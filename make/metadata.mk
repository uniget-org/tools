metadata.json: \
		$(addsuffix /manifest-minimal.json,$(ALL_TOOLS)) \
		; $(info $(M) Creating $@...)
	@jq --slurp --compact-output --arg revision "$(GIT_COMMIT_SHA)" '{"revision": $$revision, "tools": map(.tools[])}' $(addsuffix /manifest-minimal.json,$(ALL_TOOLS)) \
	>$@

metadata-full.json: \
		$(addsuffix /manifest-full.json,$(ALL_TOOLS)) \
		; $(info $(M) Creating $@...)
	@jq --slurp --compact-output '{"tools": map(.tools[])}' $(addsuffix /$@,$(ALL_TOOLS)) \
	>$@

.PHONY:
metadata.json--download:%--download: \
		; $(info $(M) Downloading metadata...)
	@set -o errexit; \
	regctl manifest get ghcr.io/uniget-org/tools/metadata:main --platform=local --format=raw-body \
	| jq --raw-output '.layers[0].digest' \
	| xargs regctl blob get ghcr.io/uniget-org/tools/metadata \
	| tar --extract --gzip --to-stdout metadata.json \
	>$*

.PHONY:
metadata-full.json--download:%--download: \
		; $(info $(M) Downloading full metadata...)
	@set -o errexit; \
	$(REGCTL) manifest get ghcr.io/uniget-org/tools/metadata:full --platform=local --format=raw-body \
	| jq --raw-output '.layers[0].digest' \
	| xargs $(REGCTL) blob get ghcr.io/uniget-org/tools/metadata \
	| tar --extract --gzip --to-stdout metadata.json \
	>$*

$(addsuffix --metadata-full,$(ALL_TOOLS_RAW)):%--metadata-full: \
		$(TOOLS_DIR)/%/manifest-full.json \
		; $(info $(M) Updating full metadata for $*...)
	@set -o errexit; \
	MANIFEST="$$(jq --compact-output '.tools[0]' $(TOOLS_DIR)/$*/manifest-full.json)"; \
	cat metadata-full.json \
	| jq --compact-output --arg tool $* 'del(.tools[] | select(.name == $$tool))' \
	>metadata-full.json.tmp; \
	cat metadata-full.json.tmp \
	| jq --compact-output \
		--argjson manifest "$${MANIFEST}" \
		'.tools += [$$manifest]' \
	>metadata-full.json; \
	rm -f metadata-full.json.tmp

.PHONY:
metadata.json--show:%--show:
	@less $*

.PHONY:
metadata.json--build: \
		metadata.json \
		@metadata/Dockerfile builders \
		; $(info $(M) Building metadata image for $(GIT_COMMIT_SHA)...)
	@set -o errexit; \
	if ! docker buildx build . \
			--builder uniget \
			--file @metadata/Dockerfile \
			--build-arg commit=$(GIT_COMMIT_SHA) \
			--platform linux/amd64,linux/arm64 \
			--tag $(REGISTRY)/$(REPOSITORY_PREFIX)metadata:$(DOCKER_TAG) \
			--push=$(or $(PUSH), false) \
			--provenance=false \
			--progress plain \
			>@metadata/build.log 2>&1; then \
		cat @metadata/build.log; \
		exit 1; \
	fi

.PHONY:
metadata-full.json--build: \
		@metadata/Dockerfile builders \
		; $(info $(M) Packaging full metadata image for $(GIT_COMMIT_SHA)...)
	@set -o errexit; \
	if ! docker buildx build . \
			--builder uniget \
			--file @metadata/Dockerfile \
			--build-arg commit=$(GIT_COMMIT_SHA) \
			--build-arg file=metadata-full.json \
			--platform linux/amd64,linux/arm64 \
			--tag $(REGISTRY)/$(REPOSITORY_PREFIX)metadata:full \
			--push=$(or $(PUSH), false) \
			--provenance=false \
			--progress plain \
			>@metadata/build.log 2>&1; then \
		cat @metadata/build.log; \
		exit 1; \
	fi

.PHONY:
metadata.json--push: \
		PUSH=true
metadata.json--push: \
		metadata.json--build \
		; $(info $(M) Pushing metadata image...)

.PHONY:
metadata-full.json--push: \
		PUSH=true
metadata-full.json--push: \
		metadata-full.json--build \
		; $(info $(M) Pushing metadata image...)

.PHONY:
metadata.json--sign: \
		$(HELPER)/var/lib/uniget/manifests/cosign.json \
		cosign.key \
		; $(info $(M) Signing metadata image...)
	@set -o errexit; \
	source .env; \
	cosign sign --key cosign.key $(REGISTRY)/$(REPOSITORY_PREFIX)metadata:$(DOCKER_TAG)

.PHONY:
metadata.json--keyless-sign: \
		$(HELPER)/var/lib/uniget/manifests/cosign.json \
		; $(info $(M) Keyless signing metadata image...)
	@set -o errexit; \
	COSIGN_EXPERIMENTAL=1 cosign sign $(REGISTRY)/$(REPOSITORY_PREFIX)metadata:$(DOCKER_TAG)
