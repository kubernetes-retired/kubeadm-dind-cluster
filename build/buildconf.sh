# Version 1.12.8
KUBEADM_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.8/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_12=c71653be73a66109b25f92322464ae7458557415
HYPERKUBE_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.8/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_12=42f34ac1137fa9447c1a8fe4386886f1febf8e03
KUBECTL_LINUX_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.8/bin/linux/amd64/kubectl'
KUBECTL_LINUX_SHA1_1_12=7110f444d9a0e8f74d76c3d09e108f1641696149
KUBECTL_DARWIN_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.8/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_12=cdd2169e5bbbccabf5e8f01afcb87b2381df7d2f

# Version 1.13.5
KUBEADM_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.5/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_13=555423deada0f55b16030aecdbcbb59fac879e4a
HYPERKUBE_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.5/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_13=425618bce9c3291c6a65611fc2036ab522ffd48d
KUBECTL_LINUX_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.5/bin/linux/amd64/kubectl'
KUBECTL_LINUX_SHA1_1_13=0e994d77be036cf9c7965f81248292dc8a11cd8c
KUBECTL_DARWIN_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.5/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_13=c99d60886cb6e68cb4725a930fca0421d9ee8732

# Version 1.14.1
KUBEADM_URL_1_14='https://storage.googleapis.com/kubernetes-release/release/v1.14.1/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_14=886e607321b4a7bf28d97e7833dcbfbb795d4613
HYPERKUBE_URL_1_14='https://storage.googleapis.com/kubernetes-release/release/v1.14.1/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_14=0012a3c9a0259990be1e6659fc642c80e8b90e8d
KUBECTL_LINUX_URL_1_14='https://storage.googleapis.com/kubernetes-release/release/v1.14.1/bin/linux/amd64/kubectl'
KUBECTL_LINUX_SHA1_1_14=fd57c812083d5dde4745b3216453d0e1e4ee64df
KUBECTL_DARWIN_URL_1_14='https://storage.googleapis.com/kubernetes-release/release/v1.14.1/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_14=fd537d239de8e0c9b5625fe87e3e15bb8649b608

# url and sha1sum of hyperkube binary -- only used for prebuilt hyperkube
KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_14}}
KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_14}}
HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_14}}
HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_14}}
KUBECTL_LINUX_URL=${KUBECTL_LINUX_URL:-${KUBECTL_LINUX_URL_1_14}}
KUBECTL_LINUX_SHA1=${KUBECTL_LINUX_SHA1:-${KUBECTL_LINUX_SHA1_1_14}}
KUBECTL_DARWIN_URL=${KUBECTL_DARWIN_URL:-${KUBECTL_DARWIN_URL_1_14}}
KUBECTL_DARWIN_SHA1=${KUBECTL_DARWIN_SHA1:-${KUBECTL_DARWIN_SHA1_1_14}}

K8S_VERSIONS="1.12 1.13 1.14"
