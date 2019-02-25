# Version 1.10.13
KUBEADM_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.13/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_10=a577dd72a1a4a1a82468d9ce2375c33e9a8a5adf
HYPERKUBE_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.13/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_10=bb219f362e1e542fef6563c01c6556e55338c61e
KUBECTL_LINUX_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.13/bin/linux/amd64/kubectl'
KUBECTL_LINUX_SHA1_1_10=37c46a35edbe69e28a65a872e735c154402cd4a6
KUBECTL_DARWIN_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.13/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_10=220b0dc38fd7c9a5aeb412589172020b6819e1b3

# Version 1.11.7
KUBEADM_URL_1_11='https://storage.googleapis.com/kubernetes-release/release/v1.11.7/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_11=9a98fff2414f93a93115fb8b304a6bba92e28a60
HYPERKUBE_URL_1_11='https://storage.googleapis.com/kubernetes-release/release/v1.11.7/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_11=6b027bc6d0c2070ccda0e695880145e189c82f1e
KUBECTL_LINUX_URL_1_11='https://storage.googleapis.com/kubernetes-release/release/v1.11.7/bin/linux/amd64/kubectl'
KUBECTL_LINUX_SHA1_1_11=142b72418855b985b8a89e81f17df9d5fb88f1a9
KUBECTL_DARWIN_URL_1_11='https://storage.googleapis.com/kubernetes-release/release/v1.11.7/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_11=9bd37b3eda2fae9f83cc7bcd584216f85ba17304

# Version 1.12.5
KUBEADM_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.5/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_12=c62767b492bdf98bf90ead913dfad2e94dec80f4
HYPERKUBE_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.5/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_12=26ca10c97011e96e5ca55deae3bce1f829e8d194
KUBECTL_LINUX_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.5/bin/linux/amd64/kubectl'
KUBECTL_LINUX_SHA1_1_12=fe8a1096c9a9167725eeb55ade4625b1fc67c270
KUBECTL_DARWIN_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.5/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_12=715663dd9f2e34f2d195bc664174b17f51094740

# Version 1.13.3
KUBEADM_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.3/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_13=a89c340c5128be555d560f6cd18b450030c08f73
HYPERKUBE_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.3/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_13=ce2fdb27fc32a06d8124b7e97cf61c21c1e2f02e
KUBECTL_LINUX_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.3/bin/linux/amd64/kubectl'
KUBECTL_LINUX_SHA1_1_13=6e332647317032e5982db98f4abf80c88c8b3de2
KUBECTL_DARWIN_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.3/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_13=45a1c5037f139af53e00a0c310bf04fa158a862e

# url and sha1sum of hyperkube binary -- only used for prebuilt hyperkube
KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_13}}
KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_13}}
HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_13}}
HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_13}}
KUBECTL_LINUX_URL=${KUBECTL_LINUX_URL:-${KUBECTL_LINUX_URL_1_13}}
KUBECTL_LINUX_SHA1=${KUBECTL_LINUX_SHA1:-${KUBECTL_LINUX_SHA1_1_13}}
KUBECTL_DARWIN_URL=${KUBECTL_DARWIN_URL:-${KUBECTL_DARWIN_URL_1_13}}
KUBECTL_DARWIN_SHA1=${KUBECTL_DARWIN_SHA1:-${KUBECTL_DARWIN_SHA1_1_13}}

K8S_VERSIONS="1.10 1.11 1.12 1.13"
