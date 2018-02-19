#!/bin/bash
# Copyright 2017 Mirantis
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

if [ $(uname) = Darwin ]; then
  readlinkf(){ perl -MCwd -e 'print Cwd::abs_path shift' "$1";}
else
  readlinkf(){ readlink -f "$1"; }
fi
DIND_ROOT="$(cd $(dirname "$(readlinkf "${BASH_SOURCE}")"); pwd)"

RUN_ON_BTRFS_ANYWAY="${RUN_ON_BTRFS_ANYWAY:-}"
if [[ ! ${RUN_ON_BTRFS_ANYWAY} ]] && docker info| grep -q '^Storage Driver: btrfs'; then
  echo "ERROR: Docker is using btrfs storage driver which is unsupported by kubeadm-dind-cluster" >&2
  echo "Please refer to the documentation for more info." >&2
  echo "Set RUN_ON_BTRFS_ANYWAY to non-empty string to continue anyway." >&2
  exit 1
fi

# In case of linuxkit / moby linux, -v will not work so we can't
# mount /lib/modules and /boot. Also we'll be using localhost
# to access the apiserver
using_linuxkit=
if ! docker info|grep -s '^Operating System: .*Docker for Windows' > /dev/null 2>&1 ; then
    if docker info|grep -s '^Kernel Version: .*-moby$' >/dev/null 2>&1 ||
         docker info|grep -s '^Kernel Version: .*-linuxkit-' > /dev/null 2>&1 ; then
        using_linuxkit=1
    fi
fi

# In case of linux as the OS and docker running locally we will be using
# localhost to access the apiserver nor do we need to add routes
using_linuxdocker=
if [[ $(uname) == Linux && -z ${DOCKER_HOST:-} ]]; then
    using_linuxdocker=1
fi

EMBEDDED_CONFIG=y;DIND_IMAGE=mirantis/kubeadm-dind-cluster:v1.9

IP_MODE="${IP_MODE:-ipv4}"  # ipv4, ipv6, (future) dualstack
if [[ ! ${EMBEDDED_CONFIG:-} ]]; then
  source "${DIND_ROOT}/config.sh"
fi

CNI_PLUGIN="${CNI_PLUGIN:-bridge}"
DEFAULT_POD_NETWORK_CIDR="10.244.0.0/16"
if [[ ${CNI_PLUGIN} = "calico" || ${CNI_PLUGIN} = "calico-kdd" ]]; then
  DEFAULT_POD_NETWORK_CIDR="192.168.0.0/16"
fi
POD_NETWORK_CIDR="${POD_NETWORK_CIDR:-${DEFAULT_POD_NETWORK_CIDR}}"
ETCD_HOST="${ETCD_HOST:-127.0.0.1}"
GCE_HOSTED="${GCE_HOSTED:-false}"
if [[ ${IP_MODE} = "ipv6" ]]; then
    DIND_SUBNET="${DIND_SUBNET:-fd00:10::}"
    dind_ip_base="${DIND_SUBNET}"
    ETCD_HOST="::1"
    KUBE_RSYNC_ADDR="${KUBE_RSYNC_ADDR:-::1}"
    SERVICE_CIDR="${SERVICE_CIDR:-fd00:10:30::/110}"
    DIND_SUBNET_SIZE="${DIND_SUBNET_SIZE:-64}"
    REMOTE_DNS64_V4SERVER="${REMOTE_DNS64_V4SERVER:-8.8.8.8}"
    LOCAL_NAT64_SERVER="${DIND_SUBNET}200"
    DNS64_PREFIX="${DNS64_PREFIX:-fd00:10:64:ff9b::}"
    DNS64_PREFIX_SIZE="${DNS64_PREFIX_SIZE:-96}"
    DNS64_PREFIX_CIDR="${DNS64_PREFIX}/${DNS64_PREFIX_SIZE}"
    dns_server="${dind_ip_base}100"
    # Create a /64 prefix so that created /80 pod net is inside the /64 DinD network
    POD_NET_PREFIX="$(echo $DIND_SUBNET | sed 's/::$//')"
    num_colons="$(grep -o ":" <<< "${POD_NET_PREFIX}" | wc -l)"
    while [ $num_colons -lt 3 ]; do
	POD_NET_PREFIX+=":0"
	let num_colons+=1
    done
else
    DIND_SUBNET="${DIND_SUBNET:-10.192.0.0}"
    dind_ip_base="$(echo "${DIND_SUBNET}" | sed 's/0$//')"
    KUBE_RSYNC_ADDR="${KUBE_RSYNC_ADDR:-127.0.0.1}"
    SERVICE_CIDR="${SERVICE_CIDR:-10.96.0.0/12}"
    DIND_SUBNET_SIZE="${DIND_SUBNET_SIZE:-16}"
    dns_server="${REMOTE_DNS64_V4SERVER:-8.8.8.8}"
fi
dns_prefix="$(echo ${SERVICE_CIDR} | sed 's,/.*,,')"
if [[ ${IP_MODE} != "ipv6" ]]; then
    dns_prefix="$(echo ${dns_prefix} | sed 's/0$//')"
    DNS_SVC_IP="${dns_prefix}10"
else
    DNS_SVC_IP="${dns_prefix}a"
fi
kube_master_ip="${dind_ip_base}2"

DIND_IMAGE="${DIND_IMAGE:-}"
BUILD_KUBEADM="${BUILD_KUBEADM:-}"
BUILD_HYPERKUBE="${BUILD_HYPERKUBE:-}"
APISERVER_PORT=${APISERVER_PORT:-8080}
NUM_NODES=${NUM_NODES:-2}
EXTRA_PORTS="${EXTRA_PORTS:-}"
LOCAL_KUBECTL_VERSION=${LOCAL_KUBECTL_VERSION:-}
KUBECTL_DIR="${KUBECTL_DIR:-${HOME}/.kubeadm-dind-cluster}"
DASHBOARD_URL="${DASHBOARD_URL:-https://rawgit.com/kubernetes/dashboard/bfab10151f012d1acc5dfb1979f3172e2400aa3c/src/deploy/kubernetes-dashboard.yaml}"
SKIP_SNAPSHOT="${SKIP_SNAPSHOT:-}"
E2E_REPORT_DIR="${E2E_REPORT_DIR:-}"
DIND_NO_PARALLEL_E2E="${DIND_NO_PARALLEL_E2E:-}"

DIND_CA_CERT_URL="${DIND_CA_CERT_URL:-}"
DIND_PROPAGATE_HTTP_PROXY="${DIND_PROPAGATE_HTTP_PROXY:-}"
DIND_HTTP_PROXY="${DIND_HTTP_PROXY:-}"
DIND_HTTPS_PROXY="${DIND_HTTPS_PROXY:-}"
DIND_NO_PROXY="${DIND_NO_PROXY:-}"

