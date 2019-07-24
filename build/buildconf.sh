# Version 1.12.10
KUBEADM_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.10/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_12=5b12635420b19c267663e2d78c4a544fb5f63feb
HYPERKUBE_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.10/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_12=cdec1f1f6f8660e37f3f109ecc151e1d58b52501
KUBECTL_LINUX_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.10/bin/linux/amd64/kubectl'
KUBECTL_LINUX_SHA1_1_12=cc3606e6bcc65c685772f5491f5bd1bb53a55416
KUBECTL_DARWIN_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.10/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_12=89d1db0bdb061d083329c52f833609970bc3ecf5

# Version 1.13.8
KUBEADM_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.8/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_13=79b2076ab759c72c7f3b3ee1b5049cde9c24ed52
HYPERKUBE_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.8/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_13=6a420462afd661f91f6d55a16abc55bb5d0f6628
KUBECTL_LINUX_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.8/bin/linux/amd64/kubectl'
KUBECTL_LINUX_SHA1_1_13=21e2f9c768c991a5897582b8fae5c234a32cc088
KUBECTL_DARWIN_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.8/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_13=dc17274dd617ddebe041f5b90863273eb7be3fc5

# Version 1.14.4
KUBEADM_URL_1_14='https://storage.googleapis.com/kubernetes-release/release/v1.14.4/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_14=9b0103936d79b5a5ed42b1e7c7a62c580fa34a64
HYPERKUBE_URL_1_14='https://storage.googleapis.com/kubernetes-release/release/v1.14.4/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_14=112a3cd6f84bfbc3bd7389b5f9b6ab6c435a2863
KUBECTL_LINUX_URL_1_14='https://storage.googleapis.com/kubernetes-release/release/v1.14.4/bin/linux/amd64/kubectl'
KUBECTL_LINUX_SHA1_1_14=c055ce78bebd3af14050d3e3f6ea4306daa37b5f
KUBECTL_DARWIN_URL_1_14='https://storage.googleapis.com/kubernetes-release/release/v1.14.4/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_14=2ddaa5874a854eff191722622f977f6d8da29e2f

# Version 1.15.0
KUBEADM_URL_1_15='https://storage.googleapis.com/kubernetes-release/release/v1.15.0/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_15=f806e926a71eb034063ef12e1585a463082d126b
HYPERKUBE_URL_1_15='https://storage.googleapis.com/kubernetes-release/release/v1.15.0/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_15=3c7f951c7f3e38997a836580ea5f7b2e014a64f4
KUBECTL_LINUX_URL_1_15='https://storage.googleapis.com/kubernetes-release/release/v1.15.0/bin/linux/amd64/kubectl'
KUBECTL_LINUX_SHA1_1_15=d604417c2efba1413e2441f16de3be84d3d9b1ae
KUBECTL_DARWIN_URL_1_15='https://storage.googleapis.com/kubernetes-release/release/v1.15.0/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_15=57f15cab86e15e9351edcb0e0a2a7d9eee7acff7

# url and sha1sum of hyperkube binary -- only used for prebuilt hyperkube
KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_15}}
KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_15}}
HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_15}}
HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_15}}
KUBECTL_LINUX_URL=${KUBECTL_LINUX_URL:-${KUBECTL_LINUX_URL_1_15}}
KUBECTL_LINUX_SHA1=${KUBECTL_LINUX_SHA1:-${KUBECTL_LINUX_SHA1_1_15}}
KUBECTL_DARWIN_URL=${KUBECTL_DARWIN_URL:-${KUBECTL_DARWIN_URL_1_15}}
KUBECTL_DARWIN_SHA1=${KUBECTL_DARWIN_SHA1:-${KUBECTL_DARWIN_SHA1_1_15}}

K8S_VERSIONS='1.12 1.13 1.14 1.15'
