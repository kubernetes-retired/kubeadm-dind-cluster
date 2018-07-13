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

fixed_dir="${DIND_ROOT}/fixed"
mkdir -p "${fixed_dir}"
for tag in v1.8 v1.9 v1.10 v1.11 stable; do
  dest="${fixed_dir}/dind-cluster-${tag}.sh"
  sed "s@#%CONFIG%@EMBEDDED_CONFIG=y;DIND_IMAGE=mirantis/kubeadm-dind-cluster:${tag}@" \
      "${DIND_ROOT}/dind-cluster.sh" >"${dest}"
  chmod +x "${dest}"
done
