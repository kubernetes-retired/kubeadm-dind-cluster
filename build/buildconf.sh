# Version 1.10.11
KUBEADM_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.11/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_10=d80c4d591ae61f60fb8c22dca2a9ef7dd6412dd9
HYPERKUBE_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.11/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_10=13a9ebddd89332d5937cc9215bd1c446d4e663af
KUBECTL_LINUX_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.11/bin/linux/amd64/kubectl'
KUBECTL_LINUX_SHA1_1_10=9ee2f78491cbf8dc76d644c23cfc8c955c34d55d
KUBECTL_DARWIN_URL_1_10='https://storage.googleapis.com/kubernetes-release/release/v1.10.11/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_10=1cfafe21222e7f5f809ba4e3e7a1471421998d37

# Version 1.11.5
KUBEADM_URL_1_11='https://storage.googleapis.com/kubernetes-release/release/v1.11.5/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_11=daec1f0ddd654ab2b7553312548e545623037366
HYPERKUBE_URL_1_11='https://storage.googleapis.com/kubernetes-release/release/v1.11.5/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_11=ddeddb33dfc581bdc3e101d7b17dc1dd2279657f
KUBECTL_LINUX_URL_1_11='https://storage.googleapis.com/kubernetes-release/release/v1.11.5/bin/linux/amd64/kubectl'
KUBECTL_LINUX_SHA1_1_11=feebec8e5649223e586fc45850d8659274c87797
KUBECTL_DARWIN_URL_1_11='https://storage.googleapis.com/kubernetes-release/release/v1.11.5/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_11=450e6e17fe65e9d24cbbe39702ad7aa9103662d7

# Version 1.12.3
KUBEADM_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.3/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_12=24d78afbd6bb3dc90cd048a1925eccc7cb4b05db
HYPERKUBE_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.3/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_12=c7ba79dff169b49beff3e8d2943a58adb6bcd7d1
KUBECTL_LINUX_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.3/bin/linux/amd64/kubectl'
KUBECTL_LINUX_SHA1_1_12=4248b9e621af7e902c9d23bf772a2ee8e50146c5
KUBECTL_DARWIN_URL_1_12='https://storage.googleapis.com/kubernetes-release/release/v1.12.3/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_12=c7d4086fbdc58d81419f7643304de0bf356e11df

# Version 1.13.0
KUBEADM_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_13=c40dccc3d6fd0b7a903b0663c7ecd84f37105a2f
HYPERKUBE_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_13=ce1d5c8a0d0f3afa506f624db7337452ac4c562f
KUBECTL_LINUX_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/linux/amd64/kubectl'
KUBECTL_LINUX_SHA1_1_13=5c619006fa45afce6efc51db819aff7d5ba7ef0e
KUBECTL_DARWIN_URL_1_13='https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/darwin/amd64/kubectl'
KUBECTL_DARWIN_SHA1_1_13=264df4722e8f70301dd150d455baeae4a855d2fc

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