if [[ ! ${LOCAL_KUBECTL_VERSION:-} && ${DIND_IMAGE:-} =~ :(v[0-9]+\.[0-9]+)$ ]]; then
  LOCAL_KUBECTL_VERSION="${BASH_REMATCH[1]}"
fi

function dind::need-source {
  if [[ ! -f cluster/kubectl.sh ]]; then
    echo "$0 must be called from the Kubernetes repository root directory" 1>&2
    exit 1
  fi
}

build_tools_dir="build"
use_k8s_source=y
if [[ ! ${BUILD_KUBEADM} && ! ${BUILD_HYPERKUBE} ]]; then
  use_k8s_source=
fi
if [[ ${use_k8s_source} ]]; then
  dind::need-source
  kubectl=cluster/kubectl.sh
  if [[ ! -f ${build_tools_dir}/common.sh ]]; then
    build_tools_dir="build-tools"
  fi
else
  if [[ ! ${LOCAL_KUBECTL_VERSION:-} ]] && ! hash kubectl 2>/dev/null; then
    echo "You need kubectl binary in your PATH to use prebuilt DIND image" 1>&2
    exit 1
  fi
  kubectl=kubectl
fi

function dind::retry {
  # based on retry function in hack/jenkins/ scripts in k8s source
  for i in {1..10}; do
    "$@" && return 0 || sleep ${i}
  done
  "$@"
}

busybox_image="busybox:1.26.2"
e2e_base_image="golang:1.7.1"
sys_volume_args=()
build_volume_args=()

function dind::set-build-volume-args {
  if [ ${#build_volume_args[@]} -gt 0 ]; then
    return 0
  fi
  build_container_name=
  if [ -n "${KUBEADM_DIND_LOCAL:-}" ]; then
    build_volume_args=(-v "$PWD:/go/src/k8s.io/kubernetes")
  else
    build_container_name="$(KUBE_ROOT=${PWD} ETCD_HOST=${ETCD_HOST} &&
                            . ${build_tools_dir}/common.sh &&
                            kube::build::verify_prereqs >&2 &&
                            echo "${KUBE_DATA_CONTAINER_NAME:-${KUBE_BUILD_DATA_CONTAINER_NAME}}")"
    build_volume_args=(--volumes-from "${build_container_name}")
  fi
}

function dind::volume-exists {
  local name="$1"
  if docker volume inspect "${name}" >& /dev/null; then
    return 0
  fi
  return 1
}

function dind::create-volume {
  local name="$1"
  docker volume create --label mirantis.kubeadm_dind_cluster --name "${name}" >/dev/null
}

# We mount /boot and /lib/modules into the container
# below to in case some of the workloads need them.
# This includes virtlet, for instance. Also this may be
# useful in future if we want DIND nodes to pass
# preflight checks.
# Unfortunately we can't do this when using Mac Docker
# (unless a remote docker daemon on Linux is used)
# NB: there's no /boot on recent Mac dockers
function dind::prepare-sys-mounts {
  if [[ ! ${using_linuxkit} ]]; then
    sys_volume_args=()
    if [[ -d /boot ]]; then
      sys_volume_args+=(-v /boot:/boot)
    fi
    if [[ -d /lib/modules ]]; then
      sys_volume_args+=(-v /lib/modules:/lib/modules)
    fi
    return 0
  fi
  if ! dind::volume-exists kubeadm-dind-sys; then
    dind::step "Saving a copy of docker host's /lib/modules"
    dind::create-volume kubeadm-dind-sys
    # Use a dirty nsenter trick to fool Docker on Mac and grab system
    # /lib/modules into sys.tar file on kubeadm-dind-sys volume.
    local nsenter="nsenter --mount=/proc/1/ns/mnt --"
    docker run \
           --rm \
           --privileged \
           -v kubeadm-dind-sys:/dest \
           --pid=host \
           "${busybox_image}" \
           /bin/sh -c \
           "if ${nsenter} test -d /lib/modules; then ${nsenter} tar -C / -c lib/modules >/dest/sys.tar; fi"
  fi
  sys_volume_args=(-v kubeadm-dind-sys:/dind-sys)
}

tmp_containers=()

function dind::cleanup {
  if [ ${#tmp_containers[@]} -gt 0 ]; then
    for name in "${tmp_containers[@]}"; do
      docker rm -vf "${name}" 2>/dev/null
    done
  fi
}

trap dind::cleanup EXIT

function dind::check-image {
  local name="$1"
  if docker inspect --format 'x' "${name}" >&/dev/null; then
    return 0
  else
    return 1
  fi
}

function dind::filter-make-output {
  # these messages make output too long and make Travis CI choke
  egrep -v --line-buffered 'I[0-9][0-9][0-9][0-9] .*(parse|conversion|defaulter|deepcopy)\.go:[0-9]+\]'
}

function dind::run-build-command {
    # this is like build/run.sh, but it doesn't rsync back the binaries,
    # only the generated files.
    local cmd=("$@")
    (
        # The following is taken from build/run.sh and build/common.sh
        # of Kubernetes source tree. It differs in
        # --filter='+ /_output/dockerized/bin/**'
        # being removed from rsync
        . ${build_tools_dir}/common.sh
        kube::build::verify_prereqs
        kube::build::build_image
        kube::build::run_build_command "$@"

        kube::log::status "Syncing out of container"

        kube::build::start_rsyncd_container

        local rsync_extra=""
        if (( ${KUBE_VERBOSE} >= 6 )); then
            rsync_extra="-iv"
        fi

        # The filter syntax for rsync is a little obscure. It filters on files and
        # directories.  If you don't go in to a directory you won't find any files
        # there.  Rules are evaluated in order.  The last two rules are a little
        # magic. '+ */' says to go in to every directory and '- /**' says to ignore
        # any file or directory that isn't already specifically allowed.
        #
        # We are looking to copy out all of the built binaries along with various
        # generated files.
        kube::build::rsync \
            --filter='- /vendor/' \
            --filter='- /_temp/' \
            --filter='+ zz_generated.*' \
            --filter='+ generated.proto' \
            --filter='+ *.pb.go' \
            --filter='+ types.go' \
            --filter='+ */' \
            --filter='- /**' \
            "rsync://k8s@${KUBE_RSYNC_ADDR}/k8s/" "${KUBE_ROOT}"

        kube::build::stop_rsyncd_container
    )
}

function dind::make-for-linux {
  local copy="$1"
  shift
  dind::step "Building binaries:" "$*"
  if [ -n "${KUBEADM_DIND_LOCAL:-}" ]; then
    dind::step "+ make WHAT=\"$*\""
    make WHAT="$*" 2>&1 | dind::filter-make-output
  elif [ "${copy}" = "y" ]; then
    dind::step "+ ${build_tools_dir}/run.sh make WHAT=\"$*\""
    "${build_tools_dir}/run.sh" make WHAT="$*" 2>&1 | dind::filter-make-output
  else
    dind::step "+ [using the build container] make WHAT=\"$*\""
    dind::run-build-command make WHAT="$*" 2>&1 | dind::filter-make-output
  fi
}

function dind::check-binary {
  local filename="$1"
  local dockerized="_output/dockerized/bin/linux/amd64/${filename}"
  local plain="_output/local/bin/linux/amd64/${filename}"
  dind::set-build-volume-args
  # FIXME: don't hardcode amd64 arch
  if [ -n "${KUBEADM_DIND_LOCAL:-${force_local:-}}" ]; then
    if [ -f "${dockerized}" -o -f "${plain}" ]; then
      return 0
    fi
  elif docker run --rm "${build_volume_args[@]}" \
              "${busybox_image}" \
              test -f "/go/src/k8s.io/kubernetes/${dockerized}" >&/dev/null; then
    return 0
  fi
  return 1
}

function dind::ensure-downloaded-kubectl {
  local kubectl_url
  local kubectl_sha1
  local kubectl_sha1_linux
  local kubectl_sha1_darwin
  local kubectl_link
  local kubectl_os
  local full_kubectl_version

  case "${LOCAL_KUBECTL_VERSION}" in
    v1.7)
      full_kubectl_version=v1.7.12
      kubectl_sha1_linux=385229d4189e4f7978de42f237d6c443c0534edd
      kubectl_sha1_darwin=af0e0853b965aa42774bba5dfbaeecb416fc6089
      ;;
    v1.8)
      full_kubectl_version=v1.8.6
      kubectl_sha1_linux=59f138a5144224cb0c8ed440d3a0a0e91ef01271
      kubectl_sha1_darwin=f1f7f1c776704e87b2db0d81229fc529ada70d41
      ;;
    v1.9)
      full_kubectl_version=v1.9.1
      kubectl_sha1_linux=4f997a2fd85473e684906dcd58f9b03c000d6c0b
      kubectl_sha1_darwin=3a3f3616b930e06fd503558870caa7d82e4cb1ef
      ;;
    "")
      return 0
      ;;
    *)
      echo "Invalid kubectl version" >&2
      exit 1
  esac

  export PATH="${KUBECTL_DIR}:$PATH"

  if [ $(uname) = Darwin ]; then
    kubectl_sha1="${kubectl_sha1_darwin}"
    kubectl_os=darwin
  else
    kubectl_sha1="${kubectl_sha1_linux}"
    kubectl_os=linux
  fi
  local link_target="kubectl-${full_kubectl_version}"
  local link_name="${KUBECTL_DIR}"/kubectl
  if [[ -h "${link_name}" && "$(readlink "${link_name}")" = "${link_target}" ]]; then
    return 0
  fi

  local path="${KUBECTL_DIR}/${link_target}"
  if [[ ! -f "${path}" ]]; then
    mkdir -p "${KUBECTL_DIR}"
    curl -sSLo "${path}" "https://storage.googleapis.com/kubernetes-release/release/${full_kubectl_version}/bin/${kubectl_os}/amd64/kubectl"
    echo "${kubectl_sha1} ${path}" | sha1sum -c
    chmod +x "${path}"
  fi

  ln -fs "${link_target}" "${KUBECTL_DIR}/kubectl"
}

