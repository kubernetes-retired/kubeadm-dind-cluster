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
# pin 'master' tests to a specific PR number
# (e.g. K8S_PR=44143)
K8S_PR="${K8S_PR:-}"

tempdir="$(mktemp -d)"
export KUBECTL_DIR="${tempdir}"
export KUBECONFIG="${KUBECTL_DIR}/kube.conf"

function cleanup {
  if [[ ${TRAVIS:-} && $? -ne 0 ]]; then
    # Use temp file to avoid mixing error messages from the script
    # with base64 content
    export PATH="${KUBECTL_DIR}:${PATH}"
    "${DIND_ROOT}"/dind-cluster.sh dump64 >"${tempdir}/dump"
    cat "${tempdir}/dump"
  fi
  rm -rf '${tempdir}'
}
trap cleanup EXIT

# FIXME: 192.168.0.0/16 causes problems with Travis(?)
export POD_NETWORK_CIDR="10.244.0.0/16"

if [[ ${NOBUILD} ]]; then
  bash -x "${DIND_ROOT}"/dind-cluster.sh clean
else
  export DIND_IMAGE=mirantis/kubeadm-dind-cluster:local
fi

function test-cluster {
  local kubectl="${KUBECTL_DIR}/kubectl"
  local defaultContext='dind'

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
  "${kubectl}" --context="$defaultContext" get pods -n kube-system | grep kube-dns
  time bash -x "${DIND_ROOT}"/dind-cluster.sh up
  "${kubectl}" --context="$defaultContext" get pods -n kube-system | grep kube-dns
  bash -x "${DIND_ROOT}"/dind-cluster.sh down
  bash -x "${DIND_ROOT}"/dind-cluster.sh clean
}

function test-cluster-src {
  (
    local version="${1:-}"
    if [[ ! -d "kubernetes" ]]; then
       git clone https://github.com/kubernetes/kubernetes.git
    fi
    cd kubernetes
    if [[ ${version} ]]; then
      git checkout "${version}"
    elif [[ ${K8S_PR} ]]; then
      git fetch origin "pull/${K8S_PR}/head:testbranch"
      git checkout testbranch
    fi
    export BUILD_KUBEADM=y
    export BUILD_HYPERKUBE=y
    test-cluster
  )
}

function test-case-1.8 {
  (
    export KUBEADM_URL="${KUBEADM_URL_1_8}"
    export KUBEADM_SHA1="${KUBEADM_SHA1_1_8}"
    export HYPERKUBE_URL="${HYPERKUBE_URL_1_8}"
    export HYPERKUBE_SHA1="${HYPERKUBE_SHA1_1_8}"
    if [[ ${NOBUILD} ]]; then
      export DIND_IMAGE=mirantis/kubeadm-dind-cluster:v1.8
      docker pull "${DIND_IMAGE}"
    else
      export LOCAL_KUBECTL_VERSION=v1.8
    fi
    test-cluster
  )
}

function test-case-1.8-flannel {
  (
    export CNI_PLUGIN=flannel
    test-case-1.8
  )
}

function test-case-1.8-calico {
  (
    export CNI_PLUGIN=calico
    test-case-1.8
  )
}

function test-case-1.8-calico-kdd {
  (
    export CNI_PLUGIN=calico-kdd
    POD_NETWORK_CIDR="192.168.0.0/16"
    test-case-1.8
  )
}

function test-case-1.8-weave {
  (
    export CNI_PLUGIN=weave
    test-case-1.8
  )
}

function test-case-1.9 {
  (
    export KUBEADM_URL="${KUBEADM_URL_1_9}"
    export KUBEADM_SHA1="${KUBEADM_SHA1_1_9}"
    export HYPERKUBE_URL="${HYPERKUBE_URL_1_9}"
    export HYPERKUBE_SHA1="${HYPERKUBE_SHA1_1_9}"
    if [[ ${NOBUILD} ]]; then
        export DIND_IMAGE=mirantis/kubeadm-dind-cluster:v1.9
        docker pull "${DIND_IMAGE}"
    else
        export LOCAL_KUBECTL_VERSION=v1.9
    fi
    test-cluster
  )
}

