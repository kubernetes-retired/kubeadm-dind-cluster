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
VERSIONS=(1.8.15 1.9.9 1.10.5 1.11.0)

first=1
for version in ${VERSIONS[@]}; do
  base_url="https://storage.googleapis.com/kubernetes-release/release/v${version}/bin"
  linux_url="${base_url}/linux/amd64"
  darwin_url="${base_url}/darwin/amd64"
  if [[ ${first} ]]; then
    first=
  else
    echo
  fi
  echo "# Version ${version}"
  suffix="$(tr .- _ <<<"${version}" | sed 's/^\([0-9]*_[0-9]*\).*/\1/')"
  echo "KUBEADM_URL_${suffix}='${linux_url}/kubeadm'"
  echo "KUBEADM_SHA1_${suffix}=$(curl -sSL "${linux_url}/kubeadm.sha1")"
  echo "HYPERKUBE_URL_${suffix}='${linux_url}/hyperkube'"
  echo "HYPERKUBE_SHA1_${suffix}=$(curl -sSL "${linux_url}/hyperkube.sha1")"
  echo "KUBECTL_URL_${suffix}='${linux_url}/kubectl'"
  echo "KUBECTL_SHA1_${suffix}=$(curl -sSL "${linux_url}/kubectl.sha1")"
  echo "KUBECTL_DARWIN_URL_${suffix}='${darwin_url}/kubectl'"
  echo "KUBECTL_DARWIN_SHA1_${suffix}=$(curl -sSL "${darwin_url}/kubectl.sha1")"
done
