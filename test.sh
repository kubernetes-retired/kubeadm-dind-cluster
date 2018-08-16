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

function get-ip-for-pod() {
  local pod_name="$1"
  local tries=100

  kubectl="${kubectl:-kubectl}"

  while (( tries-- ))
  do
    ip="$( $kubectl get pod "$pod_name" -o 'go-template={{ .status.podIP }}' )"
    if [ -n "$ip" ] && [ "$ip" != '<no value>' ]
    then
      echo "$ip"
      return
    fi
    sleep 1
  done
  return 1
}

function get-node-selector-override() {
  local node="${1}"
  echo '{ "apiVersion": "v1", "spec": { "nodeSelector": { "kubernetes.io/hostname": "'"$node"'" } } }'
}

function get-hostname-override() {
  local name="${1}"
  echo '{ "apiVersion": "v1", "spec": { "hostname": "'"$name"'" } }'
}

function setup-ipv6-test() {
  # set TEST_K8S_VER to something specific, by default testing v1.11 for now
  local v="${TEST_K8S_VER:-v1.11}"
  export LOCAL_KUBECTL_VERSION="$v"
  export DIND_IMAGE="mirantis/kubeadm-dind-cluster:${v}"
  docker pull "${DIND_IMAGE}"

  # Globally exported CIDR not applicable for IPv6
  export POD_NETWORK_CIDR=''
  # Add the directory we will download kubectl into to the PATH
  export PATH="${PATH}:${KUBECTL_DIR}"

  # Explicitiely set the DNS64 prefix
  export DNS64_PREFIX='fd00:10:64:ff9b::'

  # some shared config for the ipv6 tests
  export ipv6_enabled_host="ds.test-ipv6.noroutetohost.net"
  export ipv4_only_host="ipv4.test-ipv6.noroutetohost.net"
  export ipv6_enabled_host_ns='8.8.8.8'

  # kubectl setup
  export kubectl="kubectl --context dind"

  # the image to use for containers in k8s
  export k8s_img='tutum/dnsutils'
}

function lookup-address() {
  local name="$1"
  local type="${2:-A}"
  local ns="${3:-}"

  test -n "$ns" && ns="@${ns}"

  dig +short ${name} ${type} ${ns} | sed 's/\r//g'
}

function lookup-address-on-pod() {
  local pod="$1"

  local name="$2"
  local type="${3:-A}"
  local ns="${4:-}"

  test -n "$ns" && ns="@${ns}"

  $kubectl exec -ti "$pod" -- dig +short "${name}" "${type}" ${ns} | sed 's/\r//g'
}

function lookup-address-on-node() {
  local node="$1"
  local name="$2"
  local type=''

  case "${3:-}" in
    AAAA)  type='ahostsv6' ;;
    A)     type='ahostsv4' ;;
    *)     echo "unknown type '${3:-}' for lookup-address-on-node" >&2 ; return 1 ;;
  esac

  docker exec -ti "$node" getent "$type" "$name" | awk '/ STREAM /{ print $1 }'
}

function create-persistent-pod() {
  $kubectl run pod-on-node1 --image=${k8s_img} --restart=Never \
    --overrides="$( get-node-selector-override kube-node-1 )" \
    --command -- /bin/sh -c 'hostname ; /bin/sleep 3600' \
    >/dev/null 2>&1

  echo "$( get-ip-for-pod 'pod-on-node1' )"
}

function ping-tests-external() {
  $kubectl exec -ti pod-on-node1 -- ping6 -n -c1 $ipv6_enabled_host || {
    fail "Expected ping6 to $ipv6_enabled_host to succeed"
  }

  $kubectl exec -ti pod-on-node1 -- ping6 -n -c1 $ipv4_only_host || {
    fail "Expected ping6 to $ipv4_only_host to succeed"
  }
}

function ping-tests-internal() {
  pod_on_node1_ip="$1"
  $kubectl run pod-on-node2 --attach --image=${k8s_img} --restart=Never --rm \
    --overrides="$( get-node-selector-override kube-node-2 )" \
    --command -- /bin/ping6 -n -c 1 "$pod_on_node1_ip" || {
    fail 'Expected to be able to ping6 a pod by IP on a different node'
  }
}

