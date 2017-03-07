#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

DIND_ROOT=$(dirname "${BASH_SOURCE}")/..
source "$DIND_ROOT/build/funcs.sh"

dind::build-base
dind::build-image "${image_name}:local"
