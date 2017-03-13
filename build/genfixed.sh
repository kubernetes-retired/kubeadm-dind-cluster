#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

DIND_ROOT=$(dirname "${BASH_SOURCE}")/..

fixed_dir="${DIND_ROOT}/fixed"
mkdir -p "${fixed_dir}"
for tag in v1.4 v1.5 v1.6; do
  dest="${fixed_dir}/dind-cluster-${tag}.sh"
  sed "s@#%CONFIG%@EMBEDDED_CONFIG=y;DIND_IMAGE=mirantis/kubeadm-dind-cluster:${tag}@" \
      "${DIND_ROOT}/dind-cluster.sh" >"${dest}"
  chmod +x "${dest}"
done