function dind::ensure-kubectl {
  if [[ ! ${use_k8s_source} ]]; then
    # already checked on startup
    dind::ensure-downloaded-kubectl
    return 0
  fi
  if [ $(uname) = Darwin ]; then
    if [ ! -f _output/local/bin/darwin/amd64/kubectl ]; then
      dind::step "Building kubectl"
      dind::step "+ make WHAT=cmd/kubectl"
      make WHAT=cmd/kubectl 2>&1 | dind::filter-make-output
    fi
  elif ! force_local=y dind::check-binary kubectl; then
    dind::make-for-linux y cmd/kubectl
  fi
}

function dind::ensure-binaries {
  local -a to_build=()
  for name in "$@"; do
    if ! dind::check-binary "$(basename "${name}")"; then
      to_build+=("${name}")
    fi
  done
  if [ "${#to_build[@]}" -gt 0 ]; then
    dind::make-for-linux n "${to_build[@]}"
  fi
  return 0
}

function dind::ensure-network {
  if ! docker network inspect kubeadm-dind-net >&/dev/null; then
    local v6settings=""
    if [[ ${IP_MODE} = "ipv6" ]]; then
      # Need second network for NAT64
      v6settings="--subnet=172.18.0.0/16 --ipv6"
    fi
    docker network create ${v6settings} --subnet="${DIND_SUBNET}/${DIND_SUBNET_SIZE}" --gateway="${dind_ip_base}1" kubeadm-dind-net >/dev/null
  fi
}

function dind::ensure-volume {
  local reuse_volume=
  if [[ $1 = -r ]]; then
    reuse_volume=1
    shift
  fi
  local name="$1"
  if dind::volume-exists "${name}"; then
    if [[ ! {reuse_volume} ]]; then
      docker volume rm "${name}" >/dev/null
    fi
  elif [[ ${reuse_volume} ]]; then
    echo "*** Failed to locate volume: ${name}" 1>&2
    return 1
  fi
  dind::create-volume "${name}"
}

function dind::ensure-dns {
    if [[ ${IP_MODE} = "ipv6" ]]; then
        if ! docker inspect bind9 >&/dev/null; then
	    local bind9_path=/tmp/bind9
	    rm -rf ${bind9_path}
	    mkdir -p ${bind9_path}/conf ${bind9_path}/cache
	    cat >${bind9_path}/conf/named.conf <<BIND9_EOF
options {
    directory "/var/bind";
    allow-query { any; };
    forwarders {
        ${DNS64_PREFIX}${REMOTE_DNS64_V4SERVER};
    };
    auth-nxdomain no;    # conform to RFC1035
    listen-on-v6 { any; };
    dns64 ${DNS64_PREFIX_CIDR} {
        exclude { any; };
    };
};
BIND9_EOF
	    if [[ "${GCE_HOSTED}" = true ]]; then
		# TODO: Have bind9 create config file, and pass in variables via Env vars.
		docker-machine scp ${bind9_path}/conf/named.conf k8s-dind:bind9-named.conf
		docker-machine ssh k8s-dind sudo rm -rf ${bind-path}
		docker-machine ssh k8s-dind sudo mkdir -p ${bind9_path}/conf ${bind9_path}/cache
		docker-machine ssh k8s-dind sudo cp /home/docker-user/bind9-named.conf ${bind9_path}/conf/named.conf
	    fi
	    docker run -d --name bind9 --hostname bind9 --net kubeadm-dind-net --label mirantis.kubeadm_dind_cluster \
		   --sysctl net.ipv6.conf.all.disable_ipv6=0 --sysctl net.ipv6.conf.all.forwarding=1 \
		   --privileged=true --ip6 $dns_server --dns $dns_server \
		   -v ${bind9_path}/conf/named.conf:/etc/bind/named.conf \
		   resystit/bind9:latest >/dev/null
	    ipv4_addr="$(docker exec bind9 ip addr list eth0 | grep "inet" | awk '$1 == "inet" {print $2}')"
	    docker exec bind9 ip addr del ${ipv4_addr} dev eth0
	    docker exec bind9 ip -6 route add ${DNS64_PREFIX_CIDR} via ${LOCAL_NAT64_SERVER}
        fi
    fi
}

