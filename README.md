# kubeadm-dind-cluster [![Build Status](https://travis-ci.org/Mirantis/kubeadm-dind-cluster.svg?branch=master)](https://travis-ci.org/Mirantis/kubeadm-dind-cluster)
A Kubernetes multi-node cluster for developer _of_ Kubernetes and
projects that extend Kubernetes. Based on kubeadm and DIND (Docker in
Docker).

Supports both local workflows and workflows utilizing powerful remote
machines/cloud instances for building Kubernetes, starting test
clusters and running e2e tests.

If you're an application developer, you may be better off with
[Minikube](https://github.com/kubernetes/minikube) because it's more
mature and less dependent on the local environment, but if you're
feeling adventurous you may give `kubeadm-dind-cluster` a try, too. In
particular you can run `kubeadm-dind-cluster` in CI environment such
as Travis without having issues with nested virtualization.

## Requirements
Docker 1.12+ is recommended. If you're not using one of the
preconfigured scripts (see below) and not building from source, it's
better to have `kubectl` executable in your path matching the
version of k8s binaries you're using (i.e. for example better don't
use `kubectl` 1.8.x with `hyperkube` 1.7.x).

`kubeadm-dind-cluster` supports k8s versions 1.7.x (tested with 1.7.12),
1.8.x (tested with 1.8.6) and 1.9.x (tested with 1.9.1).

**As of now, running `kubeadm-dind-cluster` on Docker with `btrfs`
storage driver is not supported.**

