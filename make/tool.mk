SOURCE_DATE_EPOCH ?= $(shell git log -1 --pretty=%ct)
BUILDER           ?= uniget
BINFMT_TAG        ?= qemu-v8.1.5-45

$(addsuffix --vim,$(ALL_TOOLS_RAW)):%--vim:
	@vim -o2 $(TOOLS_DIR)/$*/manifest.yaml  $(TOOLS_DIR)/$*/Dockerfile.template

$(addsuffix --vscode,$(ALL_TOOLS_RAW)):%--vscode:
	@\
	code --goto $(TOOLS_DIR)/$*/manifest.yaml; \
	code --goto $(TOOLS_DIR)/$*/Dockerfile.template

$(addsuffix --logs,$(ALL_TOOLS_RAW)):%--logs:
	@less $(TOOLS_DIR)/$*/build.log

$(addsuffix --pr,$(ALL_TOOLS_RAW)):%--pr:
	@set -o errexit; \
	REPO="$$(jq --raw-output '.tools[].renovate.package' $(TOOLS_DIR)/$*/manifest.json)"; \
	REPO_SLUG="$${REPO////-}"; \
	REPO_BRANCH="$$(git for-each-ref --format='%(refname:short)' refs/heads/ | grep "$${REPO_SLUG}")"; \
	if test -z "$${REPO_BRANCH}"; then \
		echo "No branch for $${REPO_SLUG}."; \
		exit 1; \
	fi; \
	if test "$$(echo -n "${REPO_BRANCH}" | wc -l)" -gt 1; then \
		echo "Multiple branches for $${REPO_SLUG}."; \
		exit 1; \
	fi; \
	git checkout "$${REPO_BRANCH}"

$(addsuffix /manifest.json,$(ALL_TOOLS)):$(TOOLS_DIR)/%/manifest.json: \
		$(HELPER)/var/lib/uniget/manifests/gojq.json \
		$(HELPER)/var/lib/uniget/manifests/yq.json \
		$(TOOLS_DIR)/%/manifest.yaml \
		; $(info $(M) Creating manifest for $*...)
	@set -o errexit; \
	yq --output-format json eval '{"tools":[.]}' $(TOOLS_DIR)/$*/manifest.yaml \
	| jq \
		--arg reg1 "$(REGISTRY)" --arg repo1 "$(REPOSITORY_PREFIX)$*" \
		--arg reg2 "$(REGISTRY2)" --arg repo2 "$(REPOSITORY_PREFIX2)$*" \
		'.tools[0].sources = [ { "registry": $$reg1, "repository": $$repo1 }, { "registry": $$reg2, "repository": $$repo2 } ]' \
	>$(TOOLS_DIR)/$*/manifest.json

$(addsuffix /Dockerfile,$(ALL_TOOLS)):$(TOOLS_DIR)/%/Dockerfile: \
		$(TOOLS_DIR)/%/Dockerfile.template \
		; $(info $(M) Creating $@...)
	@set -o errexit; \
	cat $@.template >$@; \
	echo >>$@; \
	echo >>$@; \
	echo -e "FROM scratch\nCOPY --from=prepare /uniget_bootstrap /\n" >>$@; \
	if test -f ca.pem; then \
		sed -i -E '/^FROM .+ AS prepare/a RUN cd /usr/local/share/ca-certificates && csplit -s -z -f individual- -b "%02d.crt" custom.pem "/-----BEGIN CERTIFICATE-----/" "{*}" && update-ca-certificates' $@; \
		sed -i '/ AS prepare/a EOF' $@; \
		sed -i '/ AS prepare/r ca.pem' $@; \
		sed -i '/ AS prepare/a COPY <<EOF /usr/local/share/ca-certificates/custom.pem' $@; \
	fi

.PHONY:
install: \
		push \
		sign \
		attest

