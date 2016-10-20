# based on cluster/images/hyperkube/Dockerfile from k8s
FROM debian:jessie

RUN DEBIAN_FRONTEND=noninteractive apt-get update -y \
    && DEBIAN_FRONTEND=noninteractive apt-get -yy -q install \
    iptables \
    conntrack \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y \
    && DEBIAN_FRONTEND=noninteractive apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* # CACHEBUST

RUN ln -s /hyperkube /apiserver \
 && ln -s /hyperkube /controller-manager \
 && ln -s /hyperkube /federation-apiserver \
 && ln -s /hyperkube /federation-controller-manager \
 && ln -s /hyperkube /kubectl \
 && ln -s /hyperkube /kubelet \
 && ln -s /hyperkube /proxy \
 && ln -s /hyperkube /scheduler

# Copy the hyperkube binary
COPY hyperkube /hyperkube