function resolve-host() {
  local target="$1"

  aaaa_from_node="$( lookup-address-on-node 'kube-node-1' "${target}" AAAA )" || {
    fail "Expected to successfully resolve ${target}'s IPv6 address on kube-node-1"
  }

  aaaa_from_pod="$( lookup-address-on-pod 'pod-on-node1' "${target}" AAAA )" || {
    fail "Expected to successfully resolve ${target}'s IPv6 address on a pod"
  }

  aaaa_from_host="$( lookup-address "${target}" AAAA )" || {
    fail "Expected to successfully resolve ${target}'s IPv6 from the host"
  }

  test "${aaaa_from_node}" = "${aaaa_from_pod}" || {
    fail "Expected ${target} to resolve to the same IPv6 address on a node and on a pod"
  }

  # We verified, that AAAA is the same from Pod & Node, so we can just return
  # one of those
  local aaaa_from_k8s="${aaaa_from_pod}"

  echo "${aaaa_from_host},${aaaa_from_k8s}"
}

function verify-lookup-with-dns64-only() {
  local target="$1"

  IFS=, read aaaa_from_host aaaa_from_k8s <<<"$( resolve-host "$target" )"

  if ! starts-with "$DNS64_PREFIX" "$aaaa_from_k8s"
  then
    fail "Expected ${target} to resolve to something starting with the DNS64 prefix on pods/nodes, but got ${aaaa_from_k8s}"
  fi

  if starts-with "$DNS64_PREFIX" "$aaaa_from_host"
  then
    fail "Expected ${target} not to resolve to something starting with the DNS64 prefix on the host"
  fi
}

function verify-lookup-with-ext-dns-for-ipv6-host() {
  local target="$1"

  IFS=, read aaaa_from_host aaaa_from_k8s <<<"$( resolve-host "$target" )"

  if starts-with "$DNS64_PREFIX" "$aaaa_from_k8s"
  then
    fail "Expected ${target} not to resolve to something starting with the DNS64 prefix on pods/nodes, but got ${aaaa_from_k8s}"
  fi

  if starts-with "$DNS64_PREFIX" "$aaaa_from_host"
  then
    fail "Expected ${target} not to resolve to something starting with the DNS64 prefix on the host"
  fi

  if [ "$( lookup-address "$target" 'AAAA' "$ipv6_enabled_host_ns" )" != "$aaaa_from_k8s" ]
  then
    fail "Expected ${target} to resolve to the same as on ${ipv6_enabled_host_ns}"
  fi
}

function verify-lookup-with-ext-dns-for-ipv4-only-host() {
  local target="$1"

  IFS=, read aaaa_from_host aaaa_from_k8s <<<"$( resolve-host "$target" )"

  # Hosts which don't have a AAAA record still get one from our DNS64 range
  if ! starts-with "$DNS64_PREFIX" "$aaaa_from_k8s"
  then
    fail "Expected ${target} to resolve to something starting with the DNS64 prefix on pods/nodes, but got ${aaaa_from_k8s}"
  fi

  if [ "$aaaa_from_host" != "" ]
  then
    fail "Expected ${target} not to resolve on the host"
  fi
}

function test-case-ipv6() {
  setup-ipv6-test

  IP_MODE='ipv6' \
    bash -x ./dind-cluster.sh up

  persistent_pod_ip="$( create-persistent-pod )"

  for target in "${ipv6_enabled_host}" "${ipv4_only_host}"
  do
    if [ -z "${DIND_ALLOW_AAAA_USE:-}" ]
    then
      verify-lookup-with-dns64-only "${target}"
    else
      if [ "$target" = "$ipv6_enabled_host" ]
      then
        verify-lookup-with-ext-dns-for-ipv6-host "${target}"
      else
        verify-lookup-with-ext-dns-for-ipv4-only-host "${target}"
      fi
    fi
  done

  ping-tests-internal "$persistent_pod_ip"

  if [ -z "${DIND_ALLOW_AAAA_USE:-}" ]
  then
    ping-tests-external
  else
    {
      echo ''
      echo 'WARNING: not testing direct external IPv6 connectivity.'
      echo '  ... right now IPv6 in CI is only tested through NAT64 as'
      echo '      we do not have access to an IPv6 enabled CI system.'
      echo ''
      echo '  ... "ping-tests-external" is skipped'
      echo ''
    } >&2
  fi

  IP_MODE='ipv6' \
    bash -x ./dind-cluster.sh clean
}

function starts-with() {
  local needle="$1"
  local haystack="$2"
  [[ "$haystack" = "$needle"* ]]
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
