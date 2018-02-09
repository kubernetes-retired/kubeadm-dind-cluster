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

if [ $(uname) = Darwin ]; then
  readlinkf(){ perl -MCwd -e 'print Cwd::abs_path shift' "$1";}
else
  readlinkf(){ readlink -f "$1"; }
fi
DIND_ROOT="$(cd $(dirname "$(readlinkf "${BASH_SOURCE}")"); pwd)"
KUBE_DIND_GCE_PROJECT="${KUBE_DIND_GCE_PROJECT:-$(gcloud config list --format 'value(core.project)' 2>/dev/null)}"
KUBE_DIND_GCE_ZONE="${KUBE_DIND_GCE_ZONE:-$(gcloud config list --format 'value(compute.zone)' 2>/dev/null)}"
# Based on instructions from k8s build/README.md
if [ -z "${KUBE_DIND_GCE_PROJECT:-}" ]; then
    echo >&2 "Please set KUBE_DIND_GCE_PROJECT or use 'gcloud config set project NAME'"
    return 1
fi

set -x
KUBE_DIND_VM="${KUBE_DIND_VM:-k8s-dind}"
export GCE_HOSTED=true
export KUBE_RSYNC_PORT=8730
export APISERVER_PORT=8899
IP_MODE="${IP_MODE:-ipv4}"
opts=("-L ${KUBE_RSYNC_PORT}:localhost:${KUBE_RSYNC_PORT}")

if [[ "${IP_MODE}" = "ipv4" ]]; then
    opts+=("-L ${APISERVER_PORT}:localhost:${APISERVER_PORT}")
else
    opts+=("-L ${APISERVER_PORT}:[::1]:${APISERVER_PORT}")
fi
docker-machine create \
               --driver=google \
               --google-project=${KUBE_DIND_GCE_PROJECT} \
               --google-machine-image=ubuntu-os-cloud/global/images/ubuntu-1604-xenial-v20170307 \
               --google-zone=${KUBE_DIND_GCE_ZONE} \
               --google-machine-type=n1-standard-8 \
               --google-disk-size=50 \
               --google-disk-type=pd-ssd \
               --engine-storage-driver=overlay2 \
               ${KUBE_DIND_VM}
eval $(docker-machine env ${KUBE_DIND_VM})
docker-machine ssh ${KUBE_DIND_VM} ${opts[*]} -N&
if [ ! -z "${DIND_IMAGE:-}" ]; then
    place=`pwd`
    cd "${DIND_ROOT}"
    build/build-local.sh
    cd "$place"
fi
time "${DIND_ROOT}"/dind-cluster.sh up
set +x
