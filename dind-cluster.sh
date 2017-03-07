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

# In case of moby linux, -v will not work so we can't
# mount /lib/modules and /boot
is_moby_linux=
if docker info|grep -q '^Kernel Version: .*-moby$'; then
    is_moby_linux=1
fi

source "${DIND_ROOT}/config.sh"

DIND_SUBNET="${DIND_SUBNET:-10.192.0.0}"
dind_ip_base="$(echo "${DIND_SUBNET}" | sed 's/\.0$//')"
PREBUILT_DIND_IMAGE="${PREBUILT_DIND_IMAGE:-}"
PREBUILT_KUBEADM_AND_KUBECTL="${PREBUILT_KUBEADM_AND_KUBECTL:-}"
PREBUILT_HYPERKUBE_IMAGE="${PREBUILT_HYPERKUBE_IMAGE:-}"

BUILD_KUBEADM="${BUILD_KUBEADM:-}"
BUILD_HYPERKUBE="${BUILD_HYPERKUBE:-}"

use_k8s_source=y
if [[ ${PREBUILT_DIND_IMAGE} || ( ${PREBUILT_KUBEADM_AND_KUBECTL} && ${PREBUILT_HYPERKUBE_IMAGE} ) ]]; then
  use_k8s_source=
fi

image_version_suffix=v4
if [[ ${PREBUILT_KUBEADM_AND_KUBECTL} ]]; then
  image_version_suffix="${image_version_suffix}-extkubeadm"
fi
if [[ ${PREBUILT_HYPERKUBE_IMAGE} ]]; then
  prebuilt_hash="$(echo -n "${PREBUILT_HYPERKUBE_IMAGE}"|md5sum|head -c 8)"
  image_version_suffix="${image_version_suffix}-extk8s-${prebuilt_hash}"
fi

APISERVER_PORT=${APISERVER_PORT:-8080}
IMAGE_REPO=${IMAGE_REPO:-mirantis/kubeadm-dind-cluster}
IMAGE_TAG=${IMAGE_TAG:-${image_version_suffix}}
IMAGE_BASE_TAG=base-${image_version_suffix}
if [[ ! ${use_k8s_source} ]]; then
  # in case if the source isn't used, base image is the same as the
  # one used to run actual DIND containers
  IMAGE_BASE_TAG="${IMAGE_TAG}"
fi
IMAGE_TO_RUN=${PREBUILT_DIND_IMAGE:-"${IMAGE_REPO}:${IMAGE_TAG}"}
hypokube_image_name="mirantis/hypokube:v1"

pass_discovery_flags=
kubectl=cluster/kubectl.sh
build_tools_dir="build"
if [[ ${use_k8s_source} ]]; then
  if [[ ! -f ${build_tools_dir}/common.sh ]]; then
    build_tools_dir="build-tools"
  fi
  if [[ ! -f cluster/kubectl.sh ]]; then
    echo "$0 must be called from the Kubernetes repository root directory" 1>&2
    exit 1
  fi
  # https://github.com/kubernetes/kubernetes/commit/7945c437e59e3211c94a432e803d173282a677cd
  if git merge-base --is-ancestor 7945c437e59e3211c94a432e803d173282a677cd HEAD; then
    pass_discovery_flags=y
  fi
else
  if ! hash kubectl 2>/dev/null; then
    echo "You need kubectl binary in your PATH to use prebuilt DIND image" 1>&2
    exit 1
  fi
  kubectl=kubectl
fi

force_rebuild=
bare_image_with_tag="${IMAGE_REPO}:bare-${image_version_suffix}"
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
if [[ ${PREBUILT_HYPERKUBE_IMAGE} ]]; then
  PREPULL_IMAGES+=("${PREBUILT_HYPERKUBE_IMAGE}")
fi
build_volume_args=()

function dind::no-prebuilt {
  if [[ ${PREBUILT_DIND_IMAGE} ]]; then
    echo >&2 "This command cannot be used with prebuilt images"
  fi
}

