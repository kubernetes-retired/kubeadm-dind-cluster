#!/bin/bash -x
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

. build/buildconf.sh

NOBUILD="${NOBUILD:-}"

tempdir="$(mktemp -d)"
trap "rm -rf '${tempdir}'" EXIT
export KUBECTL_DIR="${tempdir}"

kubectl="${KUBECTL_DIR}/kubectl"

if [[ ${NOBUILD} ]]; then
  bash -x ./dind-cluster.sh clean
else
  export DIND_IMAGE=mirantis/kubeadm-dind-cluster:local
fi

function test-cluster {
  if [[ ! ${NOBUILD} ]]; then
    ./build/build-local.sh
  fi
  bash -x ./dind-cluster.sh clean
  time bash -x ./dind-cluster.sh up
  "${kubectl}" get pods -n kube-system | grep kube-dns
  time bash -x ./dind-cluster.sh up
  "${kubectl}" get pods -n kube-system | grep kube-dns
  bash -x ./dind-cluster.sh down
  bash -x ./dind-cluster.sh clean
}

(
  export KUBEADM_URL="${KUBEADM_URL_1_5}"
  export KUBEADM_SHA1="${KUBEADM_SHA1_1_5}"
  export HYPERKUBE_URL="${HYPERKUBE_URL_1_4}"
  export HYPERKUBE_SHA1="${HYPERKUBE_SHA1_1_4}"
  if [[ ${NOBUILD} ]]; then
    export DIND_IMAGE=mirantis/kubeadm-dind-cluster:v1.4
    docker pull "${DIND_IMAGE}"
  else
    export LOCAL_KUBECTL_VERSION=v1.4
  fi
  test-cluster
)

(
  export KUBEADM_URL="${KUBEADM_URL_1_5}"
  export KUBEADM_SHA1="${KUBEADM_SHA1_1_5}"
  export HYPERKUBE_URL="${HYPERKUBE_URL_1_5}"
  export HYPERKUBE_SHA1="${HYPERKUBE_SHA1_1_5}"
  if [[ ${NOBUILD} ]]; then
    export DIND_IMAGE=mirantis/kubeadm-dind-cluster:v1.5
    docker pull "${DIND_IMAGE}"
  else
    export LOCAL_KUBECTL_VERSION=v1.5
  fi
  test-cluster
)

# 1.6 fails on Travis (kube-proxy fails to restart after snapshotting)
export KUBEADM_URL="${KUBEADM_URL_1_6}"
export KUBEADM_SHA1="${KUBEADM_SHA1_1_6}"
export HYPERKUBE_URL="${HYPERKUBE_URL_1_6}"
export HYPERKUBE_SHA1="${HYPERKUBE_SHA1_1_6}"
if [[ ${NOBUILD} ]]; then
    export DIND_IMAGE=mirantis/kubeadm-dind-cluster:v1.6
    docker pull "${DIND_IMAGE}"
else
    export LOCAL_KUBECTL_VERSION=v1.6
fi
test-cluster

echo "*** OK ***"
