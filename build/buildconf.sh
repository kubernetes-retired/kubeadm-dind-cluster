# Version 1.9.11
KUBEADM_URL_1_9='https://storage.googleapis.com/kubernetes-release/release/v1.9.11/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_9=152e1dd6261f5e1aeda982fb3a5d17255860a830
HYPERKUBE_URL_1_9='https://storage.googleapis.com/kubernetes-release/release/v1.9.11/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_9=d23dc80fa2cd5f845912721afffba0e8fd9b1780
KUBECTL_URL_1_9='https://storage.googleapis.com/kubernetes-release/release/v1.9.11/bin/linux/amd64/kubectl'
KUBECTL_SHA1_1_9=3dedd41a077be12668c2ee322958dd3e9e554861
KUBECTL_DARWIN_URL_1_9='https://storage.googleapis.com/kubernetes-release/release/v1.9.11/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_9=3b436f60ff0399b3f521d549044513358487ce20

# Version 1.10.9
KUBEADM_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.9/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_10=5d300647b0512cc724248431211df92a4b6f987f
HYPERKUBE_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.9/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_10=a1899c421d3192f647ee6fa3927207bffdffbb6b
KUBECTL_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.9/bin/linux/amd64/kubectl'
KUBECTL_SHA1_1_10=bf3914630fe45b4f9ec1bc5e56f10fb30047f958
KUBECTL_DARWIN_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.9/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_10=6833874e0b24fa1857925423e4dc8aeaa322b7b3

# Version 1.11.3
KUBEADM_URL_1_11='https://storage.googleapis.com/kubernetes-release/release/v1.11.3/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_11=f127dccad906ee914af8b889bb60c07f402ed025
HYPERKUBE_URL_1_11='https://storage.googleapis.com/kubernetes-release/release/v1.11.3/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_11=4510415132722eed1add98c3352d7fa171667739
KUBECTL_URL_1_11='https://storage.googleapis.com/kubernetes-release/release/v1.11.3/bin/linux/amd64/kubectl'
KUBECTL_SHA1_1_11=5a336ea470a0053b1893fda89a538b6197566137
KUBECTL_DARWIN_URL_1_11='https://storage.googleapis.com/kubernetes-release/release/v1.11.3/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_11=4f519f6c225f2dd663a26c5c2390849324a577cb

# Version 1.12.1
KUBEADM_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.1/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_12=8f7de5a0236614bb89217b110368974dc19c78ec
HYPERKUBE_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.1/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_12=2212a4ab6091cdd4205c9b716886619d79eb8daf
KUBECTL_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.1/bin/linux/amd64/kubectl'
KUBECTL_SHA1_1_12=2135356e8e205816829f612062e1b5b4e1c81a17
KUBECTL_DARWIN_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.1/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_12=a99adb19c1fa0334ab9be37b3918e5de84436acd

# url and sha1sum of hyperkube binary -- only used for prebuilt hyperkube
KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_12}}
KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_12}}
HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_12}}
HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_12}}
