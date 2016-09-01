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
