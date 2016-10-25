FROM gcr.io/kubeadm/ci-xenial-systemd:base

RUN apt-get -qq update && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -qqy && \
    DEBIAN_FRONTEND=noninteractive apt-get install bridge-utils net-tools iproute2 iputils-ping tcpdump ipcalc jq -qqy && \
    apt-get -qq -y autoremove && \
    apt-get -qq clean && \
    mkdir -p /etc/systemd/system/kubelet.service.d

COPY kubelet.service /lib/systemd/system/
COPY wrapkubeadm /usr/local/bin
COPY start_services /usr/local/bin

CMD [ "/sbin/init" ]
