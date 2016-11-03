# ci-xenial-systemd image source: https://github.com/errordeveloper/kubeadm-ci-dind
# The tag includes commit id
FROM gcr.io/kubeadm/ci-xenial-systemd:base-master-6f6ae74260bfa1b6d97251e6e0191489aeff0939

RUN apt-get -qq update && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -qqy && \
    DEBIAN_FRONTEND=noninteractive apt-get install bridge-utils net-tools iproute2 iputils-ping tcpdump ipcalc jq curl -qqy && \
    apt-get -qq -y autoremove && \
    apt-get -qq clean && \
    mkdir -p /etc/systemd/system/kubelet.service.d

COPY kubelet.service /lib/systemd/system/
COPY wrapkubeadm /usr/local/bin
COPY start_services /usr/local/bin

VOLUME ["/var/lib/docker2"]

EXPOSE 8080

# TBD: update gcr.io/kubeadm/ci-xenial-systemd:base / bare
RUN ln -fs /sbin/init /sbin/dind_init
ENTRYPOINT ["/sbin/dind_init"]
