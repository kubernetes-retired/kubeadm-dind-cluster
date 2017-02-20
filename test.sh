#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

git clone https://github.com/kubernetes/kubernetes.git
cd kubernetes
git checkout v1.5.3

../dind-cluster.sh up
# e2e is too heavy for Travis VMs :(
# ../dind-cluster.sh e2e
cluster/kubectl.sh get pods -n kube-system | grep kube-dns
../dind-cluster.sh down
