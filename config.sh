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
