# Copyright 2018
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

# Usage:
# To build and push an image to DockerHub, run:
#      make IMG=<image-name-colon-version>
# To just do a local build without a push to DockerHub:
#      make image IMG=<image-name-colon-version>

IMG = "diverdane/bind9:latest"

all: image

image:
	docker build --no-cache -t "$(IMG)" .

push: image
	gcloud docker -- push "$(IMG)"

.PHONY: all image push