function dind::set-build-volume-args {
  if [ ${#build_volume_args[@]} -gt 0 ]; then
    return 0
  fi
  build_container_name=
  if [ -n "${KUBEADM_DIND_LOCAL:-}" ]; then
    build_volume_args=(-v "$PWD:/go/src/k8s.io/kubernetes")
  else
    build_container_name="$(KUBE_ROOT=$PWD &&
                            . ${build_tools_dir}/common.sh &&
                            kube::build::verify_prereqs >&2 &&
                            echo "${KUBE_DATA_CONTAINER_NAME:-${KUBE_BUILD_DATA_CONTAINER_NAME}}")"
    build_volume_args=(--volumes-from "${build_container_name}")
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

function dind::maybe-rebuild-bare-image {
  if [[ "${DIND_KUBEADM_FORCE_REBUILD:-}" ]] || ! dind::check-image "${bare_image_with_tag}"; then
    dind::step "Building bare image:" "${bare_image_with_tag}"
    docker build \
           --build-arg PREBUILT_KUBEADM_AND_KUBECTL="${PREBUILT_KUBEADM_AND_KUBECTL}" \
           -t "${bare_image_with_tag}" \
           "${DIND_ROOT}/image/bare"
  fi
}

function dind::start-tmp-container {
  dind::step "Starting temporary DIND container"
  tmp_container=$(docker run \
                         -d --privileged \
                         --name kubeadm-base-$(openssl rand -hex 16) \
                         --hostname kubeadm-base \
                         "$@")
  tmp_containers+=("${tmp_container}")
  docker exec ${tmp_container} start_services docker
}

function dind::tmp-container-commit {
  local image="$1"
  local role="$2"
  dind::step "Committing image:" "${image}"
  # make sure Docker doesn't start before docker0 bridge is created
  docker exec ${tmp_container} systemctl stop docker
  docker exec ${tmp_container} systemctl disable docker

  # stop the container & commit the image
  docker stop ${tmp_container}
  # TBD: update gcr.io/kubeadm/ci-xenial-systemd:base / bare
  docker commit \
         --change "LABEL mirantis.kubeadm_dind_cluster_${role}=1" \
         --change 'ENTRYPOINT ["/sbin/dind_init"]' "${tmp_container}" "${image}"
}

# dind::prepare prepares a DIND image with base
# 'hypokube' image inside it & pre-pulls images used by k8s into it.
# It doesn't place actual k8s binaries into the image though.
function dind::prepare {
  dind::start-tmp-container "${bare_image_with_tag}"

  if [[ ! ${PREBUILT_HYPERKUBE_IMAGE} ]]; then
    dind::step "Building hypokube image"
    docker cp "$DIND_ROOT/image/hypokube" ${tmp_container}:/
    docker exec ${tmp_container} docker build -t mirantis/hypokube:base -f /hypokube/base.dkr /hypokube
  fi

  for image in "${PREPULL_IMAGES[@]}"; do
    dind::step "Pulling image:" "${image}"
    docker exec ${tmp_container} docker pull "${image}"
  done

  docker exec ${tmp_container} bash -c "echo -n '${PREBUILT_HYPERKUBE_IMAGE:-${hypokube_image_name}}' >/hyperkube_image_name"
  dind::tmp-container-commit "${IMAGE_REPO}:${IMAGE_BASE_TAG}" base
}

function dind::make-for-linux {
  local copy="$1"
  shift
  dind::step "Building binaries:" "$*"
  if [ -n "${KUBEADM_DIND_LOCAL:-}" ]; then
    make WHAT="$*"
    dind::step "+ make WHAT=\"$*\""
  elif [ "${copy}" = "y" ]; then
    "${build_tools_dir}/run.sh" make WHAT="$*"
    dind::step "+ ${build_tools_dir}/run.sh make WHAT=\"$*\""
  else
    KUBE_RUN_COPY_OUTPUT=n "${build_tools_dir}/run.sh" make WHAT="$*"
    dind::step "+ KUBE_RUN_COPY_OUTPUT=n ${build_tools_dir}/run.sh make WHAT=\"$*\""
  fi
}

function dind::check-binary {
  local filename="$1"
  local dockerized="_output/dockerized/bin/linux/amd64/${filename}"
  local plain="_output/local/bin/linux/amd64/${filename}"
  dind::set-build-volume-args
  # FIXME: don't hardcode amd64 arch
  if [ -n "${KUBEADM_DIND_LOCAL:-${force_local:-}}" ]; then
    if [ -f "${dockerized}" -o -f "${plain}" ]; then
      return 0
    fi
  elif docker run --rm "${build_volume_args[@]}" \
              busybox test \
              -f "/go/src/k8s.io/kubernetes/${dockerized}" >&/dev/null; then
    return 0
  fi
  return 1
}

function dind::ensure-kubectl {
  if [[ ! ${use_k8s_source} ]]; then
    # already checked on startup
    return 0
  fi
  if [ $(uname) = Darwin ]; then
    if [ ! -f _output/local/bin/darwin/amd64/kubectl ]; then
      dind::step "Building kubectl"
      dind::step "+ make WHAT=cmd/kubectl"
      make WHAT=cmd/kubectl
    fi
  elif ! force_local=y dind::check-binary kubectl; then
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
# with kubectl and kubeadm binaries along with 'hypokube'
# image with hyperkube binary inside it.
function dind::push-binaries {
  if [[ "${DIND_KUBEADM_FORCE_REBUILD:-}" ]] || ! dind::check-image "${IMAGE_REPO}:${IMAGE_BASE_TAG}"; then
    dind::maybe-rebuild-bare-image
    dind::prepare
  fi

  if [[ ! ${use_k8s_source} ]]; then
    return 0
  fi

  dind::set-build-volume-args
  dind::ensure-kubectl
  if [[ ! ${PREBUILT_KUBEADM_AND_KUBECTL} ]]; then
    dind::ensure-binaries cmd/kubectl cmd/kubeadm
  fi
  if [[ ! ${PREBUILT_HYPERKUBE_IMAGE} ]]; then
    dind::ensure-binaries cmd/hyperkube
  fi
  dind::start-tmp-container "${build_volume_args[@]}" "${IMAGE_REPO}:${IMAGE_BASE_TAG}"
  dind::step "Updating hypokube image"
  docker exec ${tmp_container} /usr/local/bin/place_binaries.sh
  dind::tmp-container-commit "${IMAGE_REPO}:${IMAGE_TAG}" final
}

function dind::volume-exists {
  local name="$1"
  if docker volume inspect "${name}" >& /dev/null; then
    return 0
  fi
  return 1
}

function dind::ensure-network {
  if ! docker network inspect kubeadm-dind-net >&/dev/null; then
    docker network create --subnet=10.192.0.0/16 kubeadm-dind-net >/dev/null
  fi
}

function dind::ensure-volume {
  local reuse_volume=
  if [[ $1 = -r ]]; then
    reuse_volume=1
    shift
  fi
  local name="$1"
  if dind::volume-exists "${name}"; then
    if [[ ! {reuse_volume} ]]; then
      docker volume rm "${name}" >/dev/null
    fi
  elif [[ ${reuse_volume} ]]; then
    echo "*** Failed to locate volume: ${name}" 1>&2
    return 1
  fi
  docker volume create --label mirantis.kubeadm_dind_cluster --name "${name}" >/dev/null
}


function dind::run {
  local reuse_volume=
  if [[ $1 = -r ]]; then
    reuse_volume="-r"
    shift
  fi
  local container_name="${1:-}"
  local ip="${2:-}"
  local netshift="${3:-}"
  local portforward="${4:-}"
  if [[ $# -gt 4 ]]; then
    shift 4
  else
    shift $#
  fi
  local -a opts=(--ip "${ip}" "$@")
  local -a args

  if [[ ! "${container_name}" ]]; then
    echo >&2 "Must specify container name"
    exit 1
  fi

  dind::ensure-kubectl

  # remove any previously created containers with the same name
  docker rm -vf "${container_name}" >&/dev/null || true

  if [[ "$portforward" ]]; then
    opts+=(-p "$portforward")
  fi

  if [[ "$netshift" ]]; then
    args+=("systemd.setenv=DOCKER_NETWORK_OFFSET=0.0.${netshift}.0")
  fi

  dind::step "Starting DIND container:" "${container_name}"
  # We mount /boot and /lib/modules into the container
  # below to in case some of the workloads need them.
  # This includes virtlet, for instance. Unfortunately
  # we can't do this when using Mac Docker
  # (unless a remote docker daemon on Linux is used)
  if [[ ! ${is_moby_linux} ]]; then
    opts+=(-v /boot:/boot -v /lib/modules:/lib/modules)
  fi
  if [[ ${ENABLE_STREAMING_PROXY_REDIRECTS} ]]; then
    args+=("systemd.setenv=ENABLE_STREAMING_PROXY_REDIRECTS=y")
  fi

  volume_name="kubeadm-dind-${container_name}"
  dind::ensure-network
  dind::ensure-volume ${reuse_volume} "${volume_name}"

  # TODO: create named volume for binaries and mount it to /k8s
  # in case of the source build

  # Start the new container.
  docker run \
         -d --privileged \
         --net kubeadm-dind-net \
         --name "${container_name}" \
         --hostname "${container_name}" \
         -l mirantis.kubeadm_dind_cluster \
         -v ${volume_name}:/dind \
         ${opts[@]+"${opts[@]}"} \
         "${IMAGE_TO_RUN}" \
         ${args[@]+"${args[@]}"}
}

function dind::kubeadm {
  local container_id="$1"
  shift
  dind::step "Running kubeadm:" "$*"
  status=0
  # See image/bare/wrapkubeadm.
  # Capturing output is necessary to grab flags for 'kubeadm join'
  if ! docker exec "${container_id}" /bin/bash -x wrapkubeadm "$@" 2>&1 | tee /dev/fd/2; then
    echo "*** kubeadm failed" >&2
    return 1
  fi
  return ${status}
}

function dind::ensure-final-image {
  if [[ ! ${PREBUILT_DIND_IMAGE} ]] && ! dind::check-image "${IMAGE_REPO}:${IMAGE_TAG}"; then
    dind::push-binaries
  fi
}

# function dind::bare {
#   local container_name="${1:-}"
#   if [[ ! "${container_name}" ]]; then
#     echo >&2 "Must specify container name"
#     exit 1
#   fi
#   shift
#   run_opts=(${@+"$@"})
#   dind::ensure-final-image
#   dind::run "${container_name}"
# }

function dind::configure-kubectl {
  dind::step "Setting cluster config"
  "${kubectl}" config set-cluster dind --server="http://localhost:${APISERVER_PORT}" --insecure-skip-tls-verify=true
  "${kubectl}" config set-context dind --cluster=dind
  "${kubectl}" config use-context dind
}

make_binaries=
function dind::set-master-opts {
  master_opts=()
  if [[ ${BUILD_KUBEADM} || ${BUILD_HYPERKUBE} ]]; then
    # share binaries pulled from the build container between nodes
    dind::ensure-volume "dind-k8s-binaries"
    dind::set-build-volume-args
    master_opts+=("${build_volume_args[@]}" -v dind-k8s-binaries:/k8s)
    local -a bins
    if [[ ${BUILD_KUBEADM} ]]; then
      master_opts+=(-e KUBEADM_SOURCE=build://)
      bins+=(cmd/kubeadm)
    fi
    if [[ ${BUILD_HYPERKUBE} ]]; then
      master_opts+=(-e HYPERKUBE_SOURCE=build://)
      bins+=(cmd/hyperkube)
    fi
    if [[ ${make_binaries} ]]; then
      dind::make-for-linux n "${bins[@]}"
    fi
  fi
}

function dind::init {
  dind::ensure-final-image
  local -a opts
  dind::set-master-opts
  local master_ip="${dind_ip_base}.2"
  local container_id=$(dind::run kube-master "${master_ip}" 1 127.0.0.1:${APISERVER_PORT}:8080 ${master_opts[@]+"${master_opts[@]}"})
  # FIXME: I tried using custom tokens with 'kubeadm ex token create' but join failed with:
  # 'failed to parse response as JWS object [square/go-jose: compact JWS format must have three parts]'
  # So we just pick the line from 'kubeadm init' output
  kubeadm_join_flags="$(dind::kubeadm "${container_id}" init --skip-preflight-checks "$@" | grep '^kubeadm join' | sed 's/^kubeadm join //')"
  dind::configure-kubectl
}

function dind::create-node-container {
  local reuse_volume=
  if [[ $1 = -r ]]; then
    reuse_volume="-r"
    shift
  fi
  # if there's just one node currently, it's master, thus we need to use
  # kube-node-1 hostname, if there are two nodes, we should pick
  # kube-node-2 and so on
  local next_node_index=${1:-$(docker ps -q --filter=label=mirantis.kubeadm_dind_cluster | wc -l | sed 's/^ *//g')}
  local node_ip="${dind_ip_base}.$((next_node_index + 2))"
  local -a opts
  if [[ ${BUILD_KUBEADM} || ${BUILD_HYPERKUBE} ]]; then
    opts+=(-v dind-k8s-binaries:/k8s)
    if [[ ${BUILD_KUBEADM} ]]; then
      opts+=(-e KUBEADM_SOURCE=build://)
    fi
    if [[ ${BUILD_HYPERKUBE} ]]; then
      opts+=(-e HYPERKUBE_SOURCE=build://)
    fi
  fi
  dind::run ${reuse_volume} kube-node-${next_node_index} ${node_ip} $((next_node_index + 1)) "" ${opts[@]+"${opts[@]}"}
}

function dind::join {
  local container_id="$1"
  shift
  dind::kubeadm "${container_id}" join --skip-preflight-checks "$@" >/dev/null
}

function dind::escape-e2e-name {
    sed 's/[]\$*.^|()[]/\\&/g; s/\s\+/\\s+/g' <<< "$1" | tr -d '\n'
}

function dind::accelerate-kube-dns {
  dind::step "Patching kube-dns deployment to make it start faster"
  # could do this on the host, too, but we don't want to require jq here
  docker exec kube-master /bin/bash -c \
         "kubectl get deployment kube-dns -n kube-system -o json | jq '.spec.template.spec.containers[0].readinessProbe.initialDelaySeconds = 3' | kubectl apply -f -"
}

function dind::wait-for-dns {
  dind::step "Waiting for DNS"
  while [[ $(kubectl get pods -l component=kube-dns -n kube-system \
                     -o jsonpath='{.items[0].status.conditions[?(@.type == "Ready")].status}' 2>/dev/null) != "True" ]]; do
    echo -n "." >&2
    sleep 1
  done
  echo "[done]" >&2
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
  # pre-create node containers sequentially so they get predictable IPs
  local -a node_containers
  for ((n=1; n <= NUM_NODES; n++)); do
    dind::step "Starting node container:" ${n}
    if ! container_id="$(dind::create-node-container ${n})"; then
      echo >&2 "*** Failed to start node container ${n}"
      exit 1
    else
      node_containers+=(${container_id})
      dind::step "Node container started:" ${n}
    fi
  done
  status=0
  local -a pids
  for ((n=1; n <= NUM_NODES; n++)); do
    (
      dind::step "Joining node:" ${n}
      container_id="${node_containers[n-1]}"
      if ! dind::join ${container_id} ${kubeadm_join_flags}; then
        echo >&2 "*** Failed to start node container ${n}"
        exit 1
      else
        dind::step "Node joined:" ${n}
      fi
    )&
    pids[${n}]=$!
  done
  for pid in ${pids[*]}; do
    wait ${pid}
  done
  dind::accelerate-kube-dns
  # FIXME: Crossing fingers that the deployment's pods get recreated
  # here. It's not critical but if they don't subsequent cluster
  # startup may be a bit slower.
  sleep 3
  dind::wait-for-dns
}

function dind::snapshot_container {
  local container_name="$1"
  docker exec -i ${container_name} /usr/local/bin/snapshot prepare
  docker diff ${container_name} | docker exec -i ${container_name} /usr/local/bin/snapshot save
  docker rm -f "${container_name}"
}

function dind::snapshot {
  dind::snapshot_container kube-master
  for ((n=1; n <= NUM_NODES; n++)); do
    dind::snapshot_container "kube-node-${n}"
  done
}

restore_cmd=restore
function dind::restore_container {
  local container_id="$1"
  docker exec ${container_id} /usr/local/bin/snapshot "${restore_cmd}"
}

function dind::restore {
  local master_ip="${dind_ip_base}.2"
  dind::down
  dind::ensure-final-image
  dind::step "Restoring master container"
  dind::set-master-opts
  for ((n=0; n <= NUM_NODES; n++)); do
    (
      if [[ n -eq 0 ]]; then
        dind::step "Restoring master container"
        dind::restore_container "$(dind::run -r kube-master "${master_ip}" 1 127.0.0.1:${APISERVER_PORT}:8080 ${master_opts[@]+"${master_opts[@]}"})"
        dind::step "Master container restored"
      else
        dind::step "Restoring node container:" ${n}
        if ! container_id="$(dind::create-node-container -r ${n})"; then
          echo >&2 "*** Failed to start node container ${n}"
          exit 1
        else
          dind::restore_container "${container_id}"
          dind::step "Node container restored:" ${n}
        fi
      fi
    )&
    pids[${n}]=$!
  done
  for pid in ${pids[*]}; do
    wait ${pid}
  done
  # Recheck kubectl config. It's possible that the cluster was started
  # on this docker from different host
  dind::configure-kubectl
  dind::wait-for-dns
}

function dind::down {
  docker ps -q --filter=label=mirantis.kubeadm_dind_cluster | while read container_id; do
    dind::step "Removing container:" "${container_id}"
    docker rm -fv "${container_id}"
  done
}

# function dind::remove-images {
#   docker images -q -f label=mirantis.kubeadm_dind_cluster | while read image_id; do
#     dind::step "Removing image:" "${image_id}"
#     docker rmi -f "${image_id}"
#   done
# }

function dind::remove-volumes {
  docker volume ls -q -f label=mirantis.kubeadm_dind_cluster | while read volume_id; do
    dind::step "Removing volume:" "${volume_id}"
    docker volume rm -f "${volume_id}"
  done
}

function dind::check-for-snapshot {
  if ! dind::volume-exists "kubeadm-dind-kube-master"; then
    return 1
  fi
  for ((n=1; n <= NUM_NODES; n++)); do
    if ! dind::volume-exists "kubeadm-dind-kube-node-${n}"; then
      return 1
    fi
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
  dind::set-build-volume-args
  docker run \
         --rm -it \
         --net=host \
         "${build_volume_args[@]}" \
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

function dind::clean {
  dind::down
  # dind::remove-images
  dind::remove-volumes
  if docker network inspect kubeadm-dind-net >&/dev/null; then
    docker network remove kubeadm-dind-net
  fi
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
  if [ -t 2 ] ; then
    echo -e ${OPTS} "\x1B[97m* \x1B[92m${GREEN}\x1B[39m $*" 1>&2
  else
    echo ${OPTS} "* ${GREEN} $*" 1>&2
  fi
}

case "${1:-}" in
  up)
    if ! dind::check-for-snapshot; then
      make_binaries=y dind::up
      dind::snapshot
    fi
    dind::restore
    ;;
  reup)
    if ! dind::check-for-snapshot; then
      dind::up
      dind::snapshot
      dind::restore
    else
      make_binaries=y
      restore_cmd=update_and_restore
      dind::restore
    fi
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
    dind::join "$(dind::create-node-container)" "$@"
    ;;
  # bare)
  #   shift
  #   dind::bare "$@"
  #   ;;
  snapshot)
    shift
    dind::snapshot
    ;;
  restore)
    shift
    dind::restore
    ;;
  clean)
    dind::clean
    ;;
  e2e)
    shift
    dind::no-prebuilt
    dind::run-e2e "$@"
    ;;
  e2e-serial)
    shift
    dind::no-prebuilt
    dind::run-e2e-serial "$@"
    ;;
  *)
    echo "usage:" >&2
    echo "  $0 up" >&2
    echo "  $0 reup" >&2
    echo "  $0 down" >&2
    echo "  $0 init kubeadm-args..." >&2
    echo "  $0 join kubeadm-args..." >&2
    # echo "  $0 bare container_name [docker_options...]"
    echo "  $0 clean"
    echo "  $0 e2e [test-name-substring]" >&2
    echo "  $0 e2e-serial [test-name-substring]" >&2
    exit 1
    ;;
esac

# TODO: predictable IPs of the nodes (just using netshift is not enough)
