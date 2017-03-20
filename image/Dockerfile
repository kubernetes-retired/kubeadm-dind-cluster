# Copyright 2017 Mirantis
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ci-xenial-systemd image source: https://github.com/errordeveloper/kubeadm-ci-dind
# The tag includes commit id
FROM gcr.io/kubeadm/ci-xenial-systemd:base-master-6f6ae74260bfa1b6d97251e6e0191489aeff0939

LABEL mirantis.kubeadm_dind_cluster=1

ARG CNI_RELEASE=07a8a28637e97b22eb8dfe710eeae1344f69d16e

ENV ARCH amd64

# make systemd behave correctly in Docker container
# (e.g. accept systemd.setenv args, etc.)
ENV container docker

RUN mkdir -p /hypokube /etc/systemd/system/docker.service.d

COPY hypokube.dkr /hypokube/
COPY kubelet.service /lib/systemd/system/
COPY dindnet.service /lib/systemd/system/
COPY 20-fs.conf /etc/systemd/system/docker.service.d/
COPY wrapkubeadm /usr/local/bin/
COPY start_services /usr/local/bin/
COPY rundocker /usr/local/bin
COPY dindnet /usr/local/bin
COPY snapshot /usr/local/bin

# TODO: use 'systemctl mask' to disable units
# See here for example: https://github.com/docker/docker/issues/27202#issuecomment-253579916
RUN apt-get -qq update && \
    apt-mark unhold docker-engine && \
    DEBIAN_FRONTEND=noninteractive apt-get install docker-engine=1.12.6-0~ubuntu-xenial -qqy && \
    apt-mark hold docker-engine && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -qqy && \
    DEBIAN_FRONTEND=noninteractive apt-get install bridge-utils net-tools iproute2 iputils-ping tcpdump ipcalc jq curl liblz4-tool -qqy && \
    apt-get -qq -y autoremove && \
    apt-get -qq clean && \
    mkdir -p /etc/systemd/system/kubelet.service.d /etc/cni/net.d && \
    rm -f /lib/systemd/system/multi-user.target.wants/getty.target /lib/systemd/system/sysinit.target.wants/systemd-udev* /lib/systemd/system/sockets.target.wants/systemd-udev* && \
    chmod +x /usr/local/bin/rundocker /usr/local/bin/dindnet /usr/local/bin/snapshot && \
    mkdir -p /opt/cni/bin && \
    curl -sSL --retry 5 https://storage.googleapis.com/kubernetes-release/network-plugins/cni-${ARCH}-${CNI_RELEASE}.tar.gz | \
      tar -C /opt/cni -xz && \
    mkdir -p /etc/systemd/system/docker.service.wants && \
    ln -s /lib/systemd/system/dindnet.service /etc/systemd/system/docker.service.wants/ && \
    ln -s /k8s/hyperkube /usr/bin/kubectl && \
    ln -s /k8s/kubeadm /usr/bin/kubeadm

# TODO: move getty target removal to the base image

EXPOSE 8080

# TBD: update gcr.io/kubeadm/ci-xenial-systemd:base / bare
RUN ln -fs /sbin/init /sbin/dind_init
ENTRYPOINT ["/sbin/dind_init"]
