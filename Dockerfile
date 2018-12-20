FROM mirantis/kubeadm-dind-cluster:bare-v4

LABEL mirantis.kubeadm_dind_cluster_final=1

# the following args should be set for derived images

#Todo: download prebuilt hyperkube (not kubectl!) & kubeadm into /k8s
ARG PREBUILT_KUBEADM_AND_HYPERKUBE
ARG KUBEADM_URL
ARG KUBEADM_SHA1
ARG HYPERKUBE_URL
ARG HYPERKUBE_SHA1
ARG KUBECTL_VERSION
ARG KUBECTL_LINUX_URL
ARG KUBECTL_LINUX_SHA1
ARG KUBECTL_DARWIN_URL
ARG KUBECTL_DARWIN_SHA1

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
    fi && \
    ( echo "export KUBECTL_VERSION=${KUBECTL_VERSION}" && \
      echo "export KUBECTL_LINUX_SHA1=${KUBECTL_LINUX_SHA1}" && \
      echo "export KUBECTL_LINUX_URL=${KUBECTL_LINUX_URL}" && \
      echo "export KUBECTL_DARWIN_SHA1=${KUBECTL_DARWIN_SHA1}" && \
      echo "export KUBECTL_DARWIN_URL=${KUBECTL_DARWIN_URL}" ) >/dind-env
COPY save.tar.lz4 /

ENTRYPOINT ["/sbin/dind_init"]
