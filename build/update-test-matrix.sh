#!/usr/bin/env bash
# ^ use newer bash on Mac
#
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

# FIXME: should test kube-router with 1.13 instead

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

# TODO: test dual stack with IPv6 service network, when implemented
# TODO: test dual stack with NAT64/DNS64, if/when implemented

DIND_ROOT=$(dirname "${BASH_SOURCE}")/..

test_matrix=(
    # "No defaults" should be set for the tests with machine executor
    # Test name                  k8s   CNI         CRI        No defaults
    "test                        v1.10                          "
    "test                        v1.10 bridge      containerd   "
    "test                        v1.11                          "
    "test                        v1.11 bridge      containerd   "
    "test                        v1.11 kube-router              "
    "test                        v1.12                          "
    "test                        v1.12 bridge      containerd   "
    "test                        v1.13                          "
    "test                        v1.13 flannel                  "
    "test                        v1.13 calico                   "
    "test                        v1.13 calico-kdd               "
    "test                        v1.13 weave                    "
    "test                        v1.13 bridge      containerd   "
    "test                        v1.13 ptp                      "
    "test_multiple_clusters      v1.13                          "
    "test_ipv4_only              v1.13 bridge      docker      y"
    "test_ipv6_only              v1.13 bridge      docker      y"
    "test_ipv6_only_nat64        v1.13 bridge      docker      y"
    "test_ipv6_only_ext_aaaa     v1.13 bridge      docker      y"
    "test_dual_stack_v4_svc_net  v1.13 bridge      docker      y"
    "test_src_release                                           "
    "test_src_master                                            "
)

declare -A subst vars
subst[test_ipv6_only_nat64]=test_ipv6_only
vars[test_ipv6_only_nat64]="NAT64_V4_SUBNET_PREFIX: '10.100'"

subst[test_ipv6_only_ext_aaaa]=test_ipv6_only
vars[test_ipv6_only_ext_aaaa]="DIND_ALLOW_AAAA_USE: 'true'"

subst[test_dual_stack_v4_svc_net]=test_dual_stack
vars[test_dual_stack_v4_svc_net]="SERVICE_CIDR: '10.96.0.0/12';DIND_ALLOW_AAAA_USE: 'true'"

function test_name {
  local test_name k8s_ver cni cri nodef
  read test_name k8s_ver cni cri nodef <<<"$1"
  if [[ ${test_name} =~ ^test_src.* ]]; then
    echo "${test_name}"
  else
    echo "${test_name}_${k8s_ver}_${cni:-bridge}_${cri:-docker}"
  fi
}

function generate_test_case_circleci {
  local test_name k8s_ver cni cri nodef
  read test_name k8s_ver cni cri nodef <<<"$1"
  if [[ ${test_name} =~ ^test_src.* ]]; then
    # src tests are already defined above the marker
    return
  fi
  local cur_subst="${subst[${test_name}]:-}"
  cat <<EOF

  $(test_name "${1}"):
EOF
  if [[ ! ${nodef} ]]; then
    echo "    <<: *defaults"
  fi
  cat <<EOF
    <<: *${cur_subst:-${test_name}}
    environment:
      <<: *env
EOF
  local -a cur_vars=("DIND_K8S_VERSION: ${k8s_ver}" "CNI_PLUGIN: ${cni:-bridge}" "DIND_CRI: ${cri:-docker}")
  if [[ ${cur_subst} ]]; then
    local -a extra_vars
    IFS=";" read -e -a extra_vars <<<"${vars[${test_name}]}"
    cur_vars+=("${extra_vars[@]}")
  fi
  for var in "${cur_vars[@]}"; do
    echo "      ${var}"
  done
}

function gen_all {
  for item in "${test_matrix[@]}"; do
    generate_test_case_circleci "${item}"
  done
  
  cat <<EOF

workflows:
  version: 2
  build-test-push:
    jobs:
    - build:
        filters:
          tags:
            only:
              - /^v[0-9].*/
    - push:
        filters:
          tags:
            only:
              - /^v[0-9].*/
        requires:
        - build
EOF

  for item in "${test_matrix[@]}"; do
    cat <<EOF
    - $(test_name "${item}"):
        filters:
          tags:
            only:
              - /^v[0-9].*/
        requires:
        - build
EOF
  done

  cat <<EOF
    - release:
        filters:
          branches:
            ignore: /.*/
          tags:
            only:
              - /^v[0-9].*/
        requires:
        - push
EOF

  for item in "${test_matrix[@]}"; do
    echo "        - $(test_name "${item}")"
  done
}

sed -i '/^#cut here#/q' "${DIND_ROOT}/.circleci/config.yml"
gen_all >>"${DIND_ROOT}/.circleci/config.yml"
