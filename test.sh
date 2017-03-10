#!/bin/bash -x
set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

export DIND_IMAGE=mirantis/kubeadm-dind-cluster:local

function test_cluster {
  ./build/build-local.sh
  time bash -x ./dind-cluster.sh up
  kubectl get pods -n kube-system | grep kube-dns
  time bash -x ./dind-cluster.sh up
  kubectl get pods -n kube-system | grep kube-dns
  bash -x ./dind-cluster.sh down
  bash -x ./dind-cluster.sh clean
}

test_cluster

(
    export KUBEADM_URL=https://storage.googleapis.com/kubernetes-release/release/v1.6.0-beta.2/bin/linux/amd64/kubeadm
    export KUBEADM_SHA1=61286285fa2d1ecbd85ca1980f556b41d188f34f
    export HYPERKUBE_URL=https://storage.googleapis.com/kubernetes-release/release/v1.6.0-beta.2/bin/linux/amd64/hyperkube
    export HYPERKUBE_SHA1=27e3c04c248aa972a6a3f1dd742fde7fcb5e1598
    test_cluster
)