function dind::ensure-nat {
    if [[  ${IP_MODE} = "ipv6" ]]; then
        if ! docker ps | grep tayga >&/dev/null; then
            docker run -d --name tayga --hostname tayga --net kubeadm-dind-net --label mirantis.kubeadm_dind_cluster \
		   --sysctl net.ipv6.conf.all.disable_ipv6=0 --sysctl net.ipv6.conf.all.forwarding=1 \
		   --privileged=true --ip 172.18.0.200 --ip6 ${LOCAL_NAT64_SERVER} --dns ${REMOTE_DNS64_V4SERVER} --dns ${dns_server} \
		   -e TAYGA_CONF_PREFIX=${DNS64_PREFIX_CIDR} -e TAYGA_CONF_IPV4_ADDR=172.18.0.200 \
		   danehans/tayga:latest >/dev/null
	    # Need to check/create, as "clean" may remove route
	    local route="$(ip route | egrep "^172.18.0.128/25")"
	    if [[ -z "${route}" ]]; then
		if [[ "${GCE_HOSTED}" = true ]]; then
		    docker-machine ssh k8s-dind sudo ip route add 172.18.0.128/25 via 172.18.0.200
    elif [[ -z ${using_linuxdocker} ]]; then
        :
		else
		    docker run --net=host --rm --privileged busybox ip route add 172.18.0.128/25 via 172.18.0.200
		fi
	    fi
	fi
    fi
}

