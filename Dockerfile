FROM mirantis/kubeadm-dind-cluster:bare-v4

# the following args should be set for derived images
ARG PREBUILT_KUBEADM_AND_KUBECTL
ARG KUBEADM_SHA1
ARG KUBECTL_SHA1
ARG HYPERKUBE_IMAGE

RUN echo -n "${HYPERKUBE_IMAGE}" >/hyperkube_image_name
RUN if [ -n "${PREBUILT_KUBEADM_AND_KUBECTL}" ]; then \
      curl -sSL https://storage.googleapis.com/kubernetes-release/release/v1.5.3/bin/linux/amd64/kubeadm > /usr/sbin/kubeadm && \
      if [ -n "${KUBEADM_SHA1}" ]; then echo "${KUBEADM_SHA1} /usr/sbin/kubeadm" | sha1sum -c; fi && \
      chmod +x /usr/sbin/kubeadm; \
      curl -sSL https://storage.googleapis.com/kubernetes-release/release/v1.5.3/bin/linux/amd64/kubectl > /usr/bin/kubectl && \
      if [ -n "${KUBECTL_SHA1}" ]; then echo "${KUBECTL_SHA1} /usr/bin/kubectl" | sha1sum -c; fi && \
      chmod +x /usr/bin/kubectl; \
    fi
# COPY save.tar.gz /
COPY save.tar /

ENTRYPOINT ["/sbin/dind_init"]