The problems include inability to properly clean up DIND volumes due
to a [docker bug](https://github.com/docker/docker/issues/9939) which
is not really fixed and, more importantly, a
[kubelet problem](https://github.com/kubernetes/kubernetes/issues/38337).
If you want to run `kubeadm-dind-cluster` on btrfs anyway, set
`RUN_ON_BTRFS_ANYWAY` environment variable to a non-empty value.

By default `kubeadm-dind-cluster` uses dockerized builds, so no Go
installation is necessary even if you're building Kubernetes from
source. If you want you can overridde this behavior by setting
`KUBEADM_DIND_LOCAL` to a non-empty value in [config.sh](config.sh).

### Mac OS X considerations

Ensure to have `md5sha1sum` installed. If not existing can be installed via `brew install md5sha1sum`.

When building Kubernetes from source on Mac OS X, it should be
possible to build `kubectl` locally, i.e. `make WHAT=cmd/kubectl` must
work.

## Using preconfigured scripts
`kubeadm-dind-cluster` currently provides preconfigured scripts for
Kubernetes 1.7, 1.8 and 1.9. This may be convenient for use with
projects that extend or use Kubernetes. For example, you can start
Kubernetes 1.8 like this:

```shell
$ wget https://cdn.rawgit.com/Mirantis/kubeadm-dind-cluster/master/fixed/dind-cluster-v1.8.sh
$ chmod +x dind-cluster-v1.8.sh

$ # start the cluster
$ ./dind-cluster-v1.8.sh up

$ # add kubectl directory to PATH
$ export PATH="$HOME/.kubeadm-dind-cluster:$PATH"

$ kubectl get nodes
NAME          STATUS    AGE       VERSION
kube-master   Ready     6m        v1.8.6
kube-node-1   Ready     5m        v1.8.6
kube-node-2   Ready     5m        v1.8.6

$ # k8s dashboard available at http://localhost:8080/ui

$ # restart the cluster, this should happen much quicker than initial startup
$ ./dind-cluster-v1.8.sh up

$ # stop the cluster
$ ./dind-cluster-v1.8.sh down

$ # remove DIND containers and volumes
$ ./dind-cluster-v1.8.sh clean
```

Replace 1.8 with 1.7 or 1.9 to use other Kubernetes versions.
**Important note:** you need to do `./dind-cluster....sh clean` when
you switch between Kubernetes versions (but no need to do this between
rebuilds if you use `BUILD_HYPERKUBE=y` like described below).

## Using with Kubernetes source
```shell
$ git clone git@github.com:Mirantis/kubeadm-dind-cluster.git ~/dind

$ cd ~/work/kubernetes/src/k8s.io/kubernetes

$ export BUILD_KUBEADM=y
$ export BUILD_HYPERKUBE=y

$ # build binaries+images and start the cluster
$ ~/dind/dind-cluster.sh up

$ kubectl get nodes
NAME          STATUS         AGE
kube-master   Ready,master   1m
kube-node-1   Ready          34s
kube-node-2   Ready          34s

$ # k8s dashboard available at http://localhost:8080/ui

$ # run conformance tests
$ ~/dind/dind-cluster.sh e2e

$ # restart the cluster rebuilding
$ ~/dind/dind-cluster.sh up

$ # run particular e2e test based on substring
$ ~/dind/dind-cluster.sh e2e "existing RC"

$ # shut down the cluster
$ ~/dind/dind-cluster.sh down
```

The first `dind/dind-cluster.sh up` invocation can be slow because it
needs to build the base image and Kubernetes binaries. Subsequent
invocations are much faster.

## IPv6 Mode (experimental)
To run Kubernetes in IPv6 only mode, set the environment variable IP_MODE
to "ipv6". There are additional customizations that you can make for IPv6,
to set the prefix used for DNS64, subnet prefix to use for DinD, and
the service subnet CIDR (among other settings - see dind-cluster.sh):

```shell
export EMBBEDDED_CONFIG=y
export DNS64_PREFIX=fd00:77:64:ff9b::
export DIND_SUBNET=fd00:77::
export SERVICE_CIDR=fd00:77:30::/110
```

As of November 28th, there are two IPv6 Kuberentes PRs in-flight. One is for
Kubenet and one for E2E tests (neither is required for IPv6 use). You can
cherry pick these PRs, if desired, and then set the BUILD_HYPERKUBE and
BUILD_KUBEADM flags, to include the changes in a local Kubernetes repo.

```
PR #56245 Updates kubenet CNI template for v0.3.1"
PR #52748 "Add brackets around IPv6 addrs in e2e test IP:port endpoints"

git fetch origin pull/56245/head:pr56245
git log --abbrev-commit pr56245 --oneline --abbrev-commit -n 1 | cut -f 1 -d" "

git fetch origin pull/52748/head:pr52748
git log --abbrev-commit pr52748 --oneline --abbrev-commit -n 1 | cut -f 1 -d" "
```

Note: If you run into a kube-proxy crash during an attempt to modify conntrack
settings, you'll need to patch that is mentioned in this issue:

```
https://github.com/Mirantis/kubeadm-dind-cluster/issues/50
```

## Configuration
You may edit `config.sh` to override default settings. See comments in
[the file](config.sh) for more info. In particular, you can specify
CNI plugin to use via `CNI_PLUGIN` variable (`bridge`, `flannel`,
`calico`, `weave`).

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
[build/README.md](https://github.com/kubernetes/kubernetes/blob/master/build/README.md#really-remote-docker-engine)
in Kubernetes source.

When using a remote machine, you need to use ssh port forwarding
to forward `KUBE_RSYNC_PORT` and `APISERVER_PORT` you choose.

## Dumping cluster state

In case of CI environment such as Travis CI or Circle CI, it's often
desirable to get detailed cluster state for a failed job. Moreover, in case
of e.g. Travis CI there's no way to store the artefacts without using
an external service such as Amazon S3. Because of this,
kubeadm-dind-cluster supports dumping cluster state as a text block
that can be later split into individual files. For cases where there
are limits on the log size (e.g. 4 Mb log limit in Travis CI) it's also
possible to dump the lzma-compressed text block using base64 encoding.

The following commands can be used to work with cluster state dumps:
* `./dind-cluster.sh dump` dumps the cluster state as a text block
* `./dind-cluster.sh dump64` dumps the cluster state as a base64 blob
* `./dind-cluster.sh split-dump` splits the text block into individual
  files using `@@@ filename @@@` markers which are generated by
  `dump`.  The output is stored in `cluster-dump/` subdirectory of the
  current directory.
* `./dind-cluster.sh split-dump64` splits the base64 blob into
  separate files.  The blob has start and end markers so it can be
  extracted automatically from a build job log. The output is stored
  in `cluster-dump/` subdirectory of the current directory.

All of the above commands work with 'fixed' scripts, too.
kubeadm-dind-cluster's own Travis CI jobs dump base64 blobs in case of
failure. Such blocks can be then extracted directly from the output of
`travis` command line utility, e.g.

```shell
travis logs NNN.N | ./dind-cluster.sh split-dump64
```

The following information is currently stored in the dump:
* status and logs for the following systemd units on each DIND node, if the exist:
  `kubelet.service`, `dindnet.service`, `criproxy.service` and
  `dockershim.service` (the latter two are used by [CRI Proxy](https://github.com/Mirantis/criproxy))
* `ps auxww`, `docker ps -a`, `ip a` and `ip r` output for each DIND node
* the logs of all the containers of each pod in the cluster
* the output of `kubectl get all --all-namespaces -o wide`,
  `kubectl describe all --all-namespaces` and `kubectl get nodes -o wide`

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

Moreover, some projects that extend Kubernetes such as
[Virtlet](https://github.com/Mirantis/virtlet) need a way to start
kubernetes cluster quickly in CI environment without involving nested
virtulization. Current kubeadm-dind-cluster version provides means to
do this without the need to build Kubernetes locally.

## Additional notes
At the moment, all non-serial `[Conformance]` e2e tests pass for
clusters created by kubeadm-dind-cluster. `[Serial]...[Conformance]` tests
currently have some issues. You may still try running them though:
```
$ dind/dind-cluster.sh e2e-serial
```

## Related work

* kubeadm-dind-cluster was initially derived from
  [kubernetes-dind-cluster](https://github.com/sttts/kubernetes-dind-cluster),
  although as of now the code was completely rewritten.
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
