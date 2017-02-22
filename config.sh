# Apiserver port
APISERVER_PORT=${APISERVER_PORT:-8080}

# Number of nodes
NUM_NODES=${NUM_NODES:-2}

# Use overlay driver
USE_OVERLAY=${USE_OVERLAY:-y}

# Use non-dockerized build
KUBEADM_DIND_LOCAL=

# Use prebuilt DIND image
# PREBUILT_DIND_IMAGE=ishvedunov/kubeadm-dind-cluster:3-v1.5.3
PREBUILT_DIND_IMAGE=

# Set to non-empty string to make CRI work in Kubernetes 1.5.x
ENABLE_STREAMING_PROXY_REDIRECTS=

# Install prebuilt hyperkube image
#PREBUILT_HYPERKUBE_IMAGE=${PREBUILT_HYPERKUBE_IMAGE:-gcr.io/google_containers/hyperkube:v1.5.3}
#PREBUILT_HYPERKUBE_IMAGE=${PREBUILT_HYPERKUBE_IMAGE:-gcr.io/google_containers/hyperkube:v1.4.9}

# Download prebuilt kubeadm & kubectl for use inside DIND container
# PREBUILT_KUBEADM_AND_KUBECTL=${PREBUILT_KUBEADM_AND_KUBECTL:-v1.5.3}

# sha1sum of kubeadm binary -- only used for prebuilt kubeadm
# (obtained from https://storage.googleapis.com/kubernetes-release/release/v1.5.3/bin/linux/amd64/kubeadm.sha1)
KUBEADM_SHA1=${KUBEADM_SHA1:-e99b0aa7dd7ec0b69c4accf8b1b2039c2f2749b7}

# sha1sum of kubectl binary -- only used for prebuilt kubectl
# (obtained from https://storage.googleapis.com/kubernetes-release/release/v1.5.3/bin/linux/amd64/kubectl.sha1)
KUBECTL_SHA1=${KUBECTL_SHA1:-295ced9fdbd4e1efd27d44f6322b4ef19ae10a12}
