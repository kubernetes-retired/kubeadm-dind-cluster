#!/bin/bash
# Copyright 2018 Mirantis
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

source "${DIND_ROOT}/build/buildconf.sh"

IMAGE_CACHE_DIR="${IMAGE_CACHE_DIR:-}"
IMAGE_NAME="${IMAGE_NAME:-mirantis/kubeadm-dind-cluster}"

KUBEADM_URL="${KUBEADM_URL:-}"
HYPERKUBE_URL="${HYPERKUBE_URL:-}"
KUBEADM_SHA1=${KUBEADM_SHA1:-}
HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-}
GH_RELEASE_USER="kubernetes-sigs"
GH_REPO="kubeadm-dind-cluster"
GH_RELEASE_TEST_USER="ivan4th"

# FIXME: use k8s version specific list of images to pre-pull
# prepull_images=(gcr.io/google_containers/etcd-amd64:3.0.17
#                 gcr.io/google_containers/kube-discovery-amd64:1.0
#                 gcr.io/google_containers/kubedns-amd64:1.7
#                 gcr.io/google_containers/exechealthz-amd64:1.1
#                 gcr.io/google_containers/kube-dnsmasq-amd64:1.3
#                 gcr.io/google_containers/pause-amd64:3.0
#                 gcr.io/google_containers/etcd-amd64:2.2.5
#                 gcr.io/google_containers/etcd:2.2.1)

hypokube_base_image=mirantis/hypokube:base
image_version_suffix=v4
image_name="mirantis/kubeadm-dind-cluster"
BARE_IMAGE_NAME="${image_name}:bare-${image_version_suffix}"

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

function dind::build-hypokube {
    dind::step "Building hypokube image"
    docker build -t ${hypokube_base_image} -f image/hypokube_base.dkr image
}

function dind::image-archive-name {
    local images=("$@")
    image_hash="$(echo -n "${images[@]}" | md5sum | head -c32)"
    # echo "images-${image_hash}.tar.gz"
    echo "images-${image_hash}.tar"
}

function dind::save-images {
    local archive="$1"
    shift
    local images=("$@")
    dind::step "Pulling images: ${images[*]}"
    for image in "${images[@]}"; do
        if [[ ${image} != ${hypokube_base_image} ]]; then
            docker pull "${image}"
        fi
    done
    dind::step "Saving images to:" "${archive}"
    docker save "${images[@]}" | lz4 -9 > "${archive}"
}

# Rationale behind storing compressed prepulled images inside the image:
# this way they're pulled just once, otherwise it would be necessary to
# re-download them after each 'clean'
function dind::copy-saved-images {
    local dest="$1"
    shift
    local images=("$@")
    if [[ ! ${IMAGE_CACHE_DIR} ]]; then
        dind::save-images "${dest}" "${images[@]}"
    else
        local cached_archive="${IMAGE_CACHE_DIR}/$(dind::image-archive-name ${images[@]})"
        if [[ ! -f ${cached_archive} ]]; then
            mkdir -p "${IMAGE_CACHE_DIR}"
            dind::save-images "${cached_archive}" "${images[@]}"
        fi
        cp "${cached_archive}" "${dest}"
    fi
}

function dind::build-base {
    docker build -t "${BARE_IMAGE_NAME}" image/
}

function dind::build-image {
    local name="$1"
    # local -a images=("${prepull_images[@]}")
    local -a images=()

    dind::build-hypokube
    images+=("${hypokube_base_image}")

    if [[ ${KUBECTL_LINUX_URL} =~ /(v[0-9.]*)/ ]]; then
        kubectl_version="${BASH_REMATCH[1]}"
    else
        echo >&2 "can't get kubectl version from url: ${KUBECTL_LINUX_URL}"
        exit 1
    fi

    dind::copy-saved-images save.tar.lz4 "${images[@]}"
    docker build -t "${name}" \
           --build-arg KUBEADM_URL="${KUBEADM_URL}" \
           --build-arg KUBEADM_SHA1="${KUBEADM_SHA1}" \
           --build-arg HYPERKUBE_URL="${HYPERKUBE_URL}" \
           --build-arg HYPERKUBE_SHA1="${HYPERKUBE_SHA1}" \
           --build-arg KUBECTL_VERSION=${kubectl_version} \
           --build-arg KUBECTL_LINUX_SHA1="${KUBECTL_LINUX_SHA1}" \
           --build-arg KUBECTL_LINUX_URL="${KUBECTL_LINUX_URL}" \
           --build-arg KUBECTL_DARWIN_SHA1="${KUBECTL_DARWIN_SHA1}" \
           --build-arg KUBECTL_DARWIN_URL="${KUBECTL_DARWIN_URL}" \
           .
}

function release_description {
    local -a tag="${1}"
    shift
    git tag -l --format='%(contents:body)' "${tag}"
    echo
    echo "SHA256 sums for the files:"
    echo '```'
    (cd fixed && sha256sum "$@")
    echo '```'
}

function release {
    local tag="${1}"
    shift
    local gh_user="${GH_RELEASE_USER}"
    if [[ ${tag} =~ test ]]; then
        gh_user="${GH_RELEASE_TEST_USER}"
    fi
    local -a opts=(--user "${gh_user}" --repo "${GH_REPO}" --tag "${tag}")
    local -a files=($(cd fixed && ls dind-cluster-v*.sh))
    local description="$(release_description "${tag}" "${files[@]}")"
    local pre_release=
    if [[ ${tag} =~ -(test|pre).*$ ]]; then
        pre_release="--pre-release"
    fi
    if github-release --quiet delete "${opts[@]}"; then
        echo >&2 "Replacing the old release"
    fi
    github-release release "${opts[@]}" \
                   --name "$(git tag -l --format='%(contents:subject)' "${tag}")" \
                   --description "${description}" \
                   ${pre_release}
    for filename in "${files[@]}"; do
        echo >&2 "Uploading: ${filename}"
        github-release upload "${opts[@]}" \
                       --name "${filename}" \
                       --replace \
                       --file "fixed/${filename}"
    done
}
