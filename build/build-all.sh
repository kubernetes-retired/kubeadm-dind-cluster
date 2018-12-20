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

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

save_to_dir="${1:-}"

DIND_ROOT=$(dirname "${BASH_SOURCE}")/..
source "$DIND_ROOT/build/funcs.sh"

dind::build-base
images_to_save=(${BARE_IMAGE_NAME})
for v in ${K8S_VERSIONS}; do
  version="${v//./_}"
  eval "HYPERKUBE_URL=\${HYPERKUBE_URL_${version}}"
  eval "HYPERKUBE_SHA1=\${HYPERKUBE_SHA1_${version}}"
  eval "KUBEADM_URL=\${KUBEADM_URL_${version}}"
  eval "KUBEADM_SHA1=\${KUBEADM_SHA1_${version}}"
  eval "KUBECTL_LINUX_URL=\${KUBECTL_LINUX_URL_${version}}"
  eval "KUBECTL_LINUX_SHA1=\${KUBECTL_LINUX_SHA1_${version}}"
  eval "KUBECTL_DARWIN_URL=\${KUBECTL_DARWIN_URL_${version}}"
  eval "KUBECTL_DARWIN_SHA1=\${KUBECTL_DARWIN_SHA1_${version}}"
  commit="$(git rev-parse HEAD)"
  tag="${commit}-v${v}"
  cur_image="${IMAGE_NAME}:${tag}"
  dind::build-image "${cur_image}"
  images_to_save+=("${cur_image}")
done
if [[ ${save_to_dir} ]]; then
  mkdir -p _save
  docker save "${images_to_save[@]}" >_save/images.tar
else
  echo "${images_to_save[*]}"
fi
