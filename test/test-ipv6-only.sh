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

function setup-ipv6-only-test() {
  export IP_MODE='ipv6'

  # set TEST_K8S_VER to something specific, by default testing v1.11 for now
  local v="${TEST_K8S_VER:-v1.11}"
  export LOCAL_KUBECTL_VERSION="$v"
  export DIND_IMAGE="mirantis/kubeadm-dind-cluster:${v}"
  docker pull "${DIND_IMAGE}"

  # Add the directory we will download kubectl into to the PATH
  # Make sure the kubectl path has precedence so we use the donwloaded binary
  # instead of a potential locally available one.
  export PATH="${KUBECTL_DIR}:${PATH}"

  # We set it here explicitely, even though dind-cluster.sh would default it, to
  # later in the test be able to check if a resolved IP is prefixed with the
  # specified $DNS64_PREFIX
  export DNS64_PREFIX='fd00:10:64:ff9b::'

  # some shared config for the ipv6 tests
  export ipv6_enabled_host="ds.test-ipv6.noroutetohost.net"
  export ipv4_only_host="ipv4.test-ipv6.noroutetohost.net"
  export ipv6_enabled_host_ns='8.8.8.8'

  # the image to use for containers in k8s
  export k8s_img='tutum/dnsutils'

  # runs ./dind-cluster.sh with `xtrace`/`-x` by detault. To turn `xtrace` off
  # set TEST_DIND_RUN_FLAGS='', to change the flags use
  # TEST_DIND_RUN_FLAGS='-x -e -u -o pipefail'
  export dind_run_flags="${TEST_DIND_RUN_FLAGS--x}"
}

function dns-lookup-ip-by-type() {
  local name="$1"
  local type="${2:-A}"
  local ns="${3:-}"

  test -n "$ns" && ns="@${ns}"

  dig +short ${name} ${type} ${ns} | sed 's/\r//g'
}

function dns-lookup-ip-by-type-on-pod() {
  local pod="$1"

  local name="$2"
  local type="${3:-A}"
  local ns="${4:-}"

  test -n "$ns" && ns="@${ns}"

  kubectl exec -ti "$pod" -- dig +short "${name}" "${type}" ${ns} | sed 's/\r//g'
}

function dns-lookup-ip-by-type-on-node() {
  local node="$1"
  local name="$2"
  local type=''

  case "${3:-}" in
    AAAA)  type='ahostsv6' ;;
    A)     type='ahostsv4' ;;
    *)     echo "unknown type '${3:-}' for dns-lookup-ip-by-type-on-node" >&2 ; return 1 ;;
  esac

  docker exec -ti "$node" getent "$type" "$name" | awk '/ STREAM /{ print $1 }'
}

function create-persistent-pod() {
  kubectl run pod-on-node1 --image=${k8s_img} --restart=Never \
    --overrides="$( get-node-selector-override kube-node-1 )" \
    --command -- /bin/sh -c 'hostname ; /bin/sleep 3600' \
    >/dev/null 2>&1

  echo "$( get-ip-for-pod 'pod-on-node1' )"
}

function ping-tests-external() {
  kubectl exec -ti pod-on-node1 -- ping6 -n -c1 $ipv6_enabled_host || {
    fail "Expected ping6 to $ipv6_enabled_host to succeed"
  }

  kubectl exec -ti pod-on-node1 -- ping6 -n -c1 $ipv4_only_host || {
    fail "Expected ping6 to $ipv4_only_host to succeed"
  }
}

function ping-tests-internal() {
  pod_on_node1_ip="$1"
  kubectl run pod-on-node2 --attach --image=${k8s_img} --restart=Never --rm \
    --overrides="$( get-node-selector-override kube-node-2 )" \
    --command -- /bin/ping6 -n -c 1 "$pod_on_node1_ip" || {
    fail 'Expected to be able to ping6 a pod by IP on a different node'
  }
}

function resolve-host() {
  local target="$1"

  aaaa_from_node="$( dns-lookup-ip-by-type-on-node 'kube-node-1' "${target}" AAAA )" || {
    fail "Expected to successfully resolve ${target}'s IPv6 address on kube-node-1"
  }

  aaaa_from_pod="$( dns-lookup-ip-by-type-on-pod 'pod-on-node1' "${target}" AAAA )" || {
    fail "Expected to successfully resolve ${target}'s IPv6 address on a pod"
  }

  aaaa_from_host="$( dns-lookup-ip-by-type "${target}" AAAA )" || {
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

function verify-lookup-always-using-dns64-prefix() {
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

function verify-lookup-using-ipv6-address-for-ipv6-hosts() {
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

  if [ "$( dns-lookup-ip-by-type "$target" 'AAAA' "$ipv6_enabled_host_ns" )" != "$aaaa_from_k8s" ]
  then
    fail "Expected ${target} to resolve to the same as on ${ipv6_enabled_host_ns}"
  fi
}

function verify-lookup-using-dns64-prefix-for-ipv4-hosts() {
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

function test-case-ipv6-only() {
  setup-ipv6-only-test

  bash ${dind_run_flags} ./dind-cluster.sh up

  persistent_pod_ip="$( create-persistent-pod )"

  for target in "${ipv6_enabled_host}" "${ipv4_only_host}"
  do
    if [ -z "${DIND_ALLOW_AAAA_USE:-}" ]
    then
      verify-lookup-always-using-dns64-prefix "${target}"
    else
      if [ "$target" = "$ipv6_enabled_host" ]
      then
        verify-lookup-using-ipv6-address-for-ipv6-hosts "${target}"
      else
        verify-lookup-using-dns64-prefix-for-ipv4-hosts "${target}"
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
      echo 'NOTE: not testing direct external IPv6 connectivity.'
      echo '  ... right now IPv6 in CI is only tested through NAT64 as'
      echo '      we do not have access to an IPv6 enabled CI system.'
      echo ''
      echo '  ... "ping-tests-external" is skipped'
      echo ''
    } >&2
  fi

  bash ${dind_run_flags} ./dind-cluster.sh clean
}

function main() {
  test-case-ipv6-only
  echo "*** OK: $0 ***"
}

main "$@"
