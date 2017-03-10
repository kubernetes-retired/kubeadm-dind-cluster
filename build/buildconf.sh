# Version 1.4.9
HYPERKUBE_URL_1_4_9='https://storage.googleapis.com/kubernetes-release/release/v1.4.9/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_4_9=d99b70a8496922959b6013ba2bc98f4cde868ec0

# Version 1.5.3
KUBEADM_URL_1_5_3='https://storage.googleapis.com/kubernetes-release/release/v1.5.3/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_5_3=e99b0aa7dd7ec0b69c4accf8b1b2039c2f2749b7
HYPERKUBE_URL_1_5_3='https://storage.googleapis.com/kubernetes-release/release/v1.5.3/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_5_3=74dc5c4eb8c7077ecbad31d918d28a268fa447e7

# Version 1.6.0-beta.2
KUBEADM_URL_1_6_0_BETA_2='https://storage.googleapis.com/kubernetes-release/release/v1.6.0-beta.2/bin/linux/amd64/kubeadm'
KUBEADM_SHA1_1_6_0_BETA_2=61286285fa2d1ecbd85ca1980f556b41d188f34f
HYPERKUBE_URL_1_6_0_BETA_2='https://storage.googleapis.com/kubernetes-release/release/v1.6.0-beta.2/bin/linux/amd64/hyperkube'
HYPERKUBE_SHA1_1_6_0_BETA_2=27e3c04c248aa972a6a3f1dd742fde7fcb5e1598

# url and sha1sum of kubeadm binary -- only used for prebuilt kubeadm
KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_5_3}}
KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_5_3}}

# url and sha1sum of hyperkube binary -- only used for prebuilt hyperkube
HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_5_3}}
HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_5_3}}

# KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_6_0_BETA_2}}
# KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_6_0_BETA_2}}

# HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_6_0_BETA_2}}
# HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_6_0_BETA_2}}

# HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_4_9}}
# HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_4_9}}
