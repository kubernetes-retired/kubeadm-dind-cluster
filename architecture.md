# Architecture of kubeadm-dind-cluster

Base image:

* contains systemd, docker and helper scripts
* contains saved+archived pre-pulled images as .tar
* contains hypokube image in the same .tar as pre-pulled images
* used as the base for prebuilt images
* when used directly expects prebuilt binaries
  * specified either by url
  * or as [build] to pull them from build containers

Important points:
* there's separate volume mounted at /k8s holding hyperkube and
  kubeadm binaries which is created during initial cluster startup and
  is updated when k8s is rebuilt from source (we can't just use k8s
  build data container in the latter case because it may be removed at
  any moment).
* kubectl is a symlink to hyperkube binary in that volume
* loading pre-pulled images is skipped if earlier /dind exists
* when kubeadm is started, cached docker directories may be reused
  but filesystem differences are not applied
* kubeadm is executed
  * upon the first cluster startup on this particular docker
  * after ./dind-cluster.sh clean
  * when k8s binaries are rebuilt

How binary injection works in `wrapkubeadm`:

1. Start docker daemon
1. Purge any remaining containers
1. Remove saved filesystem diffs for the current node
1. Get a hash of hyperkube binary
1. Check if hypokube image with tag = hyperkube hash exists
1. If it doesn't exist, remove any non-base hypokube images and build new one with binaries
1. Enable kubelet service and start kubeadm
1. Patch kube-proxy daemonset so it
   * disables conntrack
   * mounts /hyperkube from hostPath /k8s/hyperkube
1. Patch apiserver static pod so it
   * has necessary feature gates
   * mounts /hyperkube from hostPath /k8s/hyperkube
1. Patch controller-manager and scheduler static pods so they mount
   /hyperkube from hostPath /k8s/hyperkube
