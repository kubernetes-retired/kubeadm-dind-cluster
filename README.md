# kubernetes-dind-cluster
A Kubernetes multi-node cluster for developer _of_ Kubernetes that launches in **36 seconds**

- works with [kubernetes master branch](https://github.com/kubernetes/kubernetes)
- compatible with Linux and Mac
- requires docker and docker-compose
- with kube-dns and dashboard

```shell
$ cd kubernetes
$ git clone git@github.com:sttts/kubernetes-dind-cluster.git dind

$ make
$ # only on Mac: build/run.sh make WHAT=cmd/hyperkube

$ dind/dind-up-cluster.sh
$ kubectl get nodes
NAME         STATUS    AGE
172.17.0.4   Ready     23s
172.17.0.7   Ready     21s

$ _output/local/bin/<OS>/<ARCH>/e2e.test --provider=dind \
  --kubeconfig ~/.kube/config -ginkgo.v=true \
  --host=https://localhost:6443 -ginkgo.focus="some.e2e.describe.pattern"

$ dind/dind-down-cluster.sh
```

## kubeadm support

**NOTE:** this is highly experimental

`dind/kubeadm.sh` makes it possible to bring up a DIND cluster using kubeadm.

```shell
$ cd kubernetes
$ git clone git@github.com:sttts/kubernetes-dind-cluster.git dind

$ build/run.sh make WHAT=cmd/hyperkube
$ make WHAT=cmd/kubeadm
$ make WHAT=cmd/kubectl
$ make WHAT=cmd/kubelet

$ # create master
$ dind/kubeadm-up.sh init

$ # add a couple of nodes
$ dind/kubeadm-up.sh join --token TOKEN_DISPLAYED_BY_INIT 172.17.0.2
$ dind/kubeadm-up.sh join --token TOKEN_DISPLAYED_BY_INIT 172.17.0.2

$ docker exec kube-master kubectl get nodes
NAME         STATUS    AGE
172.17.0.2   Ready     3m
172.17.0.3   Ready     2m
172.17.0.4   Ready     28s
```
