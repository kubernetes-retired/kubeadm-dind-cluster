#!/usr/bin/env bash
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

set -o xtrace
set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

. "$( dirname "$0" )/shared.inc.sh"

set -eu
set -o pipefail

function test-case-multiple-instances {
  local defaultLabel='mirantis.kubeadm_dind_cluster_runtime'
  local secondClusterID="20"
  local thirdClusterLabel="third"
  local d="./dind-cluster.sh"

  export PATH="${KUBECTL_DIR}:${PATH}"
  export DIND_PORT_FORWARDER_WAIT=1
  export DIND_PORT_FORWARDER="${PWD}/build/portforward.sh"

  "${d}" up
  CLUSTER_ID="$secondClusterID" "${d}" up
  DIND_LABEL="$thirdClusterLabel" "${d}" up

  # masters
  test "$(countContainersWithExactName "kube-master")" -eq 1 || {
    fail 'Expected exactly one container with name "kube-master" to exist - cluster created with default label'
  }
  test "$(countContainersWithExactName "kube-master-cluster-${secondClusterID}")" -eq 1 || {
    fail "Expected exactly one container with name 'kube-master-cluster-${secondClusterID}' to exist - cluster created with custom ID"
  }
  test "$(countContainersWithExactName "kube-master-${thirdClusterLabel}")" -eq 1 || {
    fail "Expected exactly one container with name 'kube-master-${thirdClusterLabel}' to exist - cluster created with custom label and assigned ID"
  }

  # nodes
  test "$(countContainersWithExactName "kube-node-\\d{1}")" -ge 1 || {
    fail 'Expected at least one container with name "kube-node-<nr>" to exist - cluster created with default label'
  }
  test "$(countContainersWithExactName "kube-node-\\d{1}-cluster-${secondClusterID}")" -ge 1 || {
    fail "Expected at least one container with name 'kube-node-<nr>-cluster-${secondClusterID}' to exist - cluster created with custom ID"
  }
  test "$(countContainersWithExactName "kube-node-\\d{1}-${thirdClusterLabel}")" -ge 1 || {
    fail "Expected at least one container with name 'kube-node-<nr>-${thirdClusterLabel}' to exist - cluster created with custom label and assigned ID"
  }

  # volumes
  test "$(countVolumesWithFilter "name=kubeadm-dind-kube-master$")" -eq 1 || {
    fail 'Expected one volume for the kube master to exist - cluster created with default label'
  }
  test "$(countVolumesWithFilter "name=kubeadm-dind-kube-node-\\d+$")" -ge 1 || {
    fail 'Expected one volume for the kube nodes to exist - cluster created with default label'
  }

  test "$(countVolumesWithFilter "name=kubeadm-dind-kube-master-cluster-${secondClusterID}$")" -eq 1 || {
    fail 'Expected one volume for the kube master to exist - cluster created with custom ID'
  }
  test "$(countVolumesWithFilter "name=kubeadm-dind-kube-node-\\d+-cluster-${secondClusterID}$")" -ge 1 || {
    fail 'Expected one volume for the kube nodes to exist - cluster created with custom ID'
  }

  test "$(countVolumesWithFilter "name=kubeadm-dind-kube-master-${thirdClusterLabel}$")" -eq 1 || {
    fail 'Expected one volume for the kube master to exist - cluster created with custom label'
  }
  test "$(countVolumesWithFilter "name=kubeadm-dind-kube-node-\\d+-${thirdClusterLabel}$")" -ge 1 || {
    fail 'Expected one volume for the kube nodes to exist - cluster created with custom label'
  }

  if usesLinuxKit
  then
    test "$(countVolumesWithFilter "name=kubeadm-dind-sys$")" -eq 1 || {
      fail 'Expected one volume for the sys to exist - cluster created with default label'
    }
    test "$(countVolumesWithFilter "name=kubeadm-dind-sys-cluster-${secondClusterID}$")" -eq 1 || {
      fail 'Expected one volume for the sys to exist - cluster created with custom ID'
    }
    test "$(countVolumesWithFilter "name=kubeadm-dind-sys-${thirdClusterLabel}$")" -eq 1 || {
      fail 'Expected one volume for the sys to exist - cluster created with custom label'
    }
  fi

  # networks
  test "$(countNetworksWithFilter "name=kubeadm-dind-net$")" -eq 1 || {
    fail 'Expected one network to exist - cluster created with default label'
  }
  test "$(countNetworksWithFilter "name=kubeadm-dind-net-cluster-${secondClusterID}$")" -eq 1 || {
    fail 'Expected one network to exist - cluster created with custom ID'
  }
  test "$(countNetworksWithFilter "name=kubeadm-dind-net-${thirdClusterLabel}$")" -eq 1 || {
    fail 'Expected one network to exist - cluster created with custom label'
  }

  # contexts
  hasKubeContext "dind" || {
    fail 'Expected to have context - cluster created with default label'
  }
  hasKubeContext "dind-cluster-${secondClusterID}" || {
    fail 'Expected to have context - cluster created with custom ID'
  }
  hasKubeContext "dind-${thirdClusterLabel}" || {
    fail 'Expected to have context - cluster created with custom label'
  }

  "${d}" clean
  CLUSTER_ID="$secondClusterID" "${d}" clean
  DIND_LABEL="$thirdClusterLabel" "${d}" clean
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

function usesLinuxKit() {
  if ! docker info|grep -s '^Operating System: .*Docker for Windows' > /dev/null 2>&1 ; then
    if docker info|grep -s '^Kernel Version: .*-moby$' >/dev/null 2>&1 ||
        docker info|grep -s '^Kernel Version: .*-linuxkit' > /dev/null 2>&1 ; then
      return 0
    fi
  fi
  return 1
}

test-case-multiple-instances
