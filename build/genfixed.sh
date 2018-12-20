#!/bin/bash
# Copyright 2017 Mirantis
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

DIND_ROOT=$(dirname "${BASH_SOURCE}")/..
source "$DIND_ROOT/build/funcs.sh"

image_tag_prefix=
if [[ ${1:-} ]]; then
  image_tag_prefix="${1}-"
fi

fixed_dir="${DIND_ROOT}/fixed"
mkdir -p "${fixed_dir}"

for tag in v1.10 v1.11 v1.12 v1.13; do
  dest="${fixed_dir}/dind-cluster-${tag}.sh"
  commit="$(cd "${DIND_ROOT}"; git rev-parse HEAD)"
  image="mirantis/kubeadm-dind-cluster:${commit}-${tag}"
  # invoke docker pull to get the digest
  docker pull "${image}"
  digest="$(docker inspect --format='{{index .RepoDigests 0}}' "${image}" | sed 's/.*@//')"
  vars=(EMBEDDED_CONFIG=y
        DOWNLOAD_KUBECTL=y
        DIND_K8S_VERSION="${tag}"
        DIND_IMAGE_DIGEST="${digest}"
        DIND_COMMIT="$(cd "${DIND_ROOT}" && git rev-parse HEAD)")
  var_str=$(IFS=';'; echo "${vars[*]}")
  sed "s@#%CONFIG%@${var_str}@" \
      "${DIND_ROOT}/dind-cluster.sh" >"${dest}"
  chmod +x "${dest}"
done
