# Copyright 2018 The Kubernetes Authors.
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

FROM alpine:latest

LABEL maintainer "leblancd@cisco.com"

RUN apk --update add bind

# Move the 'named' binary to a different location. This is done in order to
# support running the bind9 container in privileged mode in a Docker-in-Docker
# (DinD) environment on a host that happens to have active AppArmor profile
# for 'named'. Without this, AppArmor defaults to using the host's AppArmor
# profile for 'named' based on the '/usr/sbin/named' path, and permissions
# errors are generated when 'named' in the container tries to access
# libraries upon which it depends.
RUN mv /usr/sbin/named /usr/bin/named

EXPOSE 53

CMD ["named", "-c", "/etc/bind/named.conf", "-g", "-u", "named"]
