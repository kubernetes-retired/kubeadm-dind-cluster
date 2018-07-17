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
  local defaultServer='localhost:8080'
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
  "${kubectl}" --server="$defaultServer" get pods -n kube-system | grep kube-dns
  time bash -x "${DIND_ROOT}"/dind-cluster.sh up
  "${kubectl}" --server="$defaultServer" get pods -n kube-system | grep kube-dns
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

function test-case-multiple-instances {
  local defaultLabel='mirantis.kubeadm_dind_cluster_runtime'
  local customLabel='some.custom-label'

  "${DIND_ROOT}"/dind-cluster.sh up
  APISERVER_PORT=8082 DIND_SUBNET='10.199.0.0' DIND_LABEL="$customLabel" "${DIND_ROOT}"/dind-cluster.sh up

  test "$(countContainersWithLabel "$defaultLabel")" -gt 0 || {
    fail 'Expected containers with default label to exist'
  }
  test "$(countContainersWithLabel "$customLabel")"  -gt 0 || {
    fail 'Expected containers with custom label to exist'
  }

  "${DIND_ROOT}"/dind-cluster.sh clean
  test "$(countContainersWithLabel "$defaultLabel")" -eq 0 || {
    fail 'Expected containters with default label not to exist'
  }
  test "$(countContainersWithLabel "$customLabel")" -gt 0 || {
    fail 'Expected containters with custom label to exist'
  }

  DIND_LABEL="$customLabel" "${DIND_ROOT}"/dind-cluster.sh clean
  test "$(countContainersWithLabel "$defaultLabel")" -eq 0 || {
    fail 'Expected containters with default label not to exist'
  }
  test "$(countContainersWithLabel "$customLabel")" -eq 0 || {
    fail 'Expected containters with custom label not to exist'
  }
}


function test-case-cluster-names() {
  local defaultLabel='mirantis.kubeadm_dind_cluster_runtime'
  local customLabel='some.custom-label'
  local customSha='e0f1032f845a2ea6653db1f9a997ac9572d4bc65'
  local d="${DIND_ROOT}/dind-cluster.sh"

  export KUBECONFIG="$(mktemp)"
  trap 'rm -- "$KUBECONFIG"' EXIT

  "${d}" up
  APISERVER_PORT=8082 DIND_SUBNET='10.199.0.0' DIND_LABEL="$customLabel" "${d}" up

  # masters
  test "$(countContainersWithExactName "kube-master")" -eq 1 || {
    fail 'Expected exactly one container with name "kube-master" to exist - cluster created with default label'
  }
  test "$(countContainersWithExactName "kube-master-${customSha}")" -eq 1 || {
    fail 'Expected exactly one container with name "kube-master-e0f1032f845a2ea6653db1f9a997ac9572d4bc65" to exist - cluster created with custom label'
  }

  # nodes
  test "$(countContainersWithExactName "kube-node-\\d{1}")" -ge 1 || {
    fail 'Expected at least one container with name "kube-node-<nr>" to exist - cluster created with default label'
  }
  test "$(countContainersWithExactName "kube-node-\\d{1}-${customSha}")" -ge 1 || {
    fail 'Expected at least one container with name "kube-node-<nr>-e0f1032f845a2ea6653db1f9a997ac9572d4bc65" to exist - cluster created with custom label'
  }

  # volumes
  test "$(countVolumesWithFilter "name=kubeadm-dind-kube-master$")" -eq 1 || {
    fail 'Expected one volume for the kube master to exist - cluster created with default label'
  }
  test "$(countVolumesWithFilter "name=kubeadm-dind-kube-node-\\d+$")" -ge 1 || {
    fail 'Expected one volume for the kube nodes to exist - cluster created with default label'
  }
  test "$(countVolumesWithFilter "name=kubeadm-dind-sys$")" -eq 1 || {
    fail 'Expected one volume for the sys to exist - cluster created with default label'
  }

  test "$(countVolumesWithFilter "name=kubeadm-dind-kube-master-${customSha}$")" -eq 1 || {
    fail 'Expected one volume for the kube master to exist - cluster created with custom label'
  }
  test "$(countVolumesWithFilter "name=kubeadm-dind-kube-node-\\d+-${customSha}$")" -ge 1 || {
    fail 'Expected one volume for the kube nodes to exist - cluster created with custom label'
  }
  test "$(countVolumesWithFilter "name=kubeadm-dind-sys-${customSha}$")" -eq 1 || {
    fail 'Expected one volume for the sys to exist - cluster created with custom label'
  }

  # networks
  test "$(countNetworksWithFilter "name=kubeadm-dind-net$")" -eq 1 || {
    fail 'Expected one network to exist - cluster created with default label'
  }
  test "$(countNetworksWithFilter "name=kubeadm-dind-net-${customSha}$")" -eq 1 || {
    fail 'Expected one network to exist - cluster created with custom label'
  }

  # contexts
  hasKubeContext "dind" || {
    fail 'Expected to have context - cluster created with default label'
  }
  hasKubeContext "dind-${customSha}" || {
    fail 'Expected to have context - cluster created with custom label'
  }

  "${d}" clean
  DIND_LABEL="$customLabel" "${d}" clean
}

function test-case-dump-succeeds() {
  local d="${DIND_ROOT}/dind-cluster.sh"

  "$d" up
  "$d" dump >/dev/null || {
    fail "Expected '$d dump' to succeed"
  }
}

function hasKubeContext() {
  kubectl config get-contexts --no-headers \
    | sed 's/^\s*\**\s*//g' \
    | grep -q "^${1}\\s"
}

function fail() {
  local msg="$1"
  echo -e "\033[1;31m${msg}\033[0m" >&2
  return 1
}

function countNetworksWithFilter() {
  docker network ls -q --filter="$1" | wc -l | xargs
}

function countVolumesWithFilter() {
  docker volume ls -q --filter="$1" | wc -l | xargs
}

function countContainersWithExactName() {
  countContainersWithFilter "name=${1}$"
}

function countContainersWithLabel() {
  countContainersWithFilter "label=${1}"
}

function countContainersWithFilter() {
  docker ps -q --filter="${1}" | wc -l | xargs
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
  test-case-multiple-instances
  test-case-dump-succeeds
  test-case-cluster-names
else
  "test-case-${TEST_CASE}"
fi

echo "*** OK ***"

# TODO: build k8s master daily using Travis cron feature
