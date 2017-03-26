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

if [ $(uname) = Darwin ]; then
  readlinkf(){ perl -MCwd -e 'print Cwd::abs_path shift' "$1";}
else
  readlinkf(){ readlink -f "$1"; }
fi
DIND_ROOT="$(cd $(dirname "$(readlinkf "${BASH_SOURCE}")"); pwd)"

. "${DIND_ROOT}"/build/buildconf.sh

NOBUILD="${NOBUILD:-}"
TEST_CASE="${TEST_CASE:-}"

tempdir="$(mktemp -d)"
trap "rm -rf '${tempdir}'" EXIT
export KUBECTL_DIR="${tempdir}"

if [[ ${NOBUILD} ]]; then
  bash -x "${DIND_ROOT}"/dind-cluster.sh clean
else
  export DIND_IMAGE=mirantis/kubeadm-dind-cluster:local
fi

function test-cluster {
  local kubectl="${KUBECTL_DIR}/kubectl"
  if [[ ${BUILD_HYPERKUBE:-} ]]; then
    kubectl="${PWD}/cluster/kubectl.sh"
  fi
  if [[ ! ${NOBUILD} ]]; then
    (
      cd "${DIND_ROOT}"
      ./build/build-local.sh
    )
  fi
  bash -x "${DIND_ROOT}"/dind-cluster.sh clean
  time bash -x "${DIND_ROOT}"/dind-cluster.sh up
  "${kubectl}" get pods -n kube-system | grep kube-dns
  time bash -x "${DIND_ROOT}"/dind-cluster.sh up
  "${kubectl}" get pods -n kube-system | grep kube-dns
  bash -x "${DIND_ROOT}"/dind-cluster.sh down
  bash -x "${DIND_ROOT}"/dind-cluster.sh clean
}

function test-cluster-src {
  (
    local version="${1:-}"
    git clone https://github.com/kubernetes/kubernetes.git
    cd kubernetes
    if [[ ${version} ]]; then
      git checkout "${version}"
    fi
    export BUILD_KUBEADM=y
    export BUILD_HYPERKUBE=y
    test-cluster
  )
}

function test-case-1.4 {
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
}

function test-case-1.4-flannel {
  (
    export CNI_PLUGIN=flannel
    test-case-1.4
  )
}

function test-case-1.4-calico {
  (
    export CNI_PLUGIN=calico
    test-case-1.4
  )
}

function test-case-1.5 {
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
}

function test-case-1.5-flannel {
  (
    export CNI_PLUGIN=flannel
    test-case-1.5
  )
}

function test-case-1.5-calico {
  (
    export CNI_PLUGIN=calico
    test-case-1.5
  )
}

function test-case-1.6 {
  (
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
  )
}

function test-case-src-1.6 {
  test-cluster-src release-1.6
}

function test-case-src-master {
  test-cluster-src
}

if [[ ! ${TEST_CASE} ]]; then
  test-case-1.4
  test-case-1.4-flannel
  test-case-1.4-calico
  test-case-1.5
  test-case-1.5-flannel
  test-case-1.5-calico
  test-case-1.6
  # TODO: fix flannel & calico on 1.6
  test-case-src-1.6
  test-case-src-master
else
  "test-case-${TEST_CASE}"
fi

echo "*** OK ***"

# TODO: add source build of k8s 1.5 to the matrix
# TODO: build k8s master daily using Travis cron feature
