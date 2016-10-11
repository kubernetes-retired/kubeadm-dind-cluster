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

# Here we generate k8s tag using k8s scripts for the sake of convenience
. build/util.sh
k8s_version_tag="$(kube::release::semantic_image_tag_version)"
hyperkube_image_with_tag="gcr.io/google_containers/hyperkube-amd64:${k8s_version_tag}"

# FIXME: find-binary is copied from build.sh
# Find a platform specific binary, whether it was cross compiled or locally built (on Linux)
function find-binary {
  local lookfor="${1}"
  local platform="${2}"
  local locations=(
    "_output/dockerized/bin/${platform}/${lookfor}"
  )
  if [ "$(uname)" = Linux ]; then
    locations[${#locations[*]}]="_output/local/bin/${platform}/${lookfor}"
  fi
  local bin=$( (ls -t "${locations[@]}" 2>/dev/null || true) | head -1 )
  echo -n "${bin}"
}

source "${DIND_ROOT}/config.sh"
storage_dir="${DOCKER_IN_DOCKER_STORAGE_DIR:-${DOCKER_IN_DOCKER_WORK_DIR}/storage}"

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
  # We mount /var/lib/docker here because overlay-over-overlay no longer
  # works in the current docker. Because of this, we must grab the contents
  # of container's /var/lib/docker later. Note that actual
  # /var/lib/docker from the inner docker will be created under
  # ${storage_dir}/kubeadm-base because of extra bind-mount in
  # image/base/wrapdocker script.
  #
  # For details, see
  # https://github.com/docker/docker/commit/824c72f4727504e3a8d37f87ce88733c560d4129#commitcomment-17402152
  docker run \
         -v "${storage_dir}":/var/lib/docker \
         -d --privileged \
         --name ${tmp_container} \
         --hostname kubeadm-base \
         -p 127.0.0.1:${TMP_DOCKER_PORT}:${TMP_DOCKER_PORT} \
         -e DOCKER_DAEMON_ARGS="-H tcp://0.0.0.0:${TMP_DOCKER_PORT} -H unix:///var/run/docker.sock" \
         "${systemd_image_with_tag}" \
         startdocker sleep infinity

  # build hyperkube image and place it into the container's inner Docker
  DOCKER_HOST=tcp://127.0.0.1:${TMP_DOCKER_PORT}/ VERSION="${k8s_version_tag}" make -C cluster/images/hyperkube build

  # copy binaries needed for kubeadm into the temporary container
  docker cp "$(find-binary kubectl linux/amd64)" ${tmp_container}:/usr/bin/
  docker cp "$(find-binary kubeadm linux/amd64)" ${tmp_container}:/usr/sbin/
  docker cp "$(find-binary kubelet linux/amd64)" ${tmp_container}:/usr/sbin/

  # copy CNI stuff from hyperkube image we built
  docker exec ${tmp_container} mkdir -p /usr/lib/kubernetes
  docker exec ${tmp_container} \
         bash -c "docker run ${hyperkube_image_with_tag} tar -C /opt -c cni | tar -C /usr/lib/kubernetes -x"

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

  # copy /var/lib/docker data with hyperkube image
  # Some files may be inaccessible to the current user so we use
  # a container to access the files.
  # We can't use busybox here because cp -a must preserve hardlinks.
  # ubuntu:16.04 is already pulled because it's used by the dind base image
  # (FIXME: don't hardcode ubuntu:16.04 in multiple places)
  docker run -v "${storage_dir}:/storage" ubuntu:16.04 \
         bash -c "rm -rf /storage/'${new_container}' && cp -a /storage/kubeadm-base /storage/'${new_container}'"

  # start the new container and bridge its inner docker network to the 'outer' docker
  # See also image/systemd/wrapkubeadm
  docker run \
         -v "${storage_dir}":/var/lib/docker \
         -d --privileged \
         --name "${new_container}" \
         --hostname "${new_container}" \
         -e DOCKER_NETWORK_OFFSET=0.0.${netshift}.0 \
         -e HYPERKUBE_IMAGE="${hyperkube_image_with_tag}" \
         -e PROXY_FLAGS="${proxy_flags}" \
         "${IMAGE_REPO}:${IMAGE_TAG}"

  docker exec "${new_container}" wrapkubeadm "$@"
}

function dind::kubeadm::init {
  dind::kubeadm::maybe-rebuild-base-containers
  dind::kubeadm::prepare
  dind::kubeadm::run kube-master 1 init "$@"
}

function dind::kubeadm::join {
  # if there's just one node currently, it's master, thus we need to use
  # kube-node-1 hostname, if there are two nodes, we should pick
  # kube-node-2 and so on
  local next_node_index=$(docker exec kube-master kubectl get nodes -o name | wc -l)
  dind::kubeadm::run kube-node-${next_node_index} $((next_node_index + 1)) join "$@"
}

case "${1:-}" in
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
