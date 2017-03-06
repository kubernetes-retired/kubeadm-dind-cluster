# Apiserver port
APISERVER_PORT=${APISERVER_PORT:-8080}

# Number of nodes
NUM_NODES=${NUM_NODES:-2}

# Use non-dockerized build
KUBEADM_DIND_LOCAL=

# Use prebuilt DIND image
# PREBUILT_DIND_IMAGE=ishvedunov/kubeadm-dind-cluster:3-v1.5.3
PREBUILT_DIND_IMAGE="${PREBUILT_DIND_IMAGE:-}"

# Set to non-empty string to make CRI work in Kubernetes 1.5.x
ENABLE_STREAMING_PROXY_REDIRECTS=

# Set to non-empty string to enable building kubeadm
# BUILD_KUBEADM=y

# Set to non-empty string to enable building hyperkube
# BUILD_HYPERKUBE=y

# Install prebuilt hyperkube image
#PREBUILT_HYPERKUBE_IMAGE=${PREBUILT_HYPERKUBE_IMAGE:-gcr.io/google_containers/hyperkube:v1.5.3}
#PREBUILT_HYPERKUBE_IMAGE=${PREBUILT_HYPERKUBE_IMAGE:-gcr.io/google_containers/hyperkube:v1.4.9}

# url and sha1sum of kubeadm binary -- only used for prebuilt kubeadm
KUBEADM_URL=${KUBEADM_URL:-https://storage.googleapis.com/kubernetes-release/release/v1.5.3/bin/linux/amd64/kubeadm}
KUBEADM_SHA1=${KUBEADM_SHA1:-e99b0aa7dd7ec0b69c4accf8b1b2039c2f2749b7}

# url and sha1sum of hyperkube binary -- only used for prebuilt hyperkube
HYPERKUBE_URL=${HYPERKUBE_URL:-https://storage.googleapis.com/kubernetes-release/release/v1.5.3/bin/linux/amd64/hyperkube}
HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-74dc5c4eb8c7077ecbad31d918d28a268fa447e7}
