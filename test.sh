#!/bin/bash -x
set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

export PREBUILT_DIND_IMAGE=mirantis/kubeadm-dind-cluster:rmme

./build.sh

function test_cluster {
  time bash -x ./dind-cluster.sh up
  kubectl get pods -n kube-system | grep kube-dns
  time bash -x ./dind-cluster.sh up
  kubectl get pods -n kube-system | grep kube-dns
  bash -x ./dind-cluster.sh down
  bash -x ./dind-cluster.sh clean
}

test_cluster

KUBEADM_URL=https://storage.googleapis.com/kubernetes-release/release/v1.6.0-beta.1/bin/linux/amd64/kubeadm \
  KUBEADM_SHA1=049fc44729ec953aad78f54e3f8df652b91005f0 \
  HYPERKUBE_URL=https://storage.googleapis.com/kubernetes-release/release/v1.6.0-beta.1/bin/linux/amd64/hyperkube \
  HYPERKUBE_SHA1=d60060dde9c74b368c4191a05ebe0216e75c4204 \
  test_cluster
