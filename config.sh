# Optional: Deploy cluster web interface.
ENABLE_CLUSTER_UI="${ENABLE_CLUSTER_UI:-true}"

# Timeout (in seconds) to wait for each addon to come up
DOCKER_IN_DOCKER_ADDON_TIMEOUT="${DOCKER_IN_DOCKER_ADDON_TIMEOUT:-180}"

# Apiserver port
APISERVER_PORT=${APISERVER_PORT:-8080}

# Number of nodes
NUM_NODES=${NUM_NODES:-2}

# Use overlay driver
USE_OVERLAY=${USE_OVERLAY:-y}