.PHONY:
builders: \
		; $(info $(M) Starting builders...)
	@\
	docker buildx ls | grep -q "^uniget " \
	|| docker buildx create --name uniget \
		--platform $(subst $(eval ) ,$(shell echo ","),$(addprefix linux/,$(SUPPORTED_ALT_ARCH))) \
		--bootstrap; \
	echo "  Configured builders:"; \
	docker buildx ls; \
	echo "  Registering qemu..."; \
	docker container run --privileged --rm "tonistiigi/binfmt:$(BINFMT_TAG)" --install all >/dev/null

.PHONY:
clean-builders: \
		; $(info $(M) Pruning builders...)
	@\
	docker buildx ls | grep -q "^uniget " \
	&& docker builder prune --builder $(BUILDER) --all --force

.PHONY:
$(ALL_TOOLS_RAW):%: \
		$(HELPER)/var/lib/uniget/manifests/gojq.json \
		$(TOOLS_DIR)/%/manifest.json \
		$(TOOLS_DIR)/%/Dockerfile \
		builders \
		; $(info $(M) Building image $(REGISTRY)/$(REPOSITORY_PREFIX)$*...)
	@set -o errexit; \
	PUSH=$(or $(PUSH), false); \
	TOOL_VERSION="$$(jq --raw-output '.tools[].version' tools/$*/manifest.json)"; \
	VERSION_TAG="$$( echo "$${TOOL_VERSION}" | tr '+' '-' )"; \
	DEPS="$$(jq --raw-output '.tools[] | select(.build_dependencies != null) | .build_dependencies[]' tools/$*/manifest.json | paste -sd,)"; \
	TAGS="$$(jq --raw-output '.tools[] | select(.tags != null) | .tags[]' tools/$*/manifest.json | paste -sd,)"; \
	ARCHS="$$(jq --raw-output '.tools[] | select(.platforms != null) | .platforms[]' tools/$*/manifest.json | paste -sd,)"; \
	test -n "$${ARCHS}" || ARCHS="linux/$(ALT_ARCH)"; \
	export SOURCE_DATE_EPOCH="$(SOURCE_DATE_EPOCH)"; \
	echo "Name:         $*"; \
	echo "Version:      $${TOOL_VERSION}"; \
	echo "Version tag:  $${VERSION_TAG}"; \
	echo "Build deps:   $${DEPS}"; \
	echo "Platforms:    $${ARCHS}"; \
	echo "Push:         $${PUSH}"; \
	if ! docker buildx build $(TOOLS_DIR)/$@ \
			--builder $(BUILDER) \
			--build-arg branch=$(DOCKER_TAG) \
			--build-arg ref=$(DOCKER_TAG) \
			--build-arg name=$* \
			--build-arg version=$${TOOL_VERSION} \
			--build-arg deps=$${DEPS} \
			--build-arg tags=$${TAGS} \
			--platform $${ARCHS} \
			--cache-from $(REGISTRY)/$(REPOSITORY_PREFIX)$*:latest \
			--tag $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$${VERSION_TAG} \
			--provenance=false \
			--metadata-file $(TOOLS_DIR)/$@/build-metadata.json \
			--output type=registry,oci-mediatypes=true,push=$${PUSH} \
			--progress plain \
			>$(TOOLS_DIR)/$@/build.log 2>&1; then \
		cat $(TOOLS_DIR)/$@/build.log; \
		exit 1; \
	fi

.PHONY:
$(addsuffix --amd64,$(ALL_TOOLS_RAW)):%--amd64: tools/%/image-linux-amd64.json

