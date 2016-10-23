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

IMAGE_REPO=${IMAGE_REPO:-k8s.io/kubeadm-dind}
IMAGE_TAG=${IMAGE_TAG:-latest}
base_image_with_tag="k8s.io/kubernetes-dind-base:v1"
systemd_image_with_tag="k8s.io/kubernetes-dind-systemd:v1"
# fixme: don't hardcode versions here
PREPULL_IMAGES=(gcr.io/google_containers/kube-discovery-amd64:1.0
                debian:jessie
                gcr.io/google_containers/kubedns-amd64:1.7
                gcr.io/google_containers/exechealthz-amd64:1.1
                gcr.io/google_containers/kube-dnsmasq-amd64:1.3
                gcr.io/google_containers/pause-amd64:3.0
                gcr.io/google_containers/etcd-amd64:2.2.5)

# Trying to change conntrack settings fails even in priveleged containers,
# so we need to avoid it. Here's sample error message from kube-proxy:
# I1010 21:53:00.525940       1 conntrack.go:57] Setting conntrack hashsize to 49152
# Error: write /sys/module/nf_conntrack/parameters/hashsize: operation not supported
# write /sys/module/nf_conntrack/parameters/hashsize: operation not supported
proxy_flags="--conntrack-max=0 --conntrack-max-per-core=0"

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

# FIXME: find-binary is copied from build.sh
# Find a platform specific binary, whether it was cross compiled or locally built (on Linux)
function find-binary {
  local lookfor="${1}"
  local platform="${2}"
  local locations=(
    "$PWD/_output/dockerized/bin/${platform}/${lookfor}"
  )
  if [ "$(uname)" = Linux ]; then
    locations[${#locations[*]}]="$PWD/_output/local/bin/${platform}/${lookfor}"
  fi
  local bin=$( (ls -t "${locations[@]}" 2>/dev/null || true) | head -1 )
  echo -n "${bin}"
}

source "${DIND_ROOT}/config.sh"

function dind::kubeadm::maybe-rebuild-base-containers {
  if [[ "${DIND_KUBEADM_FORCE_REBUILD:-}" ]] || ! docker images "${systemd_image_with_tag}" | grep -q "${systemd_image_with_tag}"; then
    docker build -t "${base_image_with_tag}" "${DIND_ROOT}/image/base"
    docker build -t "${systemd_image_with_tag}" "${DIND_ROOT}/image/systemd"
  fi
}

function dind::kubeadm::prepare {
  TMP_DOCKER_PORT="${TMP_DOCKER_PORT:-8899}"
  local tmp_container="kubeadm-base-$(openssl rand -hex 16)"
  trap "docker rm -f ${tmp_container} 2>/dev/null" EXIT

  # Start DIND and make it accessible via TCP.
  #
  # For details, see
  # https://github.com/docker/docker/commit/824c72f4727504e3a8d37f87ce88733c560d4129#commitcomment-17402152
  docker run \
         -d --privileged \
         --name ${tmp_container} \
         --hostname kubeadm-base \
         -v "$DIND_ROOT/image:/image" \
         -v "$(find-binary hyperkube linux/amd64):/image/hypokube/hyperkube" \
         "${systemd_image_with_tag}"
  docker exec ${tmp_container} start_services docker

  # k8s.io/hypokube
  docker exec ${tmp_container} docker build -t k8s.io/hypokube:v1 /image/hypokube
  for image in "${PREPULL_IMAGES[@]}"; do
    docker exec ${tmp_container} docker pull "$image"
  done

  # copy binaries needed for kubeadm into the temporary container
  docker cp "$(find-binary kubectl linux/amd64)" ${tmp_container}:/usr/bin/
  docker cp "$(find-binary kubeadm linux/amd64)" ${tmp_container}:/usr/sbin/
  docker cp "$(find-binary kubelet linux/amd64)" ${tmp_container}:/usr/sbin/

  # TBD: sha256sum
  ARCH="${ARCH:-amd64}"
  CNI_RELEASE="${CNI_RELEASE:-07a8a28637e97b22eb8dfe710eeae1344f69d16e}"
  docker exec ${tmp_container} mkdir -p /usr/lib/kubernetes/cni/bin
  curl -sSL --retry 5 https://storage.googleapis.com/kubernetes-release/network-plugins/cni-${ARCH}-${CNI_RELEASE}.tar.gz |
      docker exec -i ${tmp_container} tar -C /usr/lib/kubernetes/cni/bin -xz

  # stop the container & commit the image
  docker stop ${tmp_container}
  docker commit --change 'CMD ["/sbin/init"]' "${tmp_container}" "${IMAGE_REPO}:${IMAGE_TAG}"
}

function dind::kubeadm::run {
  # FIXME (create several containers)
  local new_container="$1"
  local netshift="$2"
  shift 2

  # remove any previously created containers with the same name
  docker rm -f "${new_container}" 2>/dev/null || true

  # start the new container and bridge its inner docker network to the 'outer' docker
  # See also image/systemd/wrapkubeadm
  docker run \
         -d --privileged \
         --name "${new_container}" \
         --hostname "${new_container}" \
         -e DOCKER_NETWORK_OFFSET=0.0.${netshift}.0 \
         -e HYPERKUBE_IMAGE=k8s.io/hypokube:v1 \
         "${IMAGE_REPO}:${IMAGE_TAG}"

  docker exec "${new_container}" wrapkubeadm "$@"
}

function dind::kubeadm::init {
  dind::kubeadm::run kube-master 1 init "$@"
  # recipe by @errordeveloper:
  # https://github.com/kubernetes/kubernetes/pull/34522#issuecomment-253248985
  # TODO: use proxy flags for kubeadm when/if #34522 is merged
  # KUBE_PROXY_FLAGS="${PROXY_FLAGS:-} --masquerade-all --cluster-cidr=${cluster_cidr}"
  docker exec kube-master bash -c 'kubectl -n kube-system get ds -l "component=kube-proxy-amd64" -o json |
    jq ".items[0].spec.template.spec.containers[0].command |= .+ [\"--conntrack-max=0\", \"--conntrack-max-per-core=0\"]" |
    kubectl apply -f - && kubectl -n kube-system delete pods -l "component=kube-proxy-amd64"'
}

function dind::kubeadm::join {
  # if there's just one node currently, it's master, thus we need to use
  # kube-node-1 hostname, if there are two nodes, we should pick
  # kube-node-2 and so on
  local next_node_index=$(docker exec kube-master kubectl get nodes -o name | wc -l | sed 's/^ *//g')
  dind::kubeadm::run kube-node-${next_node_index} $((next_node_index + 1)) join "$@"
}

case "${1:-}" in
  prepare)
    dind::kubeadm::maybe-rebuild-base-containers
    dind::kubeadm::prepare
    ;;        
  init)
    shift
    dind::kubeadm::init "$@"
    ;;
  join)
    shift
    dind::kubeadm::join "$@"
    ;;
  *)
    echo "usage: $0 init|join kubeadm-args..." >&2
    exit 1
    ;;
esac
