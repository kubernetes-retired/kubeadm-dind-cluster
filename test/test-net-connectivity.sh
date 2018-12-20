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

function setup-test() {
  export IP_MODE="${IP_MODE:-ipv6}"

  # set TEST_K8S_VER to something specific, by default testing v1.11 for now
  local v="${TEST_K8S_VER:-v1.13}"
  export LOCAL_KUBECTL_VERSION="$v"
  export DIND_K8S_VERSION="${v}"
  if [[ -z ${DIND_SKIP_PULL+x} ]]; then
    docker pull "${DIND_IMAGE}"
  fi

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

  # Wait for the pod to be up...
  local tries=100
  local is_up=""
  while (( tries-- ))
  do
    is_up="$( kubectl get pod pod-on-node1 -o 'go-template={{ .status.phase }}' )"
    if [[ "${is_up}" = 'Running' ]]; then
      break
    fi
    sleep 1
  done
  echo "${is_up}"
}

function ping-tests-external() {
  if [[ ${IP_MODE} = "ipv4" || ${IP_MODE} = "dual-stack" ]]; then
    kubectl exec -ti pod-on-node1 -- ping -n -c1 $ipv4_only_host || {
      fail "Expected ping to $ipv4_only_host to succeed"
    }
  fi
  if [[ ${IP_MODE} = "ipv6" || ${IP_MODE} = "dual-stack" ]]; then
    if [ -z "${DIND_ALLOW_AAAA_USE:-}" ]; then
      kubectl exec -ti pod-on-node1 -- ping6 -n -c1 $ipv6_enabled_host || {
        fail "Expected ping6 to $ipv6_enabled_host (using synthesized address) to succeed"
      }
    else
      echo 'NOTE: Skipping direct IPv6 external ping - as not supported by CI' >&2
    fi
  fi
  if [[ ${IP_MODE} = "ipv6" ]]; then  # NOTE: IPv5 only does not have direct access to IPv4 hosts
    kubectl exec -ti pod-on-node1 -- ping6 -n -c1 $ipv4_only_host || {
      fail "Expected ping6 to $ipv4_only_host (using synthesized address) to succeed"
    }
  fi
}

function ping-tests-internal() {
  if [[ ${IP_MODE} = "ipv4" || ${IP_MODE} = "dual-stack" ]]; then
    pod_on_node1_ip="$( get-ip-for-pod pod-on-node1 ipv4 )"
    kubectl run pod-on-node2 --attach --image=${k8s_img} --restart=Never --rm \
      --overrides="$( get-node-selector-override kube-node-2 )" \
      --command -- /bin/ping -n -c 1 "$pod_on_node1_ip" || {
      fail 'Expected to be able to ping a pod by IP on a different node'
    }
  fi
  if [[ ${IP_MODE} = "ipv6" || ${IP_MODE} = "dual-stack" ]]; then
    pod_on_node1_ip="$( get-ip-for-pod pod-on-node1 ipv6 )"
    kubectl run pod-on-node2 --attach --image=${k8s_img} --restart=Never --rm \
      --overrides="$( get-node-selector-override kube-node-2 )" \
      --command -- /bin/ping6 -n -c 1 "$pod_on_node1_ip" || {
      fail 'Expected to be able to ping6 a pod by IP on a different node'
    }
  fi
}

function test-namespace-lookup() {
  if [[ ${IP_MODE} = "ipv4" || ${IP_MODE} = "dual-stack" ]]; then
    verify-lookup-using-ipv4-for-ipv4-hosts "${ipv4_only_host}"
  fi
  if [[ ${IP_MODE} = "ipv6" || ${IP_MODE} = "dual-stack" ]]; then
    if [[ -z "${DIND_ALLOW_AAAA_USE:-}" ]]; then
      verify-lookup-always-using-dns64-prefix "${ipv6_enabled_host}"
      if [[ ${IP_MODE} = "ipv6" ]]; then
        verify-lookup-using-dns64-prefix-for-ipv4-hosts "${ipv4_only_host}"
      fi
    else
      verify-lookup-using-ipv6-address-for-ipv6-hosts "${ipv6_enabled_host}"
    fi
  fi
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

function verify-lookup-using-ipv4-for-ipv4-hosts() {
  local target="$1"

  a_from_node="$( dns-lookup-ip-by-type-on-node 'kube-node-1' "${target}" A )" || {
    fail "Expected to successfully resolve ${target}'s IPv4 address on kube-node-1"
  }

  a_from_pod="$( dns-lookup-ip-by-type-on-pod 'pod-on-node1' "${target}" A )" || {
    fail "Expected to successfully resolve ${target}'s IPv4 address on a pod"
  }

  test "${a_from_node}" = "${a_from_pod}" || {
    fail "Expected ${target} to resolve to the same IPv4 address on a node and on a pod"
  }
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

# Testing based on IP_MODE:
#
# MODE       PING ACROSS NODES  EXTERNAL PING                NS LOOKUPS
# ipv4       using v4           v4 using v4                  v4 using v4
# ipv6       using v6           v4/v6s/v6 using v6*/v6+/v6-  v4/v6s/v6 using v6*/v6+/v6
# dual-stack using v4, v6       v4/v6s/v6 using v4/v6%/v6-   v4/v6s/v6 using v4/v6%/v6
#
# v4 = IPv4, v6 = IPv6, v6s = IPv6 synthesized address (with IPv4 embedded)
#
# (*) NOTE: using synthesized IPv6 address with embedded IPv4 address.
# (+) NOTE: uses A record for IPv4 address and embeds in synthesized IPv6 address.
# (-) NOTE: pinging direct IPv6 address is not supported by CI.
# (%) NOTE: using synthesized IPv6 address is not supported currently.
#
function test-case-net-connectivity() {
  setup-test

  bash ${dind_run_flags} ./dind-cluster.sh up

  if [[ "$( create-persistent-pod )" = "Running" ]]; then
    ping-tests-internal
    ping-tests-external
    test-namespace-lookup
  fi
  bash ${dind_run_flags} ./dind-cluster.sh clean
}

function main() {
  test-case-net-connectivity
  echo "*** OK: $0 ***"
}

main "$@"
