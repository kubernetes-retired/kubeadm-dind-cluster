# Version 1.4.9
HYPERKUBE_URL_1_4='https://storage.googleapis.com/kubernetes-release/release/v1.4.9/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_4=d99b70a8496922959b6013ba2bc98f4cde868ec0

# Version 1.5.4
KUBEADM_URL_1_5='https://storage.googleapis.com/kubernetes-release/release/v1.5.4/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_5=f56ba79b270105cccccd9acc9c7db9895d7da81b
HYPERKUBE_URL_1_5='https://storage.googleapis.com/kubernetes-release/release/v1.5.4/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_5=5b4209d12ae296dde2f01566ad8be3b93beff845

# Version 1.6.0-rc.1
KUBEADM_URL_1_6='https://storage.googleapis.com/kubernetes-release/release/v1.6.0-rc.1/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_6=9882833b8b3aaac1c91581897e448e2aad695ca2
HYPERKUBE_URL_1_6='https://storage.googleapis.com/kubernetes-release/release/v1.6.0-rc.1/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_6=c9d676b8e2e3107cf3036b91b1153b4dee87c3fa

# HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_4}}
# HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_4}}

# url and sha1sum of kubeadm binary -- only used for prebuilt kubeadm
KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_5}}
KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_5}}

# url and sha1sum of hyperkube binary -- only used for prebuilt hyperkube
HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_5}}
HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_5}}

# KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_6}}
# KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_6}}

# HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_6}}
# HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_6}}
