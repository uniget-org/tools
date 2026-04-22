SOURCE_DATE_EPOCH     ?= $(shell git log -1 --pretty=%ct)
BUILDER               ?= uniget
BINFMT_TAG            ?= qemu-v9.2.2
COSIGN_TLOG_UPLOAD    ?= false
COSIGN_REFERRERS_MODE ?= oci-1-1
ifeq ($(REGISTRY),registry.gitlab.com)
	COSIGN_REFERRERS_MODE = legacy
endif

.PHONY:
$(addsuffix --clean,$(ALL_TOOLS_RAW)):%--clean:
	@rm -f \
		$(TOOLS_DIR)/$*/manifest.json \
		$(TOOLS_DIR)/$*/Dockerfile \
		$(TOOLS_DIR)/$*/build.log \
		$(TOOLS_DIR)/$*/build-*.log \
		$(TOOLS_DIR)/$*/build-metadata.json \
		$(TOOLS_DIR)/$*/image-*.json \
		$(TOOLS_DIR)/$*/index.json \
		$(TOOLS_DIR)/$*/cosign*.pub \
		$(TOOLS_DIR)/$*/cosign*.sig \
		$(TOOLS_DIR)/$*/cosign*.sig-* \
		$(TOOLS_DIR)/$*/sbom.json \
		$(TOOLS_DIR)/$*/bov.json \
		$(TOOLS_DIR)/$*/sarif.json \
		$(TOOLS_DIR)/$*/report.csv

.PHONY:
info-test:
	@echo $(REGISTRY)
	@echo $(COSIGN_REFERRERS_MODE)

.PHONY:
$(addsuffix --vim,$(ALL_TOOLS_RAW)):%--vim:
	@vim -o2 $(TOOLS_DIR)/$*/manifest.yaml  $(TOOLS_DIR)/$*/Dockerfile.template

.PHONY:
$(addsuffix --vscode,$(ALL_TOOLS_RAW)):%--vscode:
	@code --goto $(TOOLS_DIR)/$*/manifest.yaml

.PHONY:
$(addsuffix --logs,$(ALL_TOOLS_RAW)):%--logs:
	@less $(TOOLS_DIR)/$*/build.log

.PHONY:
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
		$(TOOLS_DIR)/%/manifest.yaml \
		; $(info $(M) Creating manifest for $*...)
	@set -o errexit; \
	yq --output-format=json --indent=0 eval '{"tools": [.]}' $(TOOLS_DIR)/$*/manifest.yaml >$(TOOLS_DIR)/$*/manifest.json

$(addsuffix /manifest-minimal.json,$(ALL_TOOLS)):$(TOOLS_DIR)/%/manifest-minimal.json: \
		$(TOOLS_DIR)/%/manifest.json \
		; $(info $(M) Creating minimal manifest for $*...)
	@set -o errexit; \
	cat $(TOOLS_DIR)/$*/manifest.json \
	| jq \
		--compact-output \
		--arg reg1 "$(REGISTRY)" --arg repo1 "$(REPOSITORY_PREFIX)$*" \
		--arg reg2 "$(REGISTRY2)" --arg repo2 "$(REPOSITORY_PREFIX2)$*" \
		'.tools[0].sources = [ { "registry": $$reg1, "repository": $$repo1 }, { "registry": $$reg2, "repository": $$repo2 } ]' \
	>$(TOOLS_DIR)/$*/manifest-minimal.json

$(addsuffix /manifest-full.json,$(ALL_TOOLS)):$(TOOLS_DIR)/%/manifest-full.json: \
		$(TOOLS_DIR)/%/manifest.json \
		; $(info $(M) Creating full manifest for $*...)
	@set -o errexit; \
	if test "$$(regctl manifest get ghcr.io/uniget-org/tools/$*:main --format=raw-body | jq --exit-status '.mediaType == "application/vnd.oci.image.manifest.v1+json"')" == "true"; then \
		export SIZE="$$( regctl manifest get ghcr.io/uniget-org/tools/$*:main --format=raw-body | jq --raw-output '.layers[0].size' )"; \
	else \
		export PLATFORM="$$( regctl manifest get ghcr.io/uniget-org/tools/$*:main --format=raw-body | jq --raw-output '.manifests[] | select(.platform.os == "linux") | "\(.platform.os)/\(.platform.architecture)"' | sort | head -n 1 )"; \
		export SIZE="$$( regctl manifest get ghcr.io/uniget-org/tools/$*:main --platform=$${PLATFORM} --format=raw-body | jq --raw-output '.layers[0].size' )"; \
	fi; \
	export GIT_HISTORY="$$( git log --pretty=format:'%h %ad %s' --date=iso8601-strict $(TOOLS_DIR)/$*/manifest.yaml $(TOOLS_DIR)/$*/Dockerfile.template | tr -d '"' | jq --slurp --raw-input --compact-output '[ . | split("\n") | .[] | capture("(?<commit>[a-z0-9]+) (?<date>[-0-9T:+]+) (?<message>.+)"; null) ]' )"; \
	cat $(TOOLS_DIR)/$*/manifest.json \
	| yq eval \
		--output-format=json --indent=0 \
		'.tools[0].size = env(SIZE) | .tools[0].history = env(GIT_HISTORY) | .tools[0].date = .tools[0].history[-1].date' \
	>$(TOOLS_DIR)/$*/manifest-full.json

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
			--sbom=false \
			--attest=type=provenance,mode=max \
			--metadata-file $(TOOLS_DIR)/$@/build-metadata.json \
			--output type=registry,oci-mediatypes=true,rewrite-timestamp=true,push=$${PUSH} \
			--progress plain \
			--network=$(DOCKER_NETWORK) \
			>$(TOOLS_DIR)/$@/build.log 2>&1; then \
		cat $(TOOLS_DIR)/$@/build.log; \
		exit 1; \
	fi

