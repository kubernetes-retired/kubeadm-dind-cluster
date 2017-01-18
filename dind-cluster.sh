#!/bin/bash

# Copyright 2015 The Kubernetes Authors All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

if [ $(uname) = Darwin ]; then
  readlinkf(){ perl -MCwd -e 'print Cwd::abs_path shift' "$1";}
else
  readlinkf(){ readlink -f "$1"; }
fi
DIND_ROOT="$(cd $(dirname "$(readlinkf "${BASH_SOURCE}")"); pwd)"

if [ ! -f cluster/kubectl.sh ]; then
  echo "$0 must be called from the Kubernetes repository root directory" 1>&2
  exit 1
fi

pass_discovery_flags=
# https://github.com/kubernetes/kubernetes/commit/7945c437e59e3211c94a432e803d173282a677cd
if git merge-base --is-ancestor 7945c437e59e3211c94a432e803d173282a677cd HEAD; then
    pass_discovery_flags=y
fi

source "${DIND_ROOT}/config.sh"

build_tools_dir="build"
if [[ ! -f ${build_tools_dir}/common.sh ]]; then
    build_tools_dir="build-tools"
fi

USE_OVERLAY=${USE_OVERLAY:-y}
APISERVER_PORT=${APISERVER_PORT:-8080}
IMAGE_REPO=${IMAGE_REPO:-k8s.io/kubeadm-dind}
IMAGE_TAG=${IMAGE_TAG:-latest}
IMAGE_BASE_TAG=base-v3
force_rebuild=
systemd_image_with_tag="k8s.io/kubeadm-dind-systemd:v3"
e2e_base_image="golang:1.7.1"
# fixme: don't hardcode versions here
# fixme: consistent var name case
# TBD: try to extract versions from cmd/kubeadm/app/images/images.go
PREPULL_IMAGES=(gcr.io/google_containers/kube-discovery-amd64:1.0
                debian:jessie
                gcr.io/google_containers/kubedns-amd64:1.7
                gcr.io/google_containers/exechealthz-amd64:1.1
                gcr.io/google_containers/kube-dnsmasq-amd64:1.3
                gcr.io/google_containers/pause-amd64:3.0
                gcr.io/google_containers/etcd-amd64:2.2.5)

volume_args=()

overlay_tested=
function dind::verify-overlay {
  if [ "${USE_OVERLAY}" != "y" -o -n "${overlay_tested}" ]; then
    return 0
  fi
  dind::step "Testing overlay filesystem in docker"
  if ! docker run --rm busybox cat /proc/filesystems|grep -q '[[:blank:]]overlay[[:blank:]]*'; then
    echo >&2 "WARNING: overlay filesystem doesn't appear to work, using vfs"
    USE_OVERLAY=
  else
    dind::step "Overlay filesystem works"
  fi
  overlay_tested=y
}

