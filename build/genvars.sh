#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

VERSIONS=(1.4.9 1.5.4 1.6.0-beta.3)

first=1
for version in ${VERSIONS[@]}; do
  base_url="https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/linux/amd64"
  if [[ ${first} ]]; then
    first=
  else
    echo
  fi
  echo "# Version ${version}"
  suffix="$(tr .- _ <<<"${version}" | sed 's/^\([0-9]*_[0-9]*\).*/\1/')"
  if [[ ! (${version} =~ ^1\.4\.) ]]; then
      echo "KUBEADM_URL_${suffix}='${base_url}/kubeadm'"
      echo "KUBEADM_SHA1_${suffix}=$(curl -sSL "${base_url}/kubeadm.sha1")"
  fi
  echo "HYPERKUBE_URL_${suffix}='${base_url}/hyperkube'"
  echo "HYPERKUBE_SHA1_${suffix}=$(curl -sSL "${base_url}/hyperkube.sha1")"
done