function dind::run {
  local reuse_volume=
  if [[ $1 = -r ]]; then
    reuse_volume="-r"
    shift
  fi
  local container_name="${1:-}"
  local ip="${2:-}"
  local netshift="${3:-}"
  local portforward="${4:-}"
  if [[ $# -gt 4 ]]; then
    shift 4
  else
    shift $#
  fi
  local ip_arg="--ip"
  if [[ ${IP_MODE} = "ipv6" ]]; then
      ip_arg="--ip6"
  fi
  local -a opts=("${ip_arg}" "${ip}" "$@")
  local -a args=("systemd.setenv=CNI_PLUGIN=${CNI_PLUGIN}")
  args+=("systemd.setenv=IP_MODE=${IP_MODE}")
  if [[ ${IP_MODE} = "ipv6" ]]; then
      opts+=(--sysctl net.ipv6.conf.all.disable_ipv6=0)
      opts+=(--sysctl net.ipv6.conf.all.forwarding=1)
      opts+=(--dns ${dns_server})
      args+=("systemd.setenv=DNS64_PREFIX_CIDR=${DNS64_PREFIX_CIDR}")
      args+=("systemd.setenv=LOCAL_NAT64_SERVER=${LOCAL_NAT64_SERVER}")
      args+=("systemd.setenv=POD_NET_PREFIX=${POD_NET_PREFIX}")
  fi
  args+=("systemd.setenv=DNS_SVC_IP=${DNS_SVC_IP}")
  if [[ ! "${container_name}" ]]; then
    echo >&2 "Must specify container name"
    exit 1
  fi

  # remove any previously created containers with the same name
  docker rm -vf "${container_name}" >&/dev/null || true

  if [[ "$portforward" ]]; then
    IFS=';' read -ra array <<< "$portforward"
    for element in "${array[@]}"; do
      opts+=(-p "$element")
    done
  fi

  if [[ ${CNI_PLUGIN} = bridge && ${netshift} ]]; then
    args+=("systemd.setenv=CNI_BRIDGE_NETWORK_OFFSET=0.0.${netshift}.0")
  fi

  opts+=(${sys_volume_args[@]+"${sys_volume_args[@]}"})

  dind::step "Starting DIND container:" "${container_name}"

  if [[ ! ${using_linuxkit} ]]; then
    opts+=(-v /boot:/boot -v /lib/modules:/lib/modules)
  fi

  volume_name="kubeadm-dind-${container_name}"
  dind::ensure-network
  dind::ensure-volume ${reuse_volume} "${volume_name}"
  dind::ensure-nat
  dind::ensure-dns

  # TODO: create named volume for binaries and mount it to /k8s
  # in case of the source build

  # Start the new container.
  docker run \
	 -e IP_MODE="${IP_MODE}" \
         -d --privileged \
         --net kubeadm-dind-net \
         --name "${container_name}" \
         --hostname "${container_name}" \
         -l mirantis.kubeadm_dind_cluster \
         -v ${volume_name}:/dind \
         ${opts[@]+"${opts[@]}"} \
         "${DIND_IMAGE}" \
         ${args[@]+"${args[@]}"}
}

function dind::kubeadm {
  local container_id="$1"
  shift
  dind::step "Running kubeadm:" "$*"
  status=0
  # See image/bare/wrapkubeadm.
  # Capturing output is necessary to grab flags for 'kubeadm join'
  if ! docker exec "${container_id}" wrapkubeadm "$@" 2>&1 | tee /dev/fd/2; then
    echo "*** kubeadm failed" >&2
    return 1
  fi
  return ${status}
}

# function dind::bare {
#   local container_name="${1:-}"
#   if [[ ! "${container_name}" ]]; then
#     echo >&2 "Must specify container name"
#     exit 1
#   fi
#   shift
#   run_opts=(${@+"$@"})
#   dind::run "${container_name}"
# }

function dind::configure-kubectl {
  dind::step "Setting cluster config"
  local host="${dind_ip_base}2"
  if [[ ${IP_MODE} = "ipv6" ]]; then
      host="[${host}]"
  fi
  if [[ "${GCE_HOSTED}" = true || ${DOCKER_HOST:-} =~ ^tcp: || ${using_linuxkit} || -n ${using_linuxdocker} ]]; then
    if [[ "${IP_MODE}" = "ipv4" ]]; then
      host="localhost"
    else
      host="[::1]"
    fi
  fi
  "${kubectl}" config set-cluster dind --server="http://${host}:${APISERVER_PORT}" --insecure-skip-tls-verify=true
  "${kubectl}" config set-context dind --cluster=dind
  "${kubectl}" config use-context dind
}

force_make_binaries=
function dind::set-master-opts {
  master_opts=()
  if [[ ${BUILD_KUBEADM} || ${BUILD_HYPERKUBE} ]]; then
    # share binaries pulled from the build container between nodes
    dind::ensure-volume "dind-k8s-binaries"
    dind::set-build-volume-args
    master_opts+=("${build_volume_args[@]}" -v dind-k8s-binaries:/k8s)
    local -a bins
    if [[ ${BUILD_KUBEADM} ]]; then
      master_opts+=(-e KUBEADM_SOURCE=build://)
      bins+=(cmd/kubeadm)
    fi
    if [[ ${BUILD_HYPERKUBE} ]]; then
      master_opts+=(-e HYPERKUBE_SOURCE=build://)
      bins+=(cmd/hyperkube)
    fi
    if [[ ${force_make_binaries} ]]; then
      dind::make-for-linux n "${bins[@]}"
    else
      dind::ensure-binaries "${bins[@]}"
    fi
  fi
  if [[ ${MASTER_EXTRA_OPTS:-} ]]; then
    master_opts+=( ${MASTER_EXTRA_OPTS} )
  fi
}

cached_k8s_version=
function dind::k8s-version {
  if [[ ! ${cached_k8s_version} ]]; then
    cached_k8s_version="$("${kubectl}" version --short | grep 'Server Version' | sed 's/.*: v\|\.[0-9]*$//g')"
  fi
  echo "${cached_k8s_version}"
}

function dind::ensure-dashboard-clusterrolebinding {
  # 'create' may cause etcd timeout, yet create the clusterrolebinding.
  # So use 'apply' to actually create it
  "${kubectl}" create clusterrolebinding add-on-cluster-admin \
               --clusterrole=cluster-admin \
               --serviceaccount=kube-system:default \
               -o json --dry-run |
    "${kubectl}" apply -f -
}

function dind::deploy-dashboard {
  dind::step "Deploying k8s dashboard"
  dind::retry "${kubectl}" apply -f "${DASHBOARD_URL}"
  # https://kubernetes-io-vnext-staging.netlify.com/docs/admin/authorization/rbac/#service-account-permissions
  # Thanks @liggitt for the hint
  dind::retry dind::ensure-dashboard-clusterrolebinding
}

function dind::at-least-kubeadm-1-8 {
  # kubeadm 1.6 and below doesn't support 'version -o short' and will
  # thus produce an empty string
  local ver="$(docker exec kube-master kubeadm version -o short 2>/dev/null|sed 's/^\(v[0-9]*\.[0-9]*\).*$/\1/')"
  if [[ ! ${ver} || ${ver} = v1.7 ]]; then
    return 1
  fi
}

function dind::init {
  local -a opts
  dind::set-master-opts
  local local_host="127.0.0.1"
  if [[ ${IP_MODE} = "ipv6" ]]; then
      local_host="[::1]"
  fi
  local container_id=$(dind::run kube-master "${kube_master_ip}" 1 ${local_host}:${APISERVER_PORT}:8080 ${master_opts[@]+"${master_opts[@]}"})
  # FIXME: I tried using custom tokens with 'kubeadm ex token create' but join failed with:
  # 'failed to parse response as JWS object [square/go-jose: compact JWS format must have three parts]'
  # So we just pick the line from 'kubeadm init' output
  if dind::at-least-kubeadm-1-8; then
    # Using a template file in the image to build a kubeadm.conf file and to customize
    # it based on CNI plugin, IP mode, and environment settings. User can add additional
    # customizations to template and then rebuild the image used (build/build-local.sh).
    local pod_subnet_disable="# "
    # TODO: May want to specify each of the plugins that require --pod-network-cidr
    if [[ ${CNI_PLUGIN} != "bridge" ]]; then
      pod_subnet_disable=""
    fi
    local bind_address="0.0.0.0"
    if [[ ${IP_MODE} = "ipv6" ]]; then
      bind_address="::"
    fi
    dind::proxy kube-master

    # HACK: Indicating mode, so that wrapkubeadm will not set a cluster CIDR for kube-proxy
    # in IPv6 (only) mode.
    if [[ ${IP_MODE} = "ipv6" ]]; then
      docker exec --privileged -i kube-master touch /v6-mode
    fi

    docker exec --privileged -i kube-master bash <<EOF
sed -e "s|{{ADV_ADDR}}|${kube_master_ip}|" \
    -e "s|{{POD_SUBNET_DISABLE}}|${pod_subnet_disable}|" \
    -e "s|{{POD_NETWORK_CIDR}}|${POD_NETWORK_CIDR}|" \
    -e "s|{{SVC_SUBNET}}|${SERVICE_CIDR}|" \
    -e "s|{{BIND_ADDR}}|${bind_address}|" \
    /etc/kubeadm.conf.tmpl > /etc/kubeadm.conf
EOF
    init_args=(--config /etc/kubeadm.conf)
  else
    init_args=(--pod-network-cidr="${POD_NETWORK_CIDR}")
  fi
  # required when building from source
  if [[ ${BUILD_KUBEADM} || ${BUILD_HYPERKUBE} ]]; then
    docker exec kube-master mount --make-shared /k8s
  fi
  kubeadm_join_flags="$(dind::kubeadm "${container_id}" init "${init_args[@]}" --skip-preflight-checks "$@" | grep '^ *kubeadm join' | sed 's/^ *kubeadm join //')"
  dind::configure-kubectl
}

function dind::create-node-container {
  local reuse_volume=
  if [[ $1 = -r ]]; then
    reuse_volume="-r"
    shift
  fi
  # if there's just one node currently, it's master, thus we need to use
  # kube-node-1 hostname, if there are two nodes, we should pick
  # kube-node-2 and so on
  local next_node_index=${1:-$(docker ps -q --filter=label=mirantis.kubeadm_dind_cluster | wc -l | sed 's/^ *//g')}
  local node_ip="${dind_ip_base}$((next_node_index + 2))"
  local -a opts
  if [[ ${BUILD_KUBEADM} || ${BUILD_HYPERKUBE} ]]; then
    opts+=(-v dind-k8s-binaries:/k8s)
    if [[ ${BUILD_KUBEADM} ]]; then
      opts+=(-e KUBEADM_SOURCE=build://)
    fi
    if [[ ${BUILD_HYPERKUBE} ]]; then
      opts+=(-e HYPERKUBE_SOURCE=build://)
    fi
  fi
  dind::run ${reuse_volume} kube-node-${next_node_index} ${node_ip} $((next_node_index + 1)) "${EXTRA_PORTS}" ${opts[@]+"${opts[@]}"}
}

function dind::join {
  local container_id="$1"
  shift
  dind::proxy "${container_id}"
  dind::kubeadm "${container_id}" join --skip-preflight-checks "$@" >/dev/null
}

function dind::escape-e2e-name {
    sed 's/[]\$*.^()[]/\\&/g; s/\s\+/\\s+/g' <<< "$1" | tr -d '\n'
}

function dind::accelerate-kube-dns {
  dind::step "Patching kube-dns deployment to make it start faster"
  # Could do this on the host, too, but we don't want to require jq here
  # TODO: do this in wrapkubeadm
  docker exec kube-master /bin/bash -c \
         "kubectl get deployment kube-dns -n kube-system -o json | jq '.spec.template.spec.containers[0].readinessProbe.initialDelaySeconds = 3|.spec.template.spec.containers[0].readinessProbe.periodSeconds = 3' | kubectl apply --force -f -"
}

function dind::component-ready {
  local label="$1"
  local out
  if ! out="$("${kubectl}" get pod -l "${label}" -n kube-system \
                           -o jsonpath='{ .items[*].status.conditions[?(@.type == "Ready")].status }' 2>/dev/null)"; then
    return 1
  fi
  if ! grep -v False <<<"${out}" | grep -q True; then
    return 1
  fi
  return 0
}

function dind::kill-failed-pods {
  local pods
  # workaround for https://github.com/kubernetes/kubernetes/issues/36482
  if ! pods="$(kubectl get pod -n kube-system -o jsonpath='{ .items[?(@.status.phase == "Failed")].metadata.name }' 2>/dev/null)"; then
    return
  fi
  for name in ${pods}; do
    kubectl delete pod --now -n kube-system "${name}" >&/dev/null || true
  done
}

function dind::wait-for-ready {
  dind::step "Waiting for kube-proxy and the nodes"
  local proxy_ready
  local nodes_ready
  local n=3
  local ntries=200
  while true; do
    dind::kill-failed-pods
    if "${kubectl}" get nodes 2>/dev/null | grep -q NotReady; then
      nodes_ready=
    else
      nodes_ready=y
    fi
    if dind::component-ready k8s-app=kube-proxy; then
      proxy_ready=y
    else
      proxy_ready=
    fi
    if [[ ${nodes_ready} && ${proxy_ready} ]]; then
      if ((--n == 0)); then
        echo "[done]" >&2
        break
      fi
    else
      n=3
    fi
    if ((--ntries == 0)); then
      echo "Error waiting for kube-proxy and the nodes" >&2
      exit 1
    fi
    echo -n "." >&2
    sleep 1
  done

  dind::step "Bringing up kube-dns and kubernetes-dashboard"
  # on Travis 'scale' sometimes fails with 'error: Scaling the resource failed with: etcdserver: request timed out; Current resource version 442' here
  dind::retry "${kubectl}" scale deployment --replicas=1 -n kube-system kube-dns
  dind::retry "${kubectl}" scale deployment --replicas=1 -n kube-system kubernetes-dashboard

  ntries=200
  while ! dind::component-ready k8s-app=kube-dns || ! dind::component-ready app=kubernetes-dashboard; do
    if ((--ntries == 0)); then
      echo "Error bringing up kube-dns and kubernetes-dashboard" >&2
      exit 1
    fi
    echo -n "." >&2
    dind::kill-failed-pods
    sleep 1
  done
  echo "[done]" >&2

  dind::retry "${kubectl}" get nodes >&2
  local_host="localhost"
  if [[ ${IP_MODE} = "ipv6" ]]; then
      local_host="[::1]"
  fi
  dind::step "Access dashboard at:" "http://${local_host}:${APISERVER_PORT}/api/v1/namespaces/kube-system/services/kubernetes-dashboard:/proxy"
}

function dind::up {
  dind::down
  dind::init
  # pre-create node containers sequentially so they get predictable IPs
  local -a node_containers
  for ((n=1; n <= NUM_NODES; n++)); do
    dind::step "Starting node container:" ${n}
    if ! container_id="$(dind::create-node-container ${n})"; then
      echo >&2 "*** Failed to start node container ${n}"
      exit 1
    else
      node_containers+=(${container_id})
      dind::step "Node container started:" ${n}
    fi
  done
  dind::fix-mounts
  status=0
  local -a pids
  for ((n=1; n <= NUM_NODES; n++)); do
    (
      dind::step "Joining node:" ${n}
      container_id="${node_containers[n-1]}"
      if ! dind::join ${container_id} ${kubeadm_join_flags}; then
        echo >&2 "*** Failed to start node container ${n}"
        exit 1
      else
        dind::step "Node joined:" ${n}
      fi
    )&
    pids[${n}]=$!
  done
  if ((NUM_NODES > 0)); then
    for pid in ${pids[*]}; do
      wait ${pid}
    done
  else
    # FIXME: this may fail depending on k8s/kubeadm version
    # FIXME: check for taint & retry if it's there
    "${kubectl}" taint nodes kube-master node-role.kubernetes.io/master- || true
  fi
  case "${CNI_PLUGIN}" in
    bridge)
      ;;
    flannel)
      # without --validate=false this will fail on older k8s versions
      dind::retry "${kubectl}" apply --validate=false -f "https://github.com/coreos/flannel/blob/master/Documentation/kube-flannel.yml?raw=true"
      ;;
    calico)
      dind::retry "${kubectl}" apply -f https://docs.projectcalico.org/v2.6/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml
      ;;
    calico-kdd)
      dind::retry "${kubectl}" apply -f https://docs.projectcalico.org/v2.6/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
      dind::retry "${kubectl}" apply -f https://docs.projectcalico.org/v2.6/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
      ;;
    weave)
      dind::retry "${kubectl}" apply -f "https://github.com/weaveworks/weave/blob/master/prog/weave-kube/weave-daemonset-k8s-1.6.yaml?raw=true"
      ;;
    *)
      echo "Unsupported CNI plugin '${CNI_PLUGIN}'" >&2
      ;;
  esac
  dind::deploy-dashboard
  dind::accelerate-kube-dns
  if [[ ${CNI_PLUGIN} != bridge || ${SKIP_SNAPSHOT} ]]; then
    # This is especially important in case of Calico -
    # the cluster will not recover after snapshotting
    # (at least not after restarting from the snapshot)
    # if Calico installation is interrupted
    dind::wait-for-ready
  fi
}

