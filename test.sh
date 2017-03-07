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

# kubeadm 1.6.0-beta.1 has a bug that makes it print wrong join string
# let's wait till 1.6.0-beta.2
# FIXME: the proper solution is always using newer kubeadm and not
# relying on 'kubeadm init' output

# (
#     export KUBEADM_URL=https://storage.googleapis.com/kubernetes-release/release/v1.6.0-beta.1/bin/linux/amd64/kubeadm
#     export KUBEADM_SHA1=049fc44729ec953aad78f54e3f8df652b91005f0
#     export HYPERKUBE_URL=https://storage.googleapis.com/kubernetes-release/release/v1.6.0-beta.1/bin/linux/amd64/hyperkube
#     export HYPERKUBE_SHA1=d60060dde9c74b368c4191a05ebe0216e75c4204
#     test_cluster
# )