.PHONY:
$(addsuffix --build-all,$(ALL_TOOLS_RAW)):%--build-all: $(TOOLS_DIR)/%/image-linux-amd64.json $(TOOLS_DIR)/%/image-linux-arm64.json

.PHONY:
$(addsuffix --build-amd64,$(ALL_TOOLS_RAW)):%--build-amd64: tools/%/image-linux-amd64.json

$(TOOLS_DIR)/%/image-linux-amd64.json: \
		$(TOOLS_DIR)/%/manifest.json \
		$(TOOLS_DIR)/%/Dockerfile \
		; $(info $(M) Building image $(REGISTRY)/$(REPOSITORY_PREFIX)$* for amd64...)
	$(eval OS := linux)
	$(eval ARCH := amd64)
	$(eval TOOL_VERSION := $(shell jq --raw-output '.tools[].version' $(TOOLS_DIR)/$*/manifest.json))
	$(eval VERSION_TAG := $(shell echo "$(TOOL_VERSION)" | tr '+' '-'))
	$(eval DEPS := $(shell jq --raw-output '.tools[] | select(.build_dependencies != null) | .build_dependencies[]' $(TOOLS_DIR)/$*/manifest.json | paste -sd,))
	$(eval TAGS := $(shell jq --raw-output '.tools[] | select(.tags != null) | .tags[]' $(TOOLS_DIR)/$*/manifest.json | paste -sd,))
	@set -o errexit; \
	if ! jq --exit-status '.tools[].platforms | any(. == "linux/$(ARCH)")' $(TOOLS_DIR)/$*/manifest.json >/dev/null; then \
		echo "WARNING: Platform linux/$(ARCH) is not requested."; \
		exit 0; \
	fi; \
	rm -f image-linux-$(ARCH).json; \
	export SOURCE_DATE_EPOCH="$(SOURCE_DATE_EPOCH)"; \
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
			--network=$(DOCKER_NETWORK) \
			>$(TOOLS_DIR)/$*/build-$(ARCH).log 2>&1; then \
		cat $(TOOLS_DIR)/$*/build-$(ARCH).log; \
		exit 1; \
	fi; \
	echo -n "  Produced digest for $(ARCH): "; \
	jq --raw-output '."containerimage.digest"' $(TOOLS_DIR)/$*/image-$(OS)-$(ARCH).json

.PHONY:
$(addsuffix --build-arm64,$(ALL_TOOLS_RAW)):%--build-arm64: $(TOOLS_DIR)/%/image-linux-arm64.json

$(TOOLS_DIR)/%/image-linux-arm64.json: \
		$(TOOLS_DIR)/%/manifest.json \
		$(TOOLS_DIR)/%/Dockerfile \
		; $(info $(M) Building image $(REGISTRY)/$(REPOSITORY_PREFIX)$*...)
	$(eval OS := linux)
	$(eval ARCH := arm64)
	$(eval TOOL_VERSION := $(shell jq --raw-output '.tools[].version' $(TOOLS_DIR)/$*/manifest.json))
	$(eval VERSION_TAG := $(shell echo "$(TOOL_VERSION)" | tr '+' '-'))
	$(eval DEPS := $(shell jq --raw-output '.tools[] | select(.build_dependencies != null) | .build_dependencies[]' $(TOOLS_DIR)/$*/manifest.json | paste -sd,))
	$(eval TAGS := $(shell jq --raw-output '.tools[] | select(.tags != null) | .tags[]' $(TOOLS_DIR)/$*/manifest.json | paste -sd,))
	@set -o errexit; \
	if ! jq --exit-status '.tools[].platforms | any(. == "linux/$(ARCH)")' $(TOOLS_DIR)/$*/manifest.json >/dev/null; then \
		echo "WARNING: Platform linux/$(ARCH) is not requested."; \
		exit 0; \
	fi; \
	rm -f image-linux-$(ARCH).json; \
	export SOURCE_DATE_EPOCH="$(SOURCE_DATE_EPOCH)"; \
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
			--network=$(DOCKER_NETWORK) \
			>$(TOOLS_DIR)/$*/build-$(ARCH).log 2>&1; then \
		cat $(TOOLS_DIR)/$*/build-$(ARCH).log; \
		exit 1; \
	fi; \
	echo -n "  Produced digest for $(ARCH): "; \
	jq --raw-output '."containerimage.digest"' $(TOOLS_DIR)/$*/image-$(OS)-$(ARCH).json

