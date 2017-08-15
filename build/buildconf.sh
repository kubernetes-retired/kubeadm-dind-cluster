# Version 1.5.4
KUBEADM_URL_1_5='https://storage.googleapis.com/kubernetes-release/release/v1.5.4/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_5=f56ba79b270105cccccd9acc9c7db9895d7da81b
HYPERKUBE_URL_1_5='https://storage.googleapis.com/kubernetes-release/release/v1.5.4/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_5=5b4209d12ae296dde2f01566ad8be3b93beff845

# Version 1.6.8
KUBEADM_URL_1_6='https://storage.googleapis.com/kubernetes-release/release/v1.6.8/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_6=dd6ac1743103b9cfb125f32dd902ab07d2cf85a2
HYPERKUBE_URL_1_6='https://storage.googleapis.com/kubernetes-release/release/v1.6.8/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_6=218d820797bbabe92cc036c2caa48915977c777f

# Version 1.7.3
KUBEADM_URL_1_7='https://storage.googleapis.com/kubernetes-release/release/v1.7.3/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_7=9a9173220c153d99565736b626d13d03cb273d2c
HYPERKUBE_URL_1_7='https://storage.googleapis.com/kubernetes-release/release/v1.7.3/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_7=a74f4c4789b0b00c81370421dc395911e8cf54e8

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
