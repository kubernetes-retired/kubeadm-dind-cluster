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
IMAGE_BASE_TAG=base
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

function dind::kubeadm::maybe-rebuild-base-containers {
  if [[ "${DIND_KUBEADM_FORCE_REBUILD:-}" ]] || ! docker images "${systemd_image_with_tag}" | grep -q "${systemd_image_with_tag}"; then
    docker build -t "${systemd_image_with_tag}" "${DIND_ROOT}/image/systemd"
  fi
}

function dind::kubeadm::start-tmp-container {
  tmp_container="kubeadm-base-$(openssl rand -hex 16)"
  trap "docker rm -f ${tmp_container} 2>/dev/null" EXIT
  docker run \
         -d --privileged \
         --name ${tmp_container} \
         --hostname kubeadm-base \
         "$@"
  docker exec ${tmp_container} start_services docker
}

# dind::kubeadm::prepare prepares a DIND image with base
# 'hypokube' image inside it & pre-pulls images used by k8s into it.
# It doesn't place actual k8s binaries into the image though.
function dind::kubeadm::prepare {
  dind::kubeadm::start-tmp-container "${systemd_image_with_tag}"
  docker cp "$DIND_ROOT/image/hypokube" ${tmp_container}:/

  # k8s.io/hypokube
  docker exec ${tmp_container} docker build -t k8s.io/hypokube:base -f /hypokube/base.dkr /hypokube
  for image in "${PREPULL_IMAGES[@]}"; do
    docker exec ${tmp_container} docker pull "$image"
  done

  # TBD: sha256sum
  ARCH="${ARCH:-amd64}"
  CNI_RELEASE="${CNI_RELEASE:-07a8a28637e97b22eb8dfe710eeae1344f69d16e}"
  docker exec ${tmp_container} mkdir -p /usr/lib/kubernetes/cni/bin
  curl -sSL --retry 5 https://storage.googleapis.com/kubernetes-release/network-plugins/cni-${ARCH}-${CNI_RELEASE}.tar.gz |
      docker exec -i ${tmp_container} tar -C /usr/lib/kubernetes/cni/bin -xz

  # make sure Docker doesn't start before docker0 bridge is created
  docker exec ${tmp_container} systemctl disable docker

  # stop the container & commit the image
  docker stop ${tmp_container}
  docker commit --change 'CMD ["/sbin/init"]' "${tmp_container}" "${IMAGE_REPO}:${IMAGE_BASE_TAG}"
}

# dind::kubeadm::push-binaries creates a DIND image
# with kubectl, kubeadm and kubelet binaris along with 'hypokube'
# image with hyperkube binary inside it.
function dind::kubeadm::push-binaries {
  local -a volume_args
  if [ -n "${KUBEADM_DIND_LOCAL:-}" ]; then
    volume_args=(-v "$PWD:/go/src/k8s.io/kubernetes")
  else
    volume_args=(--volumes-from "$(KUBE_ROOT=$PWD &&
                                   . build-tools/common.sh &&
                                   kube::build::verify_prereqs >&2 &&
                                   echo "$KUBE_DATA_CONTAINER_NAME")")
  fi
  dind::kubeadm::start-tmp-container "${volume_args[@]}" "${IMAGE_REPO}:${IMAGE_BASE_TAG}"
  docker exec ${tmp_container} /hypokube/place_binaries.sh
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
  # Trying to change conntrack settings fails even in priveleged containers,
  # so we need to avoid it. Here's sample error message from kube-proxy:
  # I1010 21:53:00.525940       1 conntrack.go:57] Setting conntrack hashsize to 49152
  # Error: write /sys/module/nf_conntrack/parameters/hashsize: operation not supported
  # write /sys/module/nf_conntrack/parameters/hashsize: operation not supported
  #
  # Recipe by @errordeveloper:
  # https://github.com/kubernetes/kubernetes/pull/34522#issuecomment-253248985
  # TODO: use proxy flags for kubeadm when/if #34522 is merged
  # KUBE_PROXY_FLAGS="${PROXY_FLAGS:-} --masquerade-all --cluster-cidr=${cluster_cidr}"
  docker exec kube-master bash -c 'kubectl -n kube-system get ds -l "component=kube-proxy" -o json |
    jq ".items[0].spec.template.spec.containers[0].command |= .+ [\"--conntrack-max=0\", \"--conntrack-max-per-core=0\"]" |
    kubectl apply -f - && kubectl -n kube-system delete pods -l "component=kube-proxy"'
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
    dind::kubeadm::push-binaries
    ;;
  push)
    dind::kubeadm::push-binaries
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