function dind::fix-mounts {
  for ((n=0; n <= NUM_NODES; n++)); do
    local node_name=kube-master
    if ((n > 0)); then
      node_name="kube-node-${n}"
    fi
    docker exec "${node_name}" mount --make-shared /lib/modules/
    docker exec "${node_name}" mount --make-shared /run
    # required when building from source
    if [[ ${BUILD_KUBEADM} || ${BUILD_HYPERKUBE} ]]; then
      docker exec "${node_name}" mount --make-shared /k8s
    fi
  done
}

function dind::snapshot_container {
  local container_name="$1"
  docker exec -i ${container_name} /usr/local/bin/snapshot prepare
  docker diff ${container_name} | docker exec -i ${container_name} /usr/local/bin/snapshot save
}

function dind::snapshot {
  dind::step "Taking snapshot of the cluster"
  dind::snapshot_container kube-master
  for ((n=1; n <= NUM_NODES; n++)); do
    dind::snapshot_container "kube-node-${n}"
  done
  dind::wait-for-ready
}

restore_cmd=restore
function dind::restore_container {
  local container_id="$1"
  docker exec ${container_id} /usr/local/bin/snapshot "${restore_cmd}"
}

function dind::restore {
  dind::down
  dind::step "Restoring master container"
  dind::set-master-opts
  for ((n=0; n <= NUM_NODES; n++)); do
    (
      if [[ n -eq 0 ]]; then
        dind::step "Restoring master container"
        local local_host="127.0.0.1"
        if [[ ${IP_MODE} = "ipv6" ]]; then
          local_host="[::1]"
        fi
        dind::restore_container "$(dind::run -r kube-master "${kube_master_ip}" 1 ${local_host}:${APISERVER_PORT}:8080 ${master_opts[@]+"${master_opts[@]}"})"
        dind::step "Master container restored"
      else
        dind::step "Restoring node container:" ${n}
        if ! container_id="$(dind::create-node-container -r ${n})"; then
          echo >&2 "*** Failed to start node container ${n}"
          exit 1
        else
          dind::restore_container "${container_id}"
          dind::step "Node container restored:" ${n}
        fi
      fi
    )&
    pids[${n}]=$!
  done
  for pid in ${pids[*]}; do
    wait ${pid}
  done
  dind::fix-mounts
  # Recheck kubectl config. It's possible that the cluster was started
  # on this docker from different host
  dind::configure-kubectl
  dind::wait-for-ready
}

