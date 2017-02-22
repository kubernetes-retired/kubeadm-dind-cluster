#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

cd /go/src/k8s.io/kubernetes

# Find a platform specific binary, whether it was cross compiled or locally built (on Linux)
function find-binary {
  local lookfor="${1}"
  local platform="${2}"
  local locations=(
    "_output/dockerized/bin/${platform}/${lookfor}"
  )
  if [ "$(uname)" = Linux ]; then
    locations[${#locations[*]}]="_output/local/bin/${platform}/${lookfor}"
  fi
  local bin=$( (ls -t "${locations[@]}" 2>/dev/null || true) | head -1 )
  if [[ ! ${bin} ]]; then
    return 1
  fi
  echo -n "${bin}"
}

# copy binaries needed for kubeadm
# FIXME: don't hardcode amd64 arch
if bin="$(find-binary kubectl linux/amd64)"; then
  cp "${bin}" /usr/bin/
fi
if bin="$(find-binary kubeadm linux/amd64)"; then
  cp "${bin}" /usr/sbin/
fi
if bin="$(find-binary hyperkube linux/amd64)"; then
  cp "${bin}" /hypokube
  docker build -t k8s.io/hypokube:v1 -f /hypokube/hypokube.dkr /hypokube
fi
