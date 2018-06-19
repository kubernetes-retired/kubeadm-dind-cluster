FROM mirantis/kubeadm-dind-cluster:bare-v4

# the following args should be set for derived images

#Todo: download prebuilt hyperkube (not kubectl!) & kubeadm into /k8s
ARG PREBUILT_KUBEADM_AND_HYPERKUBE
ARG KUBEADM_URL
ARG KUBEADM_SHA1
ARG HYPERKUBE_URL
ARG HYPERKUBE_SHA1

RUN if [ -n "${KUBEADM_URL}" ]; then \
      mkdir -p /k8s && \
      curl -sSL "${KUBEADM_URL}" > /k8s/kubeadm && \
      if [ -n "${KUBEADM_SHA1}" ]; then echo "${KUBEADM_SHA1}  /k8s/kubeadm" | sha1sum -c; fi && \
      chmod +x /k8s/kubeadm; \
    fi; \
    if [ -n "${HYPERKUBE_URL}" ]; then \
      curl -sSL "${HYPERKUBE_URL}" > /k8s/hyperkube && \
      if [ -n "${HYPERKUBE_SHA1}" ]; then echo "${HYPERKUBE_SHA1}  /k8s/hyperkube" | sha1sum -c; fi && \
      chmod +x /k8s/hyperkube; \
    fi
COPY save.tar.lz4 /

ENTRYPOINT ["/sbin/dind_init"]