.PHONY:
$(addsuffix --index,$(ALL_TOOLS_RAW)):%--index: $(TOOLS_DIR)/%/index.json

$(TOOLS_DIR)/%/index.json: \
		$(TOOLS_DIR)/%/manifest.json \
		; $(info $(M) Creating index for $(REGISTRY)/$(REPOSITORY_PREFIX)$*...)
	$(eval OS := linux)
	$(eval TOOL_VERSION := $(shell jq --raw-output '.tools[].version' $(TOOLS_DIR)/$*/manifest.json))
	$(eval VERSION_TAG := $(shell echo "$(TOOL_VERSION)" | tr '+' '-'))
	@set -o errexit; \
	if test -f $(TOOLS_DIR)/$*/image-$(OS)-amd64.json; then \
		DIGEST_AMD64="$$( jq --raw-output '."containerimage.digest"' $(TOOLS_DIR)/$*/image-$(OS)-amd64.json )"; \
		echo "  Adding amd64 with digest $${DIGEST_AMD64}"; \
		PARAM_DIGEST_AMD64="--digest $${DIGEST_AMD64}"; \
	fi; \
	if test -f $(TOOLS_DIR)/$*/image-$(OS)-arm64.json; then \
		DIGEST_ARM64="$$( jq --raw-output '."containerimage.digest"' $(TOOLS_DIR)/$*/image-$(OS)-arm64.json )"; \
		echo "  Adding arm64 with digest $${DIGEST_ARM64}"; \
		PARAM_DIGEST_ARM64="--digest $${DIGEST_ARM64}"; \
	fi; \
	regctl index create $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(VERSION_TAG) \
		--format='{{json .Manifest}}' \
		$${PARAM_DIGEST_AMD64} \
		$${PARAM_DIGEST_ARM64} \
	| tr -d '\n' \
	>$(TOOLS_DIR)/$*/index.json; \
	DIGEST="sha256:$$( cat $(TOOLS_DIR)/$*/index.json | sha256sum | cut -d' ' -f1 )"; \
	echo "  Created index with digest $${DIGEST}"; \
	echo; \
	regctl manifest get $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(VERSION_TAG)@$${DIGEST}

.PHONY:
$(addsuffix --sign,$(ALL_TOOLS_RAW)):%--sign: \
		$(TOOLS_DIR)/%/manifest.json \
		$(TOOLS_DIR)/%/index.json \
		; $(info $(M) Signing image for $*...)
	$(eval OS := linux)
	$(eval ARCH := arm64)
	$(eval TOOL_VERSION := $(shell jq --raw-output '.tools[].version' $(TOOLS_DIR)/$*/manifest.json))
	$(eval VERSION_TAG := $(shell echo "$(TOOL_VERSION)" | tr '+' '-'))
	$(eval DIGEST := $(shell cat $(TOOLS_DIR)/$*/index.json))
	@COSIGN_EXPERIMENTAL=1 \
		cosign sign $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(VERSION_TAG) \
			--registry-referrers-mode=$(COSIGN_REFERRERS_MODE) \
			--output-certificate=$(TOOLS_DIR)/$*/cosign.pub \
			--output-signature=$(TOOLS_DIR)/$*/cosign.sig \
			--tlog-upload=$(COSIGN_TLOG_UPLOAD) \
			--recursive=true \
			--yes=true
	@regctl artifact tree $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(VERSION_TAG)

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
		$(TOOLS_DIR)/%/manifest.json \
		; $(info $(M) Promoting image for $*...)
	@TOOL_VERSION="$$(jq --raw-output '.tools[].version' tools/$*/manifest.json)"; \
	VERSION_TAG="$$( echo "$${TOOL_VERSION}" | tr '+' '-' )"; \
	regctl image copy $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$${VERSION_TAG} $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(DOCKER_TAG); \
	regctl image copy $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$${VERSION_TAG} $(REGISTRY)/$(REPOSITORY_PREFIX)$*:latest

.PHONY:
$(addsuffix --inspect,$(ALL_TOOLS_RAW)):%--inspect: \
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
		--progress plain \
		--network=$(DOCKER_NETWORK) && \
	docker container run \
		--interactive \
		--tty \
		--privileged \
		--network=$(DOCKER_NETWORK) \
		--env name=$* \
		--env version=$${TOOL_VERSION} \
		--rm \
		$(REGISTRY)/$(REPOSITORY_PREFIX)$*:$${VERSION_TAG} \
			bash --login +o errexit +o pipefail

.PHONY:
$(addsuffix --tar,$(ALL_TOOLS_RAW)):%--tar: \
		$(TOOLS_DIR)/%/manifest.json \
		$(TOOLS_DIR)/%/Dockerfile \
		; $(info $(M) Building into tar for $*...)
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
		--output type=tar,dest=$(TOOLS_DIR)/$*/image.tar,oci-mediatypes=true \
		--progress plain \
		--network=$(DOCKER_NETWORK)

.PHONY:
$(addsuffix --buildg,$(ALL_TOOLS_RAW)):%--buildg: \
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
