SOURCE_DATE_EPOCH ?= $(shell git log -1 --pretty=%ct)

$(addsuffix --vim,$(ALL_TOOLS_RAW)):%--vim: ## ???
	@vim -o2 $(TOOLS_DIR)/$*/manifest.yaml  $(TOOLS_DIR)/$*/Dockerfile.template

$(addsuffix --vscode,$(ALL_TOOLS_RAW)):%--vscode: ## ???
	@code --add $(TOOLS_DIR)/$*

$(addsuffix --logs,$(ALL_TOOLS_RAW)):%--logs: ## ???
	@less $(TOOLS_DIR)/$*/build.log

$(addsuffix --pr,$(ALL_TOOLS_RAW)):%--pr: ## ???
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
		; $(info $(M) Creating manifest for $*...) ## Generate from tools/*/manifest.yaml
	@set -o errexit; \
	yq --output-format json eval '{"tools":[.]}' $(TOOLS_DIR)/$*/manifest.yaml >$(TOOLS_DIR)/$*/manifest.json

$(addsuffix /Dockerfile,$(ALL_TOOLS)):$(TOOLS_DIR)/%/Dockerfile: \
		$(TOOLS_DIR)/%/Dockerfile.template \
		$(TOOLS_DIR)/Dockerfile.tail \
		; $(info $(M) Creating $@...) ## Generate from tools/*/Dockerfile.template
	@set -o errexit; \
	cat $@.template >$@; \
	echo >>$@; \
	echo >>$@; \
	if test -f $(TOOLS_DIR)/$*/post_install.sh; then echo 'COPY post_install.sh $${prefix}$${uniget_post_install}/$${name}.sh' >>$@; fi; \
	cat $(TOOLS_DIR)/Dockerfile.tail >>$@

.PHONY:
install: \
		push \
		sign \
		attest ## ???

.PHONY:
builders: \
		; $(info $(M) Starting builders...) ## ???
	@\
	docker buildx ls | grep -q "^uniget " \
	|| docker buildx create --name uniget \
		--platform $(subst $(eval ) ,$(shell echo ","),$(addprefix linux/,$(SUPPORTED_ALT_ARCH))) \
		--bootstrap; \
	docker container run --privileged --rm tonistiigi/binfmt --install all >/dev/null

.PHONY:
clean-builders: \
		; $(info $(M) Pruning builders...) ## ???
	@\
	docker buildx ls | grep -q "^uniget " \
	&& docker builder prune --builder uniget --all --force

.PHONY:
$(ALL_TOOLS_RAW):%: \
		$(HELPER)/var/lib/uniget/manifests/gojq.json \
		$(TOOLS_DIR)/%/manifest.json \
		$(TOOLS_DIR)/%/Dockerfile \
		builders \
		; $(info $(M) Building image $(REGISTRY)/$(REPOSITORY_PREFIX)$*...) ## Build container image for all tools
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
			--builder uniget \
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

$(addsuffix --deep,$(ALL_TOOLS_RAW)):%--deep: \
		info \
		metadata.json ## Build container image including all dependencies
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
		metadata.json--push ## Push all container images

.PHONY:
$(addsuffix --push,$(ALL_TOOLS_RAW)): \
		PUSH=true
$(addsuffix --push,$(ALL_TOOLS_RAW)):%--push: \
		% \
		; $(info $(M) Pushing image for $*...) ## Push container image for specific tool

.PHONY:
promote: \
		$(addsuffix --promote,$(TOOLS_RAW)) ## Promote all container images

.PHONY:
$(addsuffix --promote,$(ALL_TOOLS_RAW)):%--promote: \
		$(HELPER)/var/lib/uniget/manifests/regclient.json \
		$(TOOLS_DIR)/%/manifest.json \
		; $(info $(M) Promoting image for $*...) ## ???
	@TOOL_VERSION="$$(jq --raw-output '.tools[].version' tools/$*/manifest.json)"; \
	VERSION_TAG="$$( echo "$${TOOL_VERSION}" | tr '+' '-' )"; \
	regctl image copy $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$${VERSION_TAG} $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(DOCKER_TAG); \
	regctl image copy $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$${VERSION_TAG} $(REGISTRY)/$(REPOSITORY_PREFIX)$*:latest

.PHONY:
$(addsuffix --inspect,$(ALL_TOOLS_RAW)):%--inspect: \
		$(HELPER)/var/lib/uniget/manifests/regclient.json \
		; $(info $(M) Inspecting image for $*...) ## ???
	@TOOL_VERSION="$$(jq --raw-output '.tools[].version' tools/$*/manifest.json)"; \
	VERSION_TAG="$$( echo "$${TOOL_VERSION}" | tr '+' '-' )"; \
	regctl manifest get $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$${VERSION_TAG}

.PHONY:
$(addsuffix --install,$(ALL_TOOLS_RAW)):%--install: \
		%--push \
		%--sign \
		%--attest ## ???

.PHONY:
$(addsuffix --debug,$(ALL_TOOLS_RAW)):%--debug: \
		$(HELPER)/var/lib/uniget/manifests/gojq.json \
		$(TOOLS_DIR)/%/manifest.json \
		$(TOOLS_DIR)/%/Dockerfile \
		; $(info $(M) Debugging image for $*...) ## Build container image specific tool and enter shell
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
		--builder uniget \
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
			bash --login

.PHONY:
$(addsuffix --buildg,$(ALL_TOOLS_RAW)):%--buildg: \
		$(HELPER)/var/lib/uniget/manifests/gojq.json \
		$(HELPER)/var/lib/uniget/manifests/buildg.json \
		$(TOOLS_DIR)/%/manifest.json \
		$(TOOLS_DIR)/%/Dockerfile \
		; $(info $(M) Interactively debugging image for $*...) ## ???
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
		; $(info $(M) Testing $*...) ## Test a tool in a container image
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
		debug-$(ALT_ARCH) ## Enter shell in base image
