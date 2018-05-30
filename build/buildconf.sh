# Version 1.8.11
KUBEADM_URL_1_8='https://storage.googleapis.com/kubernetes-release/release/v1.8.11/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_8=dbdbaf6f31dc1111b38a80fa8af29024924d1fc0
HYPERKUBE_URL_1_8='https://storage.googleapis.com/kubernetes-release/release/v1.8.11/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_8=cbcb32519807c15cf1a55efb86ff3b22ddf28eb9
KUBECTL_URL_1_8='https://storage.googleapis.com/kubernetes-release/release/v1.8.11/bin/linux/amd64/kubectl'
KUBECTL_SHA1_1_8=6a089bec1802611ad9f5120c486a6e0e00095279
KUBECTL_DARWIN_URL_1_8='https://storage.googleapis.com/kubernetes-release/release/v1.8.11/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_8=d0b4c54e65b66e106758a84cddb6a5528527b017

# Version 1.9.7
KUBEADM_URL_1_9='https://storage.googleapis.com/kubernetes-release/release/v1.9.7/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_9=794841e3f05ccd7f6b6759d487beb14cf4812273
HYPERKUBE_URL_1_9='https://storage.googleapis.com/kubernetes-release/release/v1.9.7/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_9=79b333a44c20c5f8c40d45e09fa0898b88665dd5
KUBECTL_URL_1_9='https://storage.googleapis.com/kubernetes-release/release/v1.9.7/bin/linux/amd64/kubectl'
KUBECTL_SHA1_1_9=7425dbf67007cee328b85da3bf5155d01d3939e2
KUBECTL_DARWIN_URL_1_9='https://storage.googleapis.com/kubernetes-release/release/v1.9.7/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_9=b9f6122fe29dd29fff01194cc00a40a5451581fd

# Version 1.10.3
KUBEADM_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.3/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_10=ada2c07bbade36897f340cb951ce6e9802ab73bb
HYPERKUBE_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.3/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_10=f8546624c6c4001e199c4eaf8b86d968e74b19cc
KUBECTL_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.3/bin/linux/amd64/kubectl'
KUBECTL_SHA1_1_10=94f996d645e74634a4be67bbb5417f892774230b
KUBECTL_DARWIN_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.3/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_10=226442dd0011c1eb9a50b7996652680f6a45fe36
# url and sha1sum of kubeadm binary -- only used for prebuilt kubeadm
KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_10}}
KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_10}}

# url and sha1sum of hyperkube binary -- only used for prebuilt hyperkube
HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_10}}
HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_10}}