function dind::down {
  docker ps -a -q --filter=label=mirantis.kubeadm_dind_cluster | while read container_id; do
    dind::step "Removing container:" "${container_id}"
    docker rm -fv "${container_id}"
  done
}

function dind::remove-volumes {
  # docker 1.13+: docker volume ls -q -f label=mirantis.kubeadm_dind_cluster
  docker volume ls -q | (grep '^kubeadm-dind' || true) | while read volume_id; do
    dind::step "Removing volume:" "${volume_id}"
    docker volume rm "${volume_id}"
  done
}

function dind::check-for-snapshot {
  if ! dind::volume-exists "kubeadm-dind-kube-master"; then
    return 1
  fi
  for ((n=1; n <= NUM_NODES; n++)); do
    if ! dind::volume-exists "kubeadm-dind-kube-node-${n}"; then
      return 1
    fi
  done
}

function dind::do-run-e2e {
  local parallel="${1:-}"
  local focus="${2:-}"
  local skip="${3:-}"
  local host="${kube_master_ip}"
  if [[ "${IP_MODE}" = "ipv6" ]]; then
    host="[$host]"
  fi
  if [[ "${GCE_HOSTED}" = true || ${DOCKER_HOST:-} =~ ^tcp: || -n ${using_linuxdocker} ]]; then
    if [[ "${IP_MODE}" = "ipv4" ]]; then
      host="localhost"
    else
      host="[::1]"
    fi
  fi
  dind::need-source
  local test_args="--host=http://${host}:${APISERVER_PORT}"
  local -a e2e_volume_opts=()
  local term=
  if [[ ${focus} ]]; then
    test_args="--ginkgo.focus=${focus} ${test_args}"
  fi
  if [[ ${skip} ]]; then
    test_args="--ginkgo.skip=${skip} ${test_args}"
  fi
  if [[ ${E2E_REPORT_DIR} ]]; then
    test_args="--report-dir=/report ${test_args}"
    e2e_volume_opts=(-v "${E2E_REPORT_DIR}:/report")
  fi
  dind::make-for-linux n cmd/kubectl test/e2e/e2e.test vendor/github.com/onsi/ginkgo/ginkgo
  dind::step "Running e2e tests with args:" "${test_args}"
  dind::set-build-volume-args
  if [ -t 1 ] ; then
    term="-it"
    test_args="--ginkgo.noColor --num-nodes=2 ${test_args}"
  fi
  docker run \
         --rm ${term} \
         --net=host \
         "${build_volume_args[@]}" \
         -e KUBERNETES_PROVIDER=dind \
         -e KUBE_MASTER_IP=http://${host}:${APISERVER_PORT} \
         -e KUBE_MASTER=local \
         -e KUBERNETES_CONFORMANCE_TEST=y \
         -e GINKGO_PARALLEL=${parallel} \
         ${e2e_volume_opts[@]+"${e2e_volume_opts[@]}"} \
         -w /go/src/k8s.io/kubernetes \
         "${e2e_base_image}" \
         bash -c "cluster/kubectl.sh config set-cluster dind --server='http://${host}:${APISERVER_PORT}' --insecure-skip-tls-verify=true &&
         cluster/kubectl.sh config set-context dind --cluster=dind &&
         cluster/kubectl.sh config use-context dind &&
         go run hack/e2e.go -- --v --test --check-version-skew=false --test_args='${test_args}'"
}

function dind::clean {
  dind::down
  # dind::remove-images
  dind::remove-volumes
  if docker network inspect kubeadm-dind-net >&/dev/null; then
    docker network rm kubeadm-dind-net
  fi
}

function dind::run-e2e {
  local focus="${1:-}"
  local skip="${2:-[Serial]}"
  skip="$(dind::escape-e2e-name "${skip}")"
  if [[ "$focus" ]]; then
    focus="$(dind::escape-e2e-name "${focus}")"
  else
    focus="\[Conformance\]"
  fi
  local parallel=y
  if [[ ${DIND_NO_PARALLEL_E2E} ]]; then
    parallel=
  fi
  dind::do-run-e2e "${parallel}" "${focus}" "${skip}"
}

function dind::run-e2e-serial {
  local focus="${1:-}"
  local skip="${2:-}"
  skip="$(dind::escape-e2e-name "${skip}")"
  dind::need-source
  if [[ "$focus" ]]; then
    focus="$(dind::escape-e2e-name "${focus}")"
  else
    focus="\[Serial\].*\[Conformance\]"
  fi
  dind::do-run-e2e n "${focus}" "${skip}"
  # TBD: specify filter
}

function dind::step {
  local OPTS=""
  if [ "$1" = "-n" ]; then
    shift
    OPTS+="-n"
  fi
  GREEN="$1"
  shift
  if [ -t 2 ] ; then
    echo -e ${OPTS} "\x1B[97m* \x1B[92m${GREEN}\x1B[39m $*" 1>&2
  else
    echo ${OPTS} "* ${GREEN} $*" 1>&2
  fi
}

