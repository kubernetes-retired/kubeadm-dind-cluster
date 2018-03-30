# Version 1.7.15
KUBEADM_URL_1_7='https://storage.googleapis.com/kubernetes-release/release/v1.7.15/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_7=b7f12f329192d37386ace277edd816b034b7f8ee
HYPERKUBE_URL_1_7='https://storage.googleapis.com/kubernetes-release/release/v1.7.15/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_7=86aab83667820d0444a3c4d7dc5ed5788237f91d

# Version 1.8.10
KUBEADM_URL_1_8='https://storage.googleapis.com/kubernetes-release/release/v1.8.10/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_8=61a87be3c3aca1e0c40ca6e0a975bdbce15eb3f1
HYPERKUBE_URL_1_8='https://storage.googleapis.com/kubernetes-release/release/v1.8.10/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_8=59c85373484ff70291f8bc706c4440fe8d96ce52

# Version 1.9.6
KUBEADM_URL_1_9='https://storage.googleapis.com/kubernetes-release/release/v1.9.6/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_9=3eba73297aac155bcebc9d006eb1ca0cf7ff86f0
HYPERKUBE_URL_1_9='https://storage.googleapis.com/kubernetes-release/release/v1.9.6/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_9=f456848d59eb7e42f59f9d11d46804ee43e6abd8

# Version 1.10.0
KUBEADM_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.0/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_10=ba8ba627c1b3eb576835098ce41c1c9895bbbcee
HYPERKUBE_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.0/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_10=38a2c236a67d0ccbb3ac9404ace6a2705341fb7a

# url and sha1sum of kubeadm binary -- only used for prebuilt kubeadm
KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_9}}
KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_9}}

# url and sha1sum of hyperkube binary -- only used for prebuilt hyperkube
HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_9}}
HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_9}}
