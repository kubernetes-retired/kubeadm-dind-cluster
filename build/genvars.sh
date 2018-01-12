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

VERSIONS=(1.7.12 1.8.6 1.9.1)

first=1
for version in ${VERSIONS[@]}; do
  base_url="https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/linux/amd64"
  if [[ ${first} ]]; then
    first=
  else
    echo
  fi
  echo "# Version ${version}"
  suffix="$(tr .- _ <<<"${version}" | sed 's/^\([0-9]*_[0-9]*\).*/\1/')"
  if [[ ! (${version} =~ ^1\.4\.) ]]; then
      echo "KUBEADM_URL_${suffix}='${base_url}/kubeadm'"
      echo "KUBEADM_SHA1_${suffix}=$(curl -sSL "${base_url}/kubeadm.sha1")"
  fi
  echo "HYPERKUBE_URL_${suffix}='${base_url}/hyperkube'"
  echo "HYPERKUBE_SHA1_${suffix}=$(curl -sSL "${base_url}/hyperkube.sha1")"
done
