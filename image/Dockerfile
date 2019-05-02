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
FROM k8s.gcr.io/debian-base-amd64:0.4.1

STOPSIGNAL SIGRTMIN+3

LABEL mirantis.kubeadm_dind_cluster=1

ENV ARCH amd64
ENV CRICTL_VERSION=v1.12.0
ENV CRICTL_SHA256=e7d913bcce40bf54e37ab1d4b75013c823d0551e6bc088b217bc1893207b4844
ENV CNI_VERSION=v0.7.1
ENV CNI_ARCHIVE=cni-plugins-"${ARCH}"-"${CNI_VERSION}".tgz
ENV CNI_SHA1=fb29e20401d3e9598a1d8e8d7992970a36de5e05

# Specify CONTAINERD_VERSION if containerd which ships with Docker needs to be
# replaced. Note that containerd version must be specified w/o "v" prefix,
# e.g. v1.2.1
ENV CONTAINERD_VERSION=1.2.1
ENV CONTAINERD_SHA256=9818e3af4f9aac8d55fc3f66114346db1d1acd48d45f88b2cefd3d3bafb380e0

# make systemd behave correctly in Docker container
# (e.g. accept systemd.setenv args, etc.)
ENV container docker

ARG DEBIAN_FRONTEND=noninteractive
RUN clean-install \
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
    ipset \
    ipvsadm \
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
RUN clean-install docker-ce=5:18.09.0~3-0~debian-stretch && \
    sed -i '/^disabled_plugins/d' /etc/containerd/config.toml

RUN curl -sSL --retry 5 https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz >/tmp/crictl.tar.gz && \
    echo "${CRICTL_SHA256}  /tmp/crictl.tar.gz" | sha256sum -c && \
    tar -C /usr/local/bin -xvzf /tmp/crictl.tar.gz && \
    rm -f /tmp/crictl.tar.gz && \
    if [ ${CONTAINERD_VERSION} ]; then \
      curl -sSL --retry 5 https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}.linux-amd64.tar.gz >/tmp/containerd.tar.gz && \
      echo "${CONTAINERD_SHA256}  /tmp/containerd.tar.gz" | sha256sum -c && \
      tar -C /usr -xvzf /tmp/containerd.tar.gz && \
      rm -f /tmp/containerd.tar.gz; \
    fi

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
COPY kubeadm.conf.1.12.tmpl /etc/kubeadm.conf.1.12.tmpl
COPY kubeadm.conf.1.13.tmpl /etc/kubeadm.conf.1.13.tmpl
COPY dind-cluster-rbd /usr/bin/rbd
COPY node-info /

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
    ln -s /dind/containerd /var/lib/containerd && \
    mkdir -p /dind/containerd && \
    ln -s /k8s/hyperkube /usr/bin/kubectl && \
    ln -s /k8s/hyperkube /usr/bin/kubelet && \
    ln -s /k8s/kubeadm /usr/bin/kubeadm

# TODO: move getty target removal to the base image

EXPOSE 8080

RUN ln -fs /sbin/init /sbin/dind_init
ENTRYPOINT ["/sbin/dind_init"]
