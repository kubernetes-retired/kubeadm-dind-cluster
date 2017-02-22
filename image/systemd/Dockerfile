# ci-xenial-systemd image source: https://github.com/errordeveloper/kubeadm-ci-dind
# The tag includes commit id
FROM gcr.io/kubeadm/ci-xenial-systemd:base-master-6f6ae74260bfa1b6d97251e6e0191489aeff0939

ARG PREBUILT_KUBEADM_AND_KUBECTL

COPY kubelet.service /lib/systemd/system/
COPY wrapkubeadm /usr/local/bin/
COPY start_services /usr/local/bin/
COPY kubelet /usr/local/bin/

# kubeadm package tries to restart kubelet during its installation
# via systemctl, so we need extra tricks to prevent it from doing so
RUN apt-get -qq update && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -qqy && \
    DEBIAN_FRONTEND=noninteractive apt-get install bridge-utils net-tools iproute2 iputils-ping tcpdump ipcalc jq curl -qqy && \
    if [ -n "${PREBUILT_KUBEADM_AND_KUBECTL}" ]; then \
      curl -sSL https://storage.googleapis.com/kubernetes-release/release/v1.5.3/bin/linux/amd64/kubeadm > /usr/sbin/kubeadm && \
      if [ -n "${KUBEADM_SHA1}" ]; then echo "${KUBEADM_SHA1} /usr/sbin/kubeadm" | sha1sum -c; fi && \
      chmod +x /usr/sbin/kubeadm; \
      curl -sSL https://storage.googleapis.com/kubernetes-release/release/v1.5.3/bin/linux/amd64/kubectl > /usr/bin/kubectl && \
      if [ -n "${KUBECTL_SHA1}" ]; then echo "${KUBECTL_SHA1} /usr/bin/kubectl" | sha1sum -c; fi && \
      chmod +x /usr/bin/kubectl; \
    fi && \
    apt-get -qq -y autoremove && \
    apt-get -qq clean && \
    mkdir -p /etc/systemd/system/kubelet.service.d /etc/kubernetes/cni/net.d && \
    rm -f /lib/systemd/system/multi-user.target.wants/getty.target && \
    chmod +x /usr/local/bin/kubelet

# TODO: move getty target removal to the base image

VOLUME ["/var/lib/docker2"]

EXPOSE 8080

# TBD: update gcr.io/kubeadm/ci-xenial-systemd:base / bare
RUN ln -fs /sbin/init /sbin/dind_init
ENTRYPOINT ["/sbin/dind_init"]