function dind::dump {
  set +e
  echo "*** Dumping cluster state ***"
  for node in $(docker ps --format '{{.Names}}' --filter label=mirantis.kubeadm_dind_cluster); do
    for service in kubelet.service dindnet.service criproxy.service dockershim.service; do
      if docker exec "${node}" systemctl is-enabled "${service}" >&/dev/null; then
        echo "@@@ service-${node}-${service}.log @@@"
        docker exec "${node}" systemctl status "${service}"
        docker exec "${node}" journalctl -xe -n all -u "${service}"
      fi
    done
    echo "@@@ psaux-${node}.txt @@@"
    docker exec "${node}" ps auxww
    echo "@@@ dockerps-a-${node}.txt @@@"
    docker exec "${node}" docker ps -a
    echo "@@@ ip-a-${node}.txt @@@"
    docker exec "${node}" ip a
    echo "@@@ ip-r-${node}.txt @@@"
    docker exec "${node}" ip r
  done
  docker exec kube-master kubectl get pods --all-namespaces \
          -o go-template='{{range $x := .items}}{{range $x.spec.containers}}{{$x.spec.nodeName}}{{" "}}{{$x.metadata.namespace}}{{" "}}{{$x.metadata.name}}{{" "}}{{.name}}{{"\n"}}{{end}}{{end}}' |
    while read node ns pod container; do
      echo "@@@ pod-${node}-${ns}-${pod}--${container}.log @@@"
      docker exec kube-master kubectl logs -n "${ns}" -c "${container}" "${pod}"
    done
  echo "@@@ kubectl-all.txt @@@"
  docker exec kube-master kubectl get all --all-namespaces -o wide
  echo "@@@ describe-all.txt @@@"
  docker exec kube-master kubectl describe all --all-namespaces
  echo "@@@ nodes.txt @@@"
  docker exec kube-master kubectl get nodes -o wide
}

function dind::dump64 {
  echo "%%% start-base64 %%%"
  dind::dump | docker exec -i kube-master /bin/sh -c "lzma | base64 -w 100"
  echo "%%% end-base64 %%%"
}

function dind::split-dump {
  mkdir -p cluster-dump
  cd cluster-dump
  awk '!/^@@@ .* @@@$/{print >out}; /^@@@ .* @@@$/{out=$2}' out=/dev/null
  ls -l
}

function dind::split-dump64 {
  decode_opt=-d
  if base64 --help | grep -q '^ *-D'; then
    # Mac OS X
    decode_opt=-D
  fi
  sed -n '/^%%% start-base64 %%%$/,/^%%% end-base64 %%%$/p' |
    sed '1d;$d' |
    base64 "${decode_opt}" |
    lzma -dc |
    dind::split-dump
}

function dind::proxy {
  local container_id="$1"
  if [[ ${DIND_CA_CERT_URL} ]] ; then
    dind::step "+ Adding certificate on ${container_id}"
    docker exec ${container_id} /bin/sh -c "cd /usr/local/share/ca-certificates; curl -sSO ${DIND_CA_CERT_URL}"
    docker exec ${container_id} update-ca-certificates
  fi
  if [[ "${DIND_PROPAGATE_HTTP_PROXY}" || "${DIND_HTTP_PROXY}" || "${DIND_HTTPS_PROXY}" || "${DIND_NO_PROXY}" ]]; then
    dind::step "+ Setting *_PROXY for docker service on ${container_id}"
    local proxy_env="[Service]"$'\n'"Environment="
    if [[ "${DIND_PROPAGATE_HTTP_PROXY}" ]]; then
      # take *_PROXY values from container environment
      proxy_env+=$(docker exec ${container_id} env | grep -i _proxy | awk '{ print "\""$0"\""}' | xargs -d'\n')
    else
      if [[ "${DIND_HTTP_PROXY}" ]] ;  then proxy_env+="\"HTTP_PROXY=${DIND_HTTP_PROXY}\" "; fi
      if [[ "${DIND_HTTPS_PROXY}" ]] ; then proxy_env+="\"HTTPS_PROXY=${DIND_HTTPS_PROXY}\" "; fi
      if [[ "${DIND_NO_PROXY}" ]] ;    then proxy_env+="\"NO_PROXY=${DIND_NO_PROXY}\" "; fi
    fi
    docker exec -i ${container_id} /bin/sh -c "cat > /etc/systemd/system/docker.service.d/30-proxy.conf" <<< "${proxy_env}"
    docker exec ${container_id} systemctl daemon-reload
    docker exec ${container_id} systemctl restart docker
  fi
}

case "${1:-}" in
  up)
    if [[ ! ( ${DIND_IMAGE} =~ local ) ]]; then
      dind::step "Making sure DIND image is up to date"
      docker pull "${DIND_IMAGE}" >&2
    fi

    dind::prepare-sys-mounts
    dind::ensure-kubectl
    if [[ ${SKIP_SNAPSHOT} ]]; then
      force_make_binaries=y dind::up
    elif ! dind::check-for-snapshot; then
      force_make_binaries=y dind::up
      dind::snapshot
    else
      dind::restore
    fi
    ;;
  reup)
    dind::prepare-sys-mounts
    dind::ensure-kubectl
    if [[ ${SKIP_SNAPSHOT} ]]; then
      force_make_binaries=y dind::up
    elif ! dind::check-for-snapshot; then
      force_make_binaries=y dind::up
      dind::snapshot
    else
      force_make_binaries=y
      restore_cmd=update_and_restore
      dind::restore
    fi
    ;;
  down)
    dind::down
    ;;
  init)
    shift
    dind::prepare-sys-mounts
    dind::ensure-kubectl
    dind::init "$@"
    ;;
  join)
    shift
    dind::prepare-sys-mounts
    dind::ensure-kubectl
    dind::join "$(dind::create-node-container)" "$@"
    ;;
  # bare)
  #   shift
  #   dind::bare "$@"
  #   ;;
  snapshot)
    shift
    dind::snapshot
    ;;
  restore)
    shift
    dind::restore
    ;;
  clean)
    dind::clean
    ;;
  e2e)
    shift
    dind::run-e2e "$@"
    ;;
  e2e-serial)
    shift
    dind::run-e2e-serial "$@"
    ;;
  dump)
    dind::dump
    ;;
  dump64)
    dind::dump64
    ;;
  split-dump)
    dind::split-dump
    ;;
  split-dump64)
    dind::split-dump64
    ;;
  *)
    echo "usage:" >&2
    echo "  $0 up" >&2
    echo "  $0 reup" >&2
    echo "  $0 down" >&2
    echo "  $0 init kubeadm-args..." >&2
    echo "  $0 join kubeadm-args..." >&2
    # echo "  $0 bare container_name [docker_options...]"
    echo "  $0 clean"
    echo "  $0 e2e [test-name-substring]" >&2
    echo "  $0 e2e-serial [test-name-substring]" >&2
    echo "  $0 dump" >&2
    echo "  $0 dump64" >&2
    echo "  $0 split-dump" >&2
    echo "  $0 split-dump64" >&2
    exit 1
    ;;
esac
