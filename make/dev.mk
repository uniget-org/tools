BRANCHES := $(shell git ls-remote --heads 2>/dev/null | grep /renovate/ | cut -f2 | cut -d/ -f3-)

.PHONY:
branches:
	@echo $(BRANCHES)

.PHONY:
size:
	@set -o errexit; \
	export VERSION=$(VERSION); \
	bash scripts/usage.sh $(TOOLS_RAW)

.PHONY:
$(addprefix rebase--,$(BRANCHES)):rebase--%: ; $(info $(M) Rebasing branch $*...)
	@git switch $*
	@git reset --hard origin/$*
	@git rebase main
	@git push --force-with-lease
	@git switch main

.PHONY:
$(addsuffix --vscode,$(ALL_TOOLS_RAW)):%--vscode:
	@code --goto $(TOOLS_DIR)/$*/manifest.yaml

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