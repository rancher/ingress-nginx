# Copyright 2025 The Kubernetes Authors. All rights reserved.
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

NAME ?=

PLATFORMS ?= linux/amd64,linux/arm64
# External Rancher tooling uses REPO, so prioritize that over REGISTRY if set
REPO ?=
ifneq ($(strip $(REPO)),)
REGISTRY := $(REPO)
else ifeq ($(strip $(REGISTRY)),)
REGISTRY := rancher
endif
IMAGE ?= $(REGISTRY)/$(NAME)
TAG ?= $(shell cat $(NAME)/TAG)

DIR = $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BASE_IMAGE ?= $(shell cat $(DIR)/../NGINX_BASE)
GOLANG_VERSION ?= $(shell cat $(DIR)/../GOLANG_VERSION)
EXTRAARGS ?= $(shell cat $(NAME)/EXTRAARGS)

.PHONY: build
build:
	docker buildx build \
		${IID_FILE_FLAG} \
		--platform $(PLATFORMS) \
		--label org.opencontainers.image.description="Ingress NGINX $(NAME)" \
		--label org.opencontainers.image.source="https://github.com/kubernetes/ingress-nginx" \
		--label org.opencontainers.image.licenses="Apache-2.0" \
		--build-arg BASE_IMAGE=$(BASE_IMAGE) \
		--build-arg GOLANG_VERSION=$(GOLANG_VERSION) \
		--progress=plain \
		$(EXTRAARGS) \
		$(NAME)/rootfs \
		--tag $(IMAGE):$(TAG) \
		$(OUTPUT)

.PHONY: push
push: OUTPUT = --push
push: build

.PHONY: load
load: OUTPUT = --load
load: build

.PHONY: test
test:
	cd $(NAME)/rootfs && go test ./...

.PHONY: test-e2e
test-e2e:
	cd $(NAME) && hack/e2e.sh

.PHONY: clean
clean:
	docker buildx rm $(BUILDER) || :
