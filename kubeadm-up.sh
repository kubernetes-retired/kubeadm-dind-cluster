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

source "${DIND_ROOT}/config.sh"

USE_OVERLAY=${USE_OVERLAY:-y}
APISERVER_PORT=${APISERVER_PORT:-8080}
IMAGE_REPO=${IMAGE_REPO:-k8s.io/kubeadm-dind}
IMAGE_TAG=${IMAGE_TAG:-latest}
IMAGE_BASE_TAG=base
base_image_with_tag="k8s.io/kubernetes-dind-base:v1"
systemd_image_with_tag="k8s.io/kubernetes-dind-systemd:v1"
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

function dind::set-volume-args {
  if [ -n "${KUBEADM_DIND_LOCAL:-}" ]; then
    volume_args=(-v "$PWD:/go/src/k8s.io/kubernetes")
  else
    volume_args=(--volumes-from "$(KUBE_ROOT=$PWD &&
                                   . build-tools/common.sh &&
                                   kube::build::verify_prereqs >&2 &&
                                   echo "$KUBE_DATA_CONTAINER_NAME")")
  fi
}

tmp_containers=()
function cleanup {
  if [ ${#tmp_containers[@]} -gt 0 ]; then
    for name in "${tmp_containers[@]}"; do
      docker rm -vf "${name}" 2>/dev/null
    done
  fi
}
trap cleanup EXIT

function dind::maybe-rebuild-base-containers {
  if [[ "${DIND_KUBEADM_FORCE_REBUILD:-}" ]] || ! docker images "${systemd_image_with_tag}" | grep -q "${systemd_image_with_tag}"; then
    dind::step "Building base image:" "${systemd_image_with_tag}"
    docker build -t "${systemd_image_with_tag}" "${DIND_ROOT}/image/systemd"
  fi
}

function dind::start-tmp-container {
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
  # XXX should be 'ENTRYPOINT ["/sbin/dind_init"]' but looks like outdated
  # gcr.io/kubeadm/ci-xenial-systemd:bare is being used...
  docker commit --change 'ENTRYPOINT ["/sbin/init"]' "${tmp_container}" "${image}"
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

# dind::push-binaries creates a DIND image
# with kubectl, kubeadm and kubelet binaris along with 'hypokube'
# image with hyperkube binary inside it.
function dind::push-binaries {
  dind::set-volume-args
  dind::start-tmp-container "${volume_args[@]}" "${IMAGE_REPO}:${IMAGE_BASE_TAG}"
  dind::step "Updating hypokube image"
  docker exec ${tmp_container} /hypokube/place_binaries.sh
  dind::tmp-container-commit "${IMAGE_REPO}:${IMAGE_TAG}"
}

function dind::run {
  # FIXME (create several containers)
  local container_name="$1"
  local netshift="$2"
  local portforward="$3"
  local -a portforward_opts=()
  shift 3

  # remove any previously created containers with the same name
  docker rm -vf "${container_name}" 2>/dev/null || true

  if [[ "$portforward" ]]; then
    portforward_opts=(-p "$portforward")
  fi

  dind::step "Starting DIND container:" "${container_name}"
  # Start the new container.
  new_container=$(docker run \
                         -d --privileged \
                         --name "${container_name}" \
                         --hostname "${container_name}" \
                         -e USE_OVERLAY=${USE_OVERLAY} \
                         -e DOCKER_NETWORK_OFFSET=0.0.${netshift}.0 \
                         -e HYPERKUBE_IMAGE=k8s.io/hypokube:v1 \
                         -l kubeadm-dind \
                         ${portforward_opts[@]+"${portforward_opts[@]}"} \
                         "${IMAGE_REPO}:${IMAGE_TAG}")

  # See also image/systemd/wrapkubeadm
  dind::step "Running kubeadm:" "$*"
  docker exec "${new_container}" wrapkubeadm "$@"
}

function dind::init {
  dind::run kube-master 1 127.0.0.1:${APISERVER_PORT}:8080 init "$@"
  dind::step "Setting cluster config"
  cluster/kubectl.sh config set-cluster dind --server="http://localhost:${APISERVER_PORT}" --insecure-skip-tls-verify=true
  cluster/kubectl.sh config set-context dind --cluster=dind
  cluster/kubectl.sh config use-context dind
}

function dind::join {
  # if there's just one node currently, it's master, thus we need to use
  # kube-node-1 hostname, if there are two nodes, we should pick
  # kube-node-2 and so on
  local next_node_index=$(docker ps --format='{{.Names}}' --filter=label=kubeadm-dind | wc -l | sed 's/^ *//g')
  dind::run kube-node-${next_node_index} $((next_node_index + 1)) "" join "$@"
}

function dind::escape-e2e-name {
    sed 's/[]\$*.^|()[]/\\&/g; s/\s\+/\\s+/g' <<< "$1" | tr -d '\n'
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
  GREEN="${1}"
  shift
  if [ -t 1 ] ; then
    echo -e ${OPTS} "\x1B[97m* \x1B[92m${GREEN}\x1B[39m $*" 1>&2
  else
    echo ${OPTS} "* ${GREEN} $*" 1>&2
  fi
}

case "${1:-}" in
  prepare)
    dind::maybe-rebuild-base-containers
    dind::prepare
    dind::push-binaries
    ;;
  push)
    dind::push-binaries
    ;;
  init)
    shift
    dind::init "$@"
    ;;
  join)
    shift
    dind::join "$@"
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
    echo "  $0 prepare" >&2
    echo "  $0 init kubeadm-args..." >&2
    echo "  $0 join kubeadm-args..." >&2
    echo "  $0 push" >&2
    echo "  $0 e2e [test-name-substring]" >&2
    echo "  $0 e2e-serial [test-name-substring]" >&2
    exit 1
    ;;
esac