function test-case-1.9-flannel {
  (
    export CNI_PLUGIN=flannel
    test-case-1.9
  )
}

function test-case-1.9-calico {
  (
    export CNI_PLUGIN=calico
    test-case-1.9
  )
}

function test-case-1.9-calico-kdd {
  (
    export CNI_PLUGIN=calico-kdd
    POD_NETWORK_CIDR="192.168.0.0/16"
    test-case-1.9
  )
}

function test-case-1.9-weave {
  (
    export CNI_PLUGIN=weave
    test-case-1.9
  )
}

function test-case-1.10 {
  (
    export KUBEADM_URL="${KUBEADM_URL_1_10}"
    export KUBEADM_SHA1="${KUBEADM_SHA1_1_10}"
    export HYPERKUBE_URL="${HYPERKUBE_URL_1_10}"
    export HYPERKUBE_SHA1="${HYPERKUBE_SHA1_1_10}"
    if [[ ${NOBUILD} ]]; then
        export DIND_IMAGE=mirantis/kubeadm-dind-cluster:v1.10
        docker pull "${DIND_IMAGE}"
    else
        export LOCAL_KUBECTL_VERSION=v1.10
    fi
    test-cluster
  )
}

function test-case-1.10-flannel {
  (
    export CNI_PLUGIN=flannel
    test-case-1.10
  )
}

function test-case-1.10-calico {
  (
    export CNI_PLUGIN=calico
    test-case-1.10
  )
}

function test-case-1.10-calico-kdd {
  (
    export CNI_PLUGIN=calico-kdd
    POD_NETWORK_CIDR="192.168.0.0/16"
    test-case-1.10
  )
}

function test-case-1.10-weave {
  (
    export CNI_PLUGIN=weave
    test-case-1.10
  )
}

function test-case-src-1.10 {
  test-cluster-src release-1.10
}

function test-case-src-master {
  test-cluster-src master
}

function test-case-src-master-flannel {
  (
    export CNI_PLUGIN=flannel
    test-cluster-src
  )
}

function test-case-src-master-calico {
  (
    export CNI_PLUGIN=calico
    test-cluster-src
  )
}

function test-case-src-master-calico-kdd {
  (
    export CNI_PLUGIN=calico-kdd
    POD_NETWORK_CIDR="192.168.0.0/16"
    test-cluster-src
  )
}

function test-case-src-master-weave {
  (
    export CNI_PLUGIN=weave
    test-cluster-src
  )
}

function test-case-src-working-area {
  test-cluster-src
}

function test-case-src-master-coredns {
  (
    export DNS_SERVICE=coredns
    test-cluster-src
  )
}

function test-case-dump-succeeds() {
  local d="${DIND_ROOT}/dind-cluster.sh"

  "$d" up
  "$d" dump >/dev/null || {
    fail "Expected '$d dump' to succeed"
  }
}

function test-case-restore() {
  local d="${DIND_ROOT}/dind-cluster.sh"

  "$d" up
  APISERVER_PORT=8083 "$d" up || {
    fail 'Expected to be able to restore the cluster with the APIServer listening on 8083'
  }

  "$d" clean
}

function fail() {
  local msg="$1"
  echo -e "\033[1;31m${msg}\033[0m" >&2
  return 1
}

if [[ ! ${TEST_CASE} ]]; then
  test-case-1.8
  test-case-1.8-flannel
  test-case-1.8-calico
  test-case-1.8-calico-kdd
  test-case-1.8-weave
  test-case-1.9
  test-case-1.9-flannel
  test-case-1.9-calico
  test-case-1.9-calico-kdd
  test-case-1.9-weave
  test-case-src-1.10
  test-case-src-master
  # test-case-src-master-flannel
  # test-case-src-master-calico
  # test-case-src-calico-kdd
  # test-case-src-master-weave
  # test-case-src-master-coredns
  test-case-dump-succeeds
  test-case-restore
else
  "test-case-${TEST_CASE}"
fi

echo "*** OK ***"

# TODO: build k8s master daily using Travis cron feature
