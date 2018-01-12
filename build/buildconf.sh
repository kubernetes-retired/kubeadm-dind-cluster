# Version 1.7.12
KUBEADM_URL_1_7='https://storage.googleapis.com/kubernetes-release/release/v1.7.12/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_7=0a42387387b4525363af2bb7db8c9e6b528165fd
HYPERKUBE_URL_1_7='https://storage.googleapis.com/kubernetes-release/release/v1.7.12/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_7=4dc029534a5d062c0468f3bc5fdda73810a042f6

# Version 1.8.6
KUBEADM_URL_1_8='https://storage.googleapis.com/kubernetes-release/release/v1.8.6/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_8=693e1810708eaf61d02cdecc45ede9fd0fc888bd
HYPERKUBE_URL_1_8='https://storage.googleapis.com/kubernetes-release/release/v1.8.6/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_8=3184d872172fafba8f3c7e039bfa0deb0c09b9c3

# Version 1.9.1
KUBEADM_URL_1_9='https://storage.googleapis.com/kubernetes-release/release/v1.9.1/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_9=9770b518ea2abf3302d036225dd7449d2d3d6136
HYPERKUBE_URL_1_9='https://storage.googleapis.com/kubernetes-release/release/v1.9.1/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_9=e4684850cae15501cf16ce6915a0b7dcbea60a35

# url and sha1sum of kubeadm binary -- only used for prebuilt kubeadm
KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_9}}
KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_9}}

# url and sha1sum of hyperkube binary -- only used for prebuilt hyperkube
HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_9}}
HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_9}}
