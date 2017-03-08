# DIND subnet (/16 is always used)
DIND_SUBNET=10.192.0.0

# Apiserver port
APISERVER_PORT=${APISERVER_PORT:-8080}

# Number of nodes
NUM_NODES=${NUM_NODES:-2}

# Use non-dockerized build
KUBEADM_DIND_LOCAL=

# Use prebuilt DIND image
DIND_IMAGE="${DIND_IMAGE:-mirantis/kubeadm-dind-cluster:v1.5}"

# Set to non-empty string to make CRI work in Kubernetes 1.5.x
ENABLE_STREAMING_PROXY_REDIRECTS=

# Set to non-empty string to enable building kubeadm
# BUILD_KUBEADM=y

# Set to non-empty string to enable building hyperkube
# BUILD_HYPERKUBE=y

# Set to true to deploy k8s dashboard
DEPLOY_DASHBOARD=y
