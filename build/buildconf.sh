# Version 1.5.4
KUBEADM_URL_1_5='https://storage.googleapis.com/kubernetes-release/release/v1.5.4/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_5=f56ba79b270105cccccd9acc9c7db9895d7da81b
HYPERKUBE_URL_1_5='https://storage.googleapis.com/kubernetes-release/release/v1.5.4/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_5=5b4209d12ae296dde2f01566ad8be3b93beff845

# Version 1.6.6
KUBEADM_URL_1_6='https://storage.googleapis.com/kubernetes-release/release/v1.6.6/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_6=e2eb3dd2b71fdfb2d5a33a260b52a8f7f3b060a7
HYPERKUBE_URL_1_6='https://storage.googleapis.com/kubernetes-release/release/v1.6.6/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_6=bb741aba5760c751f3ed661debc583e5c8e62cd6

# Version 1.7.0
KUBEADM_URL_1_7='https://storage.googleapis.com/kubernetes-release/release/v1.7.0/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_7=fca7334a26c3e14ad6fde64cd5209e0e64b3ba8c
HYPERKUBE_URL_1_7='https://storage.googleapis.com/kubernetes-release/release/v1.7.0/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_7=50e7376ef9ebe12d8492b5ce1d70e0d9d933d814

# KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_5}}
# KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_5}}

# HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_5}}
# HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_5}}

# HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_6}}
# HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_6}}

# url and sha1sum of kubeadm binary -- only used for prebuilt kubeadm
KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_7}}
KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_7}}

# url and sha1sum of hyperkube binary -- only used for prebuilt hyperkube
HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_7}}
HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_7}}
