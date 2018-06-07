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

# Some parts are taken from here:
# https://github.com/kubernetes/test-infra/blob/master/dind/base/Dockerfile

# Copyright 2017 The Kubernetes Authors.
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
FROM k8s.gcr.io/debian-base-amd64:0.3

STOPSIGNAL SIGRTMIN+3

LABEL mirantis.kubeadm_dind_cluster=1

ENV ARCH amd64
ENV CNI_VERSION=v0.7.1
ENV CNI_ARCHIVE=cni-plugins-"${ARCH}"-"${CNI_VERSION}".tgz
ENV CNI_SHA1=fb29e20401d3e9598a1d8e8d7992970a36de5e05

# make systemd behave correctly in Docker container
# (e.g. accept systemd.setenv args, etc.)
ENV container docker

ARG DEBIAN_FRONTEND=noninteractive
RUN clean-install apt-utils \
    apt-transport-https \
    bash \
    bridge-utils \
    ca-certificates \
    curl \
    e2fsprogs \
    ebtables \
    ethtool \
    gnupg2 \
    ipcalc \
    iptables \
    iproute2 \
    iputils-ping \
    jq \
    kmod \
    lsb-core \
    less \
    lzma \
    liblz4-tool \
    mount \
    net-tools \
    procps \
    socat \
    software-properties-common \
    util-linux \
    vim \
    systemd \
    systemd-sysv \
    sysvinit-utils

# Install docker.
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - && apt-key fingerprint 0EBFCD88 && add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/debian \
    $(lsb_release -cs) \
    stable"
RUN clean-install docker-ce=17.03.2~ce-0~debian-stretch

RUN mkdir -p /hypokube /etc/systemd/system/docker.service.d /var/lib/kubelet

COPY hypokube.dkr /hypokube/
COPY kubelet.service /lib/systemd/system/
COPY dindnet.service /lib/systemd/system/
COPY docker.service /lib/systemd/system/docker.service
COPY wrapkubeadm /usr/local/bin/
COPY start_services /usr/local/bin/
COPY rundocker /usr/local/bin
COPY dindnet /usr/local/bin
COPY snapshot /usr/local/bin
COPY kubeadm.conf.tmpl /etc/kubeadm.conf.tmpl

# Remove unwanted systemd services.
# TODO: use 'systemctl mask' to disable units
# See here for example: https://github.com/docker/docker/issues/27202#issuecomment-253579916
RUN for i in /lib/systemd/system/sysinit.target.wants/*; do [ "${i##*/}" = "systemd-tmpfiles-setup.service" ] || rm -f "$i"; done; \
  rm -f /lib/systemd/system/multi-user.target.wants/*;\
  rm -f /etc/systemd/system/*.wants/*;\
  rm -f /lib/systemd/system/local-fs.target.wants/*; \
  rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
  rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
  rm -f /lib/systemd/system/basic.target.wants/*;\
  rm -f /lib/systemd/system/anaconda.target.wants/*;

RUN chmod +x /usr/local/bin/rundocker /usr/local/bin/dindnet /usr/local/bin/snapshot && \
    mkdir -p /opt/cni/bin && \
    curl -sSL --retry 5 https://github.com/containernetworking/plugins/releases/download/"${CNI_VERSION}"/"${CNI_ARCHIVE}" >"/tmp/${CNI_ARCHIVE}" && \
      echo "${CNI_SHA1}  /tmp/${CNI_ARCHIVE}" | sha1sum -c && \
      tar -C /opt/cni/bin -xzf "/tmp/${CNI_ARCHIVE}" && \
      rm -f "/tmp/${CNI_ARCHIVE}" && \
    mkdir -p /etc/systemd/system/docker.service.wants && \
    ln -s /lib/systemd/system/dindnet.service /etc/systemd/system/docker.service.wants/ && \
    ln -s /k8s/hyperkube /usr/bin/kubectl && \
    ln -s /k8s/hyperkube /usr/bin/kubelet && \
    ln -s /k8s/kubeadm /usr/bin/kubeadm

# TODO: move getty target removal to the base image

EXPOSE 8080

RUN ln -fs /sbin/init /sbin/dind_init
ENTRYPOINT ["/sbin/dind_init"]
