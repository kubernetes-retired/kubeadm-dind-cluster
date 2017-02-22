#!/bin/bash -x
set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

(
    export PREBUILT_HYPERKUBE_IMAGE=gcr.io/google_containers/hyperkube:v1.4.9
    export PREBUILT_KUBEADM_AND_KUBECTL=v1.5.3
    ./dind-cluster.sh up
    kubectl get pods -n kube-system | grep kube-dns
    ./dind-cluster.sh down

    docker ps -qa|xargs docker rm -fv 2>/dev/null || true
    docker images -qa|docker rmi -f 2>/dev/null || true
)


(
    export PREBUILT_HYPERKUBE_IMAGE=gcr.io/google_containers/hyperkube:v1.5.3
    export PREBUILT_KUBEADM_AND_KUBECTL=v1.5.3
    ./dind-cluster.sh up
    kubectl get pods -n kube-system | grep kube-dns
    ./dind-cluster.sh down

    docker ps -qa|xargs docker rm -fv 2>/dev/null || true
    docker images -qa|docker rmi -f 2>/dev/null || true
)

# TODO: also test fully prebuilt kubeadm-dind-cluster image

if [ ! -d kubernetes ]; then
    git clone https://github.com/kubernetes/kubernetes.git
fi

cd kubernetes
git checkout v1.5.3

../dind-cluster.sh up
# e2e is too heavy for Travis VMs :(
# ../dind-cluster.sh e2e
cluster/kubectl.sh get pods -n kube-system | grep kube-dns
../dind-cluster.sh down
