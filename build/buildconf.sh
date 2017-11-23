# Version 1.6.12
KUBEADM_URL_1_6='https://storage.googleapis.com/kubernetes-release/release/v1.6.12/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_6=fd4b93ad795c194461ad004a616a561c7572840b
HYPERKUBE_URL_1_6='https://storage.googleapis.com/kubernetes-release/release/v1.6.12/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_6=1f25b89c602570ba3451d4e849050424805de793

# Version 1.7.10
KUBEADM_URL_1_7='https://storage.googleapis.com/kubernetes-release/release/v1.7.10/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_7=6b536d165abff73a87fb9f0338cdd2c55804ae9a
HYPERKUBE_URL_1_7='https://storage.googleapis.com/kubernetes-release/release/v1.7.10/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_7=c4028e5010cf673c871918e3db9ca288a106da37

# Version 1.8.4
KUBEADM_URL_1_8='https://storage.googleapis.com/kubernetes-release/release/v1.8.4/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_8=da851284055fe9be8512a7e8272da0b42096d6cc
HYPERKUBE_URL_1_8='https://storage.googleapis.com/kubernetes-release/release/v1.8.4/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_8=d86a6d48fb6138dab210bed01e7941530302fe22

# url and sha1sum of kubeadm binary -- only used for prebuilt kubeadm
KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_8}}
KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_8}}

# url and sha1sum of hyperkube binary -- only used for prebuilt hyperkube
HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_8}}
HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_8}}
