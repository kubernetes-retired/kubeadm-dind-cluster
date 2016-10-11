# http://developers.redhat.com/blog/2016/09/13/running-systemd-in-a-non-privileged-container/
# SIGRTMIN+3 is the shutdown signal for systemd
FROM k8s.io/kubernetes-dind-base:v1

STOPSIGNAL SIGRTMIN+3
# TBD: # https://www.fedux.org/articles/2015/10/27/care-about-oomscoreadjust-in-your-systemd-enabled-docker-images.html?utm_source=rubyflow&utm_medium=linklog&utm_campaign=new_article

## TODO add tricks proposed by @marun https://github.com/kubernetes/release/pull/86#issuecomment-248185616
RUN apt-get -qq update && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -qqy && \
    DEBIAN_FRONTEND=noninteractive apt-get install systemd -qqy && \
    apt-get -qq -y autoremove && \
    apt-get -qq clean && \
    cd /lib/systemd/system/ && \
    (ls sysinit.target.wants/* multi-user.target.wants/* local-fs.target.wants/* | \
       grep -v systemd-tmpfiles-setup.service; \
       ls sockets.target.wants/*initctl*; \
       ls graphical.target.wants/*; \
       ls /etc/systemd/system/*.wants/*; \
       ls /var/lib/apt/lists/*) | xargs -n 1 rm -f -v && \
    ln -v -f /lib/systemd/system/multi-user.target /lib/systemd/system/default.target && \
    sed -i 's@ExecStart=.*@ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:8899 --storage-driver=overlay2@' \
        /lib/systemd/system/docker.service && \
    mkdir -p /etc/systemd/system/kubelet.service.d

COPY kubelet.service /lib/systemd/system/
COPY 10-kubeadm.conf /etc/systemd/system/kubelet.service.d/
COPY wrapkubeadm /usr/local/bin

CMD [ "/sbin/init" ]

# FIXME: --storage-driver=overlay2 fails with the following error:
# 'overlay2' is not supported over <unknown>
# (although it works fine when docker is started without systemd)
# See here:
# https://github.com/docker/docker/blob/b826bebda0cff2cc2d3083b954c810d2889eefe5/daemon/graphdriver/driver_linux.go#L89
# (GetFSMagic func)
# TBD: credits
