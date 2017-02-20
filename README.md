# kubeadm-dind-cluster [![Build Status](https://travis-ci.org/Mirantis/kubeadm-dind-cluster.svg?branch=master)](https://travis-ci.org/Mirantis/kubeadm-dind-cluster)
A Kubernetes multi-node cluster for developer _of_ Kubernetes. Based
on kubeadm and DIND (Docker in Docker).

Supports both local workflows and workflows utilizing powerful remote
machines/cloud instances for building Kubernetes, starting test
clusters and running e2e tests.

## Usage
```shell
$ cd kubernetes
$ git clone git@github.com:Mirantis/kubeadm-dind-cluster.git dind

$ # build binaries+images and start the cluster
$ dind/dind-cluster.sh up

$ kubectl get nodes
NAME         STATUS    AGE
172.17.0.2   Ready     2m
172.17.0.3   Ready     2m
172.17.0.4   Ready     2m

$ # run conformance tests
$ dind/dind-cluster.sh e2e

$ # rebuild binaries & update images
$ dind/dind-cluster.sh update

$ # restart the cluster
$ dind/dind-cluster.sh up

$ # run particular e2e test based on substring
$ dind/dind-cluster.sh e2e "existing RC"

$ # create 'bare' DIND container for experimentation
$ dind/dind-cluster.sh bare foobar -v /somedir:/somedir
$ docker exec foobar ls -l /

$ # shut down the cluster
$ dind/dind-cluster.sh down
```

The first `dind/dind-cluster.sh up` invocation can be slow because it
needs to build the base image and Kubernetes binaries. Subsequent
invocations are much faster.

## Configuration
You may edit `config.sh` to override default settings. See comments in
the file for more info.

## Requirements
On Linux, the only requirement is Docker (tested on 1.12.2). By
default kubeadm-dind-cluster uses dockerized builds, but this
can be overridden by setting `KUBEADM_DIND_LOCAL` to a non-empty
value in [config.sh](config.sh).

On Mac OS X, it should be possible to build `kubectl` locally,
i.e. `make WHAT=cmd/kubectl` must work.

## Remote Docker / GCE
It's possible to build Kubernetes on a remote machine running Docker.
kubeadm-dind-cluster can consume binaries directly from the build
data container without copying them back to developer's machine.
An example utilizing GCE instance is provided in [gce-setup.sh](gce-setup.sh).
You may try running it using `source` (`.`) so that docker-machine
shell environment is preserved, e.g.
```shell
. gce-setup.sh
```
The example is based on sample commands from
[build-tools/README.md](https://github.com/kubernetes/kubernetes/blob/master/build-tools/README.md#really-remote-docker-engine)
in Kubernetes source.

When using a remote machine, you need to use ssh port forwarding
to forward `KUBE_RSYNC_PORT` and `APISERVER_PORT` you choose.

## Motivation
`hack/local-up-cluster.sh` is widely used for k8s development. It has
a couple of serious issues though. First of all, it only supports
single node clusters, which means that it's hard to use it to work on
e.g. scheduler-related issues and e2e tests that require several nodes
can't be run. Another problem is that it has little resemblance to
real clusters.

There's also k8s vagrant provider, but it's quite slow. Besides,
`cluster/` directory in k8s source is now considered deprecated.

Another widely suggested solution for development clusters is
[minikube](https://github.com/kubernetes/minikube), but currently it's
not very well suited for development of Kubernetes itself. Besides,
it's currently only supports single node, too, unless used with
additional DIND layer like [nkube](https://github.com/marun/nkube).

[kubernetes-dind-cluster](https://github.com/sttts/kubernetes-dind-cluster)
is very nice & useful but uses a custom method of cluster setup
(same as 2nd problem with local-up-cluster).

There's also sometimes a need to use a powerful remote machine or a
cloud instance to build and test Kubernetes. Having Docker as the only
requirement for such machine would be nice. Builds and unit tests are
already covered by
[jbeda's work](https://github.com/kubernetes/kubernetes/pull/30787) on
dockerized builds, but being able to quickly start remote test
clusters and run e2e tests is also important.

kubeadm-dind-cluster uses kubeadm to create a cluster consisting of
docker containers instead of VMs. That's somewhat of a compromise but
allows one to (re)start clusters quickly which is quite important when
making changes to k8s source.

## Additional notes
At the moment, all non-serial `[Conformance]` e2e tests pass for
clusters created by kubeadm-dind-cluster. `[Serial]...[Conformance]` tests
currently have some issues. You may still try running them though:
```
$ dind/dind-cluster.sh e2e-serial
```
CNI isn't used currently. The option to use it will be added in near
future. For now, DIND containers' network interfaces are bridged together,
see [image/systemd/wrapkubeadm](image/systemd/wrapkubeadm).

## Related work

* kubeadm-dind-cluster was initially derived from
  [kubernetes-dind-cluster](https://github.com/sttts/kubernetes-dind-cluster).
  kubernetes-dind-cluster is somewhat faster but uses less standard
  way of k8s deployment. It also doesn't include support for consuming
  binaries from remote dockerized builds.
* [kubeadm-ci-dind](https://github.com/errordeveloper/kubeadm-ci-dind),
  [kubeadm-ci-packager](https://github.com/errordeveloper/kubeadm-ci-packager) and
  [kubeadm-ci-tester](https://github.com/errordeveloper/kubeadm-ci-tester).
  These projects are similar to kubeadm-dind-cluster but are intended primarily for CI.
  They include packaging step which is too slow for the purpose of having
  convenient k8s "playground". kubeadm-dind-cluster uses Docker images
  from `kubeadm-ci-dind`.
* [nkube](https://github.com/marun/nkube) starts
  Kubernetes-in-Kubernetes clusters.