tools/%/image-linux-amd64.json: \
		$(HELPER)/var/lib/uniget/manifests/gojq.json \
		$(TOOLS_DIR)/%/manifest.json \
		$(TOOLS_DIR)/%/Dockerfile \
		builders \
		; $(info $(M) Building image $(REGISTRY)/$(REPOSITORY_PREFIX)$* for amd64...)
	$(eval OS := linux)
	$(eval ARCH := amd64)
	$(eval TOOL_VERSION := $(shell jq --raw-output '.tools[].version' tools/$*/manifest.json))
	$(eval VERSION_TAG := $(shell echo "$(TOOL_VERSION)" | tr '+' '-'))
	$(eval DEPS := $(shell jq --raw-output '.tools[] | select(.build_dependencies != null) | .build_dependencies[]' tools/$*/manifest.json | paste -sd,))
	$(eval TAGS := $(shell jq --raw-output '.tools[] | select(.tags != null) | .tags[]' tools/$*/manifest.json | paste -sd,))
	@set -o errexit; \
	if ! jq --exit-status '.tools[].platforms | any(. == "linux/$(ARCH)")' tools/$*/manifest.json >/dev/null; then \
		echo "WARNING: Platform linux/$(ARCH) is not requested."; \
		exit 0; \
	fi; \
	rm -f image-linux-$(ARCH).json; \
    if ! docker buildx build $(TOOLS_DIR)/$* \
			--builder=$(BUILDER) \
			--build-arg=branch=$(DOCKER_TAG) \
			--build-arg=ref=$(DOCKER_TAG) \
			--build-arg=name=$* \
			--build-arg=version=$(TOOL_VERSION) \
			--build-arg=deps=$${DEPS} \
			--build-arg=tags=$${TAGS} \
			--sbom=false \
			--provenance=false \
			--label=org.opencontainers.image.source="https://github.com/uniget-org/tools" \
			--label=org.opencontainers.image.title="$*" \
			--label=org.opencontainers.image.description="$* packaged for installation" \
			--label=org.opencontainers.image.version="$(TOOL_VERSION)" \
			--label=dev.uniget.name="$*" \
			--label=dev.uniget.version="$(TOOL_VERSION)" \
			--label=dev.uniget.needs="$(DEPS)" \
			--label=dev.uniget.tags="$(TAGS)" \
			--platform=$(OS)/$(ARCH) \
			--cache-from=type=registry,ref=$(REGISTRY)/$(REPOSITORY_PREFIX)$*:latest \
			--cache-from=type=registry,ref=$(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(VERSION_TAG) \
			--cache-from=type=registry,ref=$(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(VERSION_TAG)-$(OS)-$(ARCH) \
			--cache-to=type=inline,mode=max \
			--metadata-file=$(TOOLS_DIR)/$*/image-$(OS)-$(ARCH).json \
			--tag=$(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(VERSION_TAG)-$(OS)-$(ARCH) \
			--output=type=registry,oci-mediatypes=true \
			--progress plain \
			>$(TOOLS_DIR)/$*/build-$(ARCH).log 2>&1; then \
		cat $(TOOLS_DIR)/$*/build-$(ARCH).log; \
		exit 1; \
	fi; \
	echo -n "  Produced digest for $(ARCH): "; \
	jq --raw-output '."containerimage.digest"' $(TOOLS_DIR)/$*/image-$(OS)-$(ARCH).json

.PHONY:
$(addsuffix --arm64,$(ALL_TOOLS_RAW)):%--arm64: tools/%/image-linux-arm64.json

tools/%/image-linux-arm64.json: \
		$(HELPER)/var/lib/uniget/manifests/gojq.json \
		$(TOOLS_DIR)/%/manifest.json \
		$(TOOLS_DIR)/%/Dockerfile \
		builders \
		; $(info $(M) Building image $(REGISTRY)/$(REPOSITORY_PREFIX)$*...)
	$(eval OS := linux)
	$(eval ARCH := arm64)
	$(eval TOOL_VERSION := $(shell jq --raw-output '.tools[].version' tools/$*/manifest.json))
	$(eval VERSION_TAG := $(shell echo "$(TOOL_VERSION)" | tr '+' '-'))
	$(eval DEPS := $(shell jq --raw-output '.tools[] | select(.build_dependencies != null) | .build_dependencies[]' tools/$*/manifest.json | paste -sd,))
	$(eval TAGS := $(shell jq --raw-output '.tools[] | select(.tags != null) | .tags[]' tools/$*/manifest.json | paste -sd,))
	@set -o errexit; \
	if ! jq --exit-status '.tools[].platforms | any(. == "linux/$(ARCH)")' tools/$*/manifest.json >/dev/null; then \
		echo "WARNING: Platform linux/$(ARCH) is not requested."; \
		exit 0; \
	fi; \
	rm -f image-linux-$(ARCH).json; \
    if ! docker buildx build $(TOOLS_DIR)/$* \
			--builder=$(BUILDER) \
			--build-arg=branch=$(DOCKER_TAG) \
			--build-arg=ref=$(DOCKER_TAG) \
			--build-arg=name=$* \
			--build-arg=version=$(TOOL_VERSION) \
			--build-arg=deps=$${DEPS} \
			--build-arg=tags=$${TAGS} \
			--sbom=false \
			--provenance=false \
			--label=org.opencontainers.image.source="https://github.com/uniget-org/tools" \
			--label=org.opencontainers.image.title="$*" \
			--label=org.opencontainers.image.description="$* packaged for installation" \
			--label=org.opencontainers.image.version="$(TOOL_VERSION)" \
			--label=dev.uniget.name="$*" \
			--label=dev.uniget.version="$(TOOL_VERSION)" \
			--label=dev.uniget.needs="$(DEPS)" \
			--label=dev.uniget.tags="$(TAGS)" \
			--platform=$(OS)/$(ARCH) \
			--cache-from=type=registry,ref=$(REGISTRY)/$(REPOSITORY_PREFIX)$*:latest \
			--cache-from=type=registry,ref=$(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(VERSION_TAG) \
			--cache-from=type=registry,ref=$(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(VERSION_TAG)-$(OS)-$(ARCH) \
			--cache-to=type=inline,mode=max \
			--metadata-file=$(TOOLS_DIR)/$*/image-$(OS)-$(ARCH).json \
			--tag=$(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(VERSION_TAG)-$(OS)-$(ARCH) \
			--output=type=registry,oci-mediatypes=true \
			--progress plain \
			>$(TOOLS_DIR)/$*/build-$(ARCH).log 2>&1; then \
		cat $(TOOLS_DIR)/$*/build-$(ARCH).log; \
		exit 1; \
	fi; \
	echo -n "  Produced digest for $(ARCH): "; \
	jq --raw-output '."containerimage.digest"' $(TOOLS_DIR)/$*/image-$(OS)-$(ARCH).json

.PHONY:
$(addsuffix --index,$(ALL_TOOLS_RAW)):%--index: \
		$(HELPER)/var/lib/uniget/manifests/gojq.json \
		$(TOOLS_DIR)/%/manifest.json \
		; $(info $(M) Creating index for $(REGISTRY)/$(REPOSITORY_PREFIX)$*...)
	$(eval OS := linux)
	$(eval TOOL_VERSION := $(shell jq --raw-output '.tools[].version' tools/$*/manifest.json))
	@set -o errexit; \
	if test -f $(TOOLS_DIR)/$*/image-$(OS)-amd64.json; then \
		DIGEST_AMD64="$$( jq --raw-output '."containerimage.digest"' $(TOOLS_DIR)/$*/image-$(OS)-amd64.json )"; \
		echo "  Adding amd64 with digest $${DIGEST_AMD64}"; \
		PARAM_REF_AMD64="--ref $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(TOOL_VERSION)-$(OS)-amd64@$${DIGEST_AMD64}"; \
	fi; \
	if test -f $(TOOLS_DIR)/$*/image-$(OS)-arm64.json; then \
		DIGEST_ARM64="$$( jq --raw-output '."containerimage.digest"' $(TOOLS_DIR)/$*/image-$(OS)-arm64.json )"; \
		echo "  Adding arm64 with digest $${DIGEST_ARM64}"; \
		PARAM_REF_ARM64="--ref $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(TOOL_VERSION)-$(OS)-arm64@$${DIGEST_ARM64}"; \
	fi; \
	regctl index create $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(TOOL_VERSION) \
		--by-digest \
		$${PARAM_REF_AMD64} \
		$${PARAM_REF_ARM64} \
	>$(TOOLS_DIR)/$*/index.txt; \
	echo "  Created index with digest $$( cat $(TOOLS_DIR)/$*/index.txt )"; \
	echo; \
	regctl manifest get $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(TOOL_VERSION)@$$( cat $(TOOLS_DIR)/$*/index.txt )

$(addsuffix --deep,$(ALL_TOOLS_RAW)):%--deep: \
		info \
		metadata.json
	@set -o errexit; \
	DEPS="$$(jq --raw-output '.tools[] | select(.build_dependencies != null) | .build_dependencies[]' tools/$*/manifest.json | paste -sd' ')"; \
	if test -z "$${DEPS}"; then \
		echo "No deps for $*"; \
	else \
		for DEP in $${DEPS}; do \
			echo "Making deps: $${DEPS}."; \
			make $${DEP}--deep; \
		done; \
	fi; \
	make $*

.PHONY:
push: \
		PUSH=true
push: \
		$(TOOLS_RAW) \
		metadata.json--push

.PHONY:
$(addsuffix --push,$(ALL_TOOLS_RAW)): \
		PUSH=true
$(addsuffix --push,$(ALL_TOOLS_RAW)):%--push: \
		% \
		; $(info $(M) Pushing image for $*...)

.PHONY:
promote: \
		$(addsuffix --promote,$(TOOLS_RAW))

.PHONY:
$(addsuffix --promote,$(ALL_TOOLS_RAW)):%--promote: \
		$(HELPER)/var/lib/uniget/manifests/regclient.json \
		$(TOOLS_DIR)/%/manifest.json \
		; $(info $(M) Promoting image for $*...)
	@TOOL_VERSION="$$(jq --raw-output '.tools[].version' tools/$*/manifest.json)"; \
	VERSION_TAG="$$( echo "$${TOOL_VERSION}" | tr '+' '-' )"; \
	regctl image copy $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$${VERSION_TAG} $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(DOCKER_TAG); \
	regctl image copy $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$${VERSION_TAG} $(REGISTRY)/$(REPOSITORY_PREFIX)$*:latest

.PHONY:
$(addsuffix --inspect,$(ALL_TOOLS_RAW)):%--inspect: \
		$(HELPER)/var/lib/uniget/manifests/regclient.json \
		; $(info $(M) Inspecting image for $*...)
	@TOOL_VERSION="$$(jq --raw-output '.tools[].version' tools/$*/manifest.json)"; \
	VERSION_TAG="$$( echo "$${TOOL_VERSION}" | tr '+' '-' )"; \
	regctl manifest get $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$${VERSION_TAG}

.PHONY:
$(addsuffix --install,$(ALL_TOOLS_RAW)):%--install: \
		%--push \
		%--sign \
		%--attest

.PHONY:
$(addsuffix --debug,$(ALL_TOOLS_RAW)):%--debug: \
		$(HELPER)/var/lib/uniget/manifests/gojq.json \
		$(TOOLS_DIR)/%/manifest.json \
		$(TOOLS_DIR)/%/Dockerfile \
		; $(info $(M) Debugging image for $*...)
	@set -o errexit; \
	TOOL_VERSION="$$(jq --raw-output '.tools[].version' $(TOOLS_DIR)/$*/manifest.json)"; \
	VERSION_TAG="$$( echo "$${TOOL_VERSION}" | tr '+' '-' )"; \
	DEPS="$$(jq --raw-output '.tools[] | select(.build_dependencies != null) |.build_dependencies[]' tools/$*/manifest.json | paste -sd,)"; \
	TAGS="$$(jq --raw-output '.tools[] | select(.tags != null) |.tags[]' tools/$*/manifest.json | paste -sd,)"; \
	test -n "$${ARCHS}" || ARCHS="linux/$(ALT_ARCH)"; \
	export SOURCE_DATE_EPOCH="$(SOURCE_DATE_EPOCH)"; \
	echo "Name:         $*"; \
	echo "Version:      $${TOOL_VERSION}"; \
	echo "Version tag:  $${VERSION_TAG}"; \
	echo "Build deps:   $${DEPS}"; \
	export BUILDX_EXPERIMENTAL=1; \
	docker buildx debug --on=error --invoke=/bin/bash build $(TOOLS_DIR)/$* \
		--builder default \
		--build-arg branch=$(DOCKER_TAG) \
		--build-arg ref=$(DOCKER_TAG) \
		--build-arg name=$* \
		--build-arg version=$${TOOL_VERSION} \
		--build-arg deps=$${DEPS} \
		--build-arg tags=$${TAGS} \
		--cache-from $(REGISTRY)/$(REPOSITORY_PREFIX)$*:latest \
		--platform linux/amd64 \
		--tag $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$${VERSION_TAG} \
		--target prepare \
		--output type=docker,oci-mediatypes=true \
		--progress plain && \
	docker container run \
		--interactive \
		--tty \
		--privileged \
		--env name=$* \
		--env version=$${TOOL_VERSION} \
		--rm \
		$(REGISTRY)/$(REPOSITORY_PREFIX)$*:$${VERSION_TAG} \
			bash --login +o errexit +o pipefail

.PHONY:
$(addsuffix --buildg,$(ALL_TOOLS_RAW)):%--buildg: \
		$(HELPER)/var/lib/uniget/manifests/gojq.json \
		$(HELPER)/var/lib/uniget/manifests/buildg.json \
		$(TOOLS_DIR)/%/manifest.json \
		$(TOOLS_DIR)/%/Dockerfile \
		; $(info $(M) Interactively debugging image for $*...)
	@set -o errexit; \
	TOOL_VERSION="$$(jq --raw-output '.tools[].version' $(TOOLS_DIR)/$*/manifest.json)"; \
	DEPS="$$(jq --raw-output '.tools[] | select(.build_dependencies != null) |.build_dependencies[]' tools/$*/manifest.json | paste -sd,)"; \
	TAGS="$$(jq --raw-output '.tools[] | select(.tags != null) |.tags[]' tools/$*/manifest.json | paste -sd,)"; \
	test -n "$${ARCHS}" || ARCHS="linux/$(ALT_ARCH)"; \
	echo "Name:         $*"; \
	echo "Version:      $${TOOL_VERSION}"; \
	echo "Build deps:   $${DEPS}"; \
	buildg debug $(TOOLS_DIR)/$* \
		--build-arg branch=$(DOCKER_TAG) \
		--build-arg ref=$(DOCKER_TAG) \
		--build-arg name=$* \
		--build-arg version=$${TOOL_VERSION} \
		--build-arg deps=$${DEPS} \
		--build-arg tags=$${TAGS} \
		--cache-from $(REGISTRY)/$(REPOSITORY_PREFIX)$*:latest

.PHONY:
$(addsuffix --test,$(ALL_TOOLS_RAW)):%--test: \
		% \
		; $(info $(M) Testing $*...)
	@set -o errexit; \
	if ! test -f "$(TOOLS_DIR)/$*/test.sh"; then \
		echo "Nothing to test."; \
		exit; \
	fi; \
	uniget generate $* \
	| docker build --tag test-$* -; \
	bash $(TOOLS_DIR)/$*/test.sh test-$*

.PHONY:
debug: \
		debug-$(ALT_ARCH)
