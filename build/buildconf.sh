# Version 1.6.9
KUBEADM_URL_1_6='https://storage.googleapis.com/kubernetes-release/release/v1.6.9/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_6=96ed4a8ad999e469882d867ae1b7dfbe8c1d7894
HYPERKUBE_URL_1_6='https://storage.googleapis.com/kubernetes-release/release/v1.6.9/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_6=bdbed1ef845d701d4c55cf0a905d1e600aec5b23

# Version 1.7.8
KUBEADM_URL_1_7='https://storage.googleapis.com/kubernetes-release/release/v1.7.8/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_7=c79edbc8942a064be20026b51070d0cfb71e3529
HYPERKUBE_URL_1_7='https://storage.googleapis.com/kubernetes-release/release/v1.7.8/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_7=22aec18da9935fe0a2208225c40ff820898eb010

# Version 1.8.1
KUBEADM_URL_1_8='https://storage.googleapis.com/kubernetes-release/release/v1.8.1/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_8=d63518b06fa3694af808fb9a9d69be0cb53d33e7
HYPERKUBE_URL_1_8='https://storage.googleapis.com/kubernetes-release/release/v1.8.1/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_8=0649c9b16ba18028f5b449df882844463adf7a8a

# url and sha1sum of kubeadm binary -- only used for prebuilt kubeadm
KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_8}}
KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_8}}

# url and sha1sum of hyperkube binary -- only used for prebuilt hyperkube
HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_8}}
HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_8}}