function dind::set-volume-args {
  if [ ${#volume_args[@]} -gt 0 ]; then
    return 0
  fi
  build_container_name=
  if [ -n "${KUBEADM_DIND_LOCAL:-}" ]; then
    volume_args=(-v "$PWD:/go/src/k8s.io/kubernetes")
  else
    build_container_name="$(KUBE_ROOT=$PWD &&
                            . ${build_tools_dir}/common.sh &&
                            kube::build::verify_prereqs >&2 &&
                            echo "$KUBE_DATA_CONTAINER_NAME")"
    volume_args=(--volumes-from "${build_container_name}")
  fi
}

tmp_containers=()

function dind::cleanup {
  if [ ${#tmp_containers[@]} -gt 0 ]; then
    for name in "${tmp_containers[@]}"; do
      docker rm -vf "${name}" 2>/dev/null
    done
  fi
}

trap dind::cleanup EXIT

function dind::check-image {
  local name="$1"
  if docker inspect --format 'x' "${name}" >&/dev/null; then
    return 0
  else
    return 1
  fi
}

function dind::maybe-rebuild-base-containers {
  if [[ "${DIND_KUBEADM_FORCE_REBUILD:-}" ]] || ! dind::check-image "${systemd_image_with_tag}"; then
    dind::step "Building base image:" "${systemd_image_with_tag}"
    docker build -t "${systemd_image_with_tag}" "${DIND_ROOT}/image/systemd"
  fi
}

function dind::start-tmp-container {
  dind::verify-overlay
  dind::step "Starting temporary DIND container"
  tmp_container=$(docker run \
                         -d --privileged \
                         --name kubeadm-base-$(openssl rand -hex 16) \
                         --hostname kubeadm-base \
                         -e USE_OVERLAY=${USE_OVERLAY} \
                         "$@")
  tmp_containers+=("${tmp_container}")
  docker exec ${tmp_container} start_services docker
}

function dind::tmp-container-commit {
  local image="$1"
  dind::step "Committing image:" "${image}"
  # make sure Docker doesn't start before docker0 bridge is created
  docker exec ${tmp_container} systemctl stop docker
  docker exec ${tmp_container} systemctl disable docker
  if [ "${USE_OVERLAY}" = "y" ]; then
    # Save contents of the docker graph dir in the image.
    # /var/lib/docker2 is a volume and it's not saved by
    # 'docker commit'.
    docker exec ${tmp_container} bash -c "mkdir -p /var/lib/docker_keep && mv /var/lib/docker2/* /var/lib/docker_keep/"
  fi

  # stop the container & commit the image
  docker stop ${tmp_container}
  # TBD: update gcr.io/kubeadm/ci-xenial-systemd:base / bare
  docker commit --change 'ENTRYPOINT ["/sbin/dind_init"]' "${tmp_container}" "${image}"
}

# dind::prepare prepares a DIND image with base
# 'hypokube' image inside it & pre-pulls images used by k8s into it.
# It doesn't place actual k8s binaries into the image though.
function dind::prepare {
  dind::start-tmp-container "${systemd_image_with_tag}"

  dind::step "Building hypokube image"
  docker cp "$DIND_ROOT/image/hypokube" ${tmp_container}:/
  docker exec ${tmp_container} docker build -t k8s.io/hypokube:base -f /hypokube/base.dkr /hypokube

  for image in "${PREPULL_IMAGES[@]}"; do
    dind::step "Pulling image:" "${image}"
    docker exec ${tmp_container} docker pull "${image}"
  done

  dind::step "Downloading CNI"
  # TBD: sha256sum
  ARCH="${ARCH:-amd64}"
  CNI_RELEASE="${CNI_RELEASE:-07a8a28637e97b22eb8dfe710eeae1344f69d16e}"
  docker exec ${tmp_container} mkdir -p /usr/lib/kubernetes/cni/bin
  docker exec -i ${tmp_container} bash -c "curl -sSL --retry 5 https://storage.googleapis.com/kubernetes-release/network-plugins/cni-${ARCH}-${CNI_RELEASE}.tar.gz | tar -C /usr/lib/kubernetes/cni/bin -xz"

  dind::tmp-container-commit "${IMAGE_REPO}:${IMAGE_BASE_TAG}"
}

function dind::make-for-linux {
  local copy="$1"
  shift
  dind::step "Building binaries:" "$*"
  if [ -n "${KUBEADM_DIND_LOCAL:-}" ]; then
    set -x
    make WHAT="$*"
    { set +x; } 2>/dev/null
  elif [ "${copy}" = "y" ]; then
    set -x
    "${build_tools_dir}/run.sh" make WHAT="$*"
    { set +x; } 2>/dev/null
  else
    set -x
    KUBE_RUN_COPY_OUTPUT=n "${build_tools_dir}/run.sh" make WHAT="$*"
    { set +x; } 2>/dev/null
  fi
}

function dind::check-binary {
  local filename="$1"
  local dockerized="_output/dockerized/bin/linux/amd64/${filename}"
  local plain="_output/local/bin/linux/amd64/${filename}"
  dind::set-volume-args
  # FIXME: don't hardcode amd64 arch
  if [ -n "${KUBEADM_DIND_LOCAL:-${force_local:-}}" ]; then
    if [ -f "${dockerized}" -o -f "${plain}" ]; then
      return 0
    fi
  elif docker run --rm "${volume_args[@]}" \
              busybox test \
              -f "/go/src/k8s.io/kubernetes/${dockerized}" >&/dev/null; then
    return 0
  fi
  return 1
}

function dind::ensure-kubectl {
  if [ $(uname) = Darwin ]; then
    if [ ! -f _output/local/bin/darwin/amd64/kubectl ]; then
      dind::step "Building kubectl"
      set -x
      make WHAT=cmd/kubectl
      { set +x; } 2>/dev/null
    fi
  elif ! force_local=y dind::check-binary cmd/kubectl; then
    dind::make-for-linux y cmd/kubectl
  fi
}

function dind::ensure-binaries {
  local -a to_build=()
  for name in "$@"; do
    if [[ "${force_rebuild}" ]] || ! dind::check-binary "$(basename "${name}")"; then
      to_build+=("${name}")
    fi
  done
  if [ "${#to_build[@]}" -gt 0 ]; then
    dind::make-for-linux n "${to_build[@]}"
  fi
  return 0
}

# dind::push-binaries creates a DIND image
# with kubectl, kubeadm and kubelet binaris along with 'hypokube'
# image with hyperkube binary inside it.
function dind::push-binaries {
  if [[ "${DIND_KUBEADM_FORCE_REBUILD:-}" ]] || ! dind::check-image "${IMAGE_REPO}:${IMAGE_BASE_TAG}"; then
    dind::maybe-rebuild-base-containers
    dind::prepare
  fi

  dind::set-volume-args
  dind::ensure-kubectl
  dind::ensure-binaries cmd/hyperkube cmd/kubelet cmd/kubectl cmd/kubeadm
  dind::start-tmp-container "${volume_args[@]}" "${IMAGE_REPO}:${IMAGE_BASE_TAG}"
  dind::step "Updating hypokube image"
  docker exec ${tmp_container} /hypokube/place_binaries.sh
  dind::tmp-container-commit "${IMAGE_REPO}:${IMAGE_TAG}"
}

run_opts=()
function dind::run {
  # FIXME (create several containers)
  local container_name="${1:-}"
  local netshift="${2:-}"
  local portforward="${3:-}"
  local -a opts=(${run_opts[@]+"${run_opts[@]}"})
  if [[ $# -gt 3 ]]; then
    shift 3
  else
    shift $#
  fi

  if [[ ! "${container_name}" ]]; then
    echo >&2 "Must specify container name"
    exit 1
  fi

  dind::ensure-kubectl

  # remove any previously created containers with the same name
  docker rm -vf "${container_name}" 2>/dev/null || true

  if [[ "$portforward" ]]; then
    opts+=(-p "$portforward")
  fi

  if [[ "$netshift" ]]; then
    opts+=(-e DOCKER_NETWORK_OFFSET=0.0.${netshift}.0)
  fi

  dind::verify-overlay
  dind::step "Starting DIND container:" "${container_name}"
  # We mount /boot and /lib/modules into the container
  # below to make kubeadm preflight checks happy -- they
  # need to locate kernel config and among other things
  # they look at /proc/configs.gz (possibly loading configs
  # module for this) and also for /boot/config-*
  modrobe configs >& /dev/null || true
  # Start the new container.
  new_container=$(docker run \
                         -d --privileged \
                         --name "${container_name}" \
                         --hostname "${container_name}" \
                         -l kubeadm-dind \
                         -e USE_OVERLAY=${USE_OVERLAY} \
                         -e HYPERKUBE_IMAGE=k8s.io/hypokube:v1 \
                         -v /boot:/boot \
                         -v /lib/modules:/lib/modules \
                         ${opts[@]+"${opts[@]}"} \
                         "${IMAGE_REPO}:${IMAGE_TAG}")
  if [[ "$#" -gt 0 ]]; then
    dind::step "Running kubeadm:" "$*"
    status=0
    # See image/systemd/wrapkubeadm.
    # Capturing output is necessary to grab flags for 'kubeadm join'
    kubeadm_output="$(docker exec "${new_container}" wrapkubeadm "$@" 2>&1)" || status=$?
    echo >&2 "${kubeadm_output}"
    return ${status}
  fi
}

function dind::ensure-final-image {
  if ! dind::check-image "${IMAGE_REPO}:${IMAGE_TAG}"; then
    dind::push-binaries
  fi
}

function dind::bare {
  local container_name="${1:-}"
  if [[ ! "${container_name}" ]]; then
    echo >&2 "Must specify container name"
    exit 1
  fi
  shift
  run_opts=(${@+"$@"})
  dind::ensure-final-image
  dind::run "${container_name}"
}

function dind::init {
  dind::ensure-final-image
  dind::run kube-master 1 127.0.0.1:${APISERVER_PORT}:8080 init "$@"
  # FIXME: I tried using custom tokens with 'kubeadm ex token create' but join failed with:
  # 'failed to parse response as JWS object [square/go-jose: compact JWS format must have three parts]'
  # So we just pick the line from 'kubeadm init' output
  kubeadm_join_flags="$(grep '^kubeadm join' <<<"${kubeadm_output}"|sed 's/^kubeadm join //')"
  dind::step "Setting cluster config"
  cluster/kubectl.sh config set-cluster dind --server="http://localhost:${APISERVER_PORT}" --insecure-skip-tls-verify=true
  cluster/kubectl.sh config set-context dind --cluster=dind
  cluster/kubectl.sh config use-context dind
}

function dind::join {
  # if there's just one node currently, it's master, thus we need to use
  # kube-node-1 hostname, if there are two nodes, we should pick
  # kube-node-2 and so on
  local next_node_index=${1:-$(docker ps -q --filter=label=kubeadm-dind | wc -l | sed 's/^ *//g')}
  shift
  dind::run kube-node-${next_node_index} $((next_node_index + 1)) "" join "$@"
}

function dind::escape-e2e-name {
    sed 's/[]\$*.^|()[]/\\&/g; s/\s\+/\\s+/g' <<< "$1" | tr -d '\n'
}

function dind::up {
  dind::down
  if [[ ${pass_discovery_flags} ]]; then
    # newer kubeadm
    dind::init --discovery token://
  else
    dind::init
  fi
  local master_ip="$(docker inspect --format="{{.NetworkSettings.IPAddress}}" kube-master)"
  status=0
  local -a pids
  for ((n=1; n <= NUM_NODES; n++)); do
    (
      dind::step "Starting node:" ${n}
      if ! out="$(dind::join ${n} ${kubeadm_join_flags} 2>&1)"; then
        echo >&2 -e "Failed to start node ${n}:\n${out}"
        exit 1
      else
        dind::step "Node started:" ${n}
      fi
    )&
    pids[${n}]=$!
  done
  for pid in ${pids[*]}; do
    wait ${pid}
  done
}

function dind::down {
  docker ps -q --filter=label=kubeadm-dind | while read container_id; do
    dind::step "Removing container:" "${container_id}"
    docker rm -fv "${container_id}"
  done
}

function dind::do-run-e2e {
  local parallel="${1:-}"
  local focus="${2:-}"
  local skip="${3:-}"
  local test_args="--host=http://localhost:${APISERVER_PORT}"
  if [[ "$focus" ]]; then
    test_args="--ginkgo.focus=${focus} ${test_args}"
  fi
  if [[ "$skip" ]]; then
    test_args="--ginkgo.skip=${skip} ${test_args}"
  fi
  dind::ensure-binaries cmd/kubectl test/e2e/e2e.test vendor/github.com/onsi/ginkgo/ginkgo
  dind::step "Running e2e tests with args:" "${test_args}"
  dind::set-volume-args
  docker run \
         --rm -it \
         --net=host \
         "${volume_args[@]}" \
         -e KUBERNETES_PROVIDER=dind \
         -e KUBE_MASTER_IP=http://localhost:${APISERVER_PORT} \
         -e KUBE_MASTER=local \
         -e KUBERNETES_CONFORMANCE_TEST=y \
         -e GINKGO_PARALLEL=${parallel} \
         -w /go/src/k8s.io/kubernetes \
         "${e2e_base_image}" \
         bash -c "cluster/kubectl.sh config set-cluster dind --server='http://localhost:${APISERVER_PORT}' --insecure-skip-tls-verify=true &&
         cluster/kubectl.sh config set-context dind --cluster=dind &&
         cluster/kubectl.sh config use-context dind &&
         go run hack/e2e.go --v --test -check_version_skew=false --test_args='${test_args}'"
}

function dind::run-e2e {
  local focus="${1:-}"
  local skip="${2:-\[Serial\]}"
  if [[ "$focus" ]]; then
    focus="$(dind::escape-e2e-name "${focus}")"
  else
    focus="\[Conformance\]"
  fi
  dind::do-run-e2e y "${focus}" "${skip}"
}

function dind::run-e2e-serial {
  local focus="${1:-}"
  local skip="${2:-}"
  if [[ "$focus" ]]; then
    focus="$(dind::escape-e2e-name "${focus}")"
  else
    focus="\[Serial\].*\[Conformance\]"
  fi
  dind::do-run-e2e n "${focus}" "${skip}"
  # TBD: specify filter
}

function dind::step {
  local OPTS=""
  if [ "$1" = "-n" ]; then
    shift
    OPTS+="-n"
  fi
  GREEN="$1"
  shift
  if [ -t 1 ] ; then
    echo -e ${OPTS} "\x1B[97m* \x1B[92m${GREEN}\x1B[39m $*" 1>&2
  else
    echo ${OPTS} "* ${GREEN} $*" 1>&2
  fi
}

case "${1:-}" in
  update)
    force_rebuild=y
    dind::push-binaries
    ;;
  up)
    dind::up
    ;;
  down)
    dind::down
    ;;
  init)
    shift
    dind::init "$@"
    ;;
  join)
    shift
    dind::join "" "$@"
    ;;
  bare)
    shift
    dind::bare "$@"
    ;;
  e2e)
    shift
    dind::run-e2e "$@"
    ;;
  e2e-serial)
    shift
    dind::run-e2e-serial "$@"
    ;;
  *)
    echo "usage:" >&2
    echo "  $0 update" >&2
    echo "  $0 up" >&2
    echo "  $0 down" >&2
    echo "  $0 init kubeadm-args..." >&2
    echo "  $0 join kubeadm-args..." >&2
    echo "  $0 bare container_name [docker_options...]"
    echo "  $0 e2e [test-name-substring]" >&2
    echo "  $0 e2e-serial [test-name-substring]" >&2
    exit 1
    ;;
esac
