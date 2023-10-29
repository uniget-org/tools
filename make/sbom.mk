cosign.key: \
		$(HELPER)/var/lib/uniget/manifests/cosign.json \
		; $(info $(M) Creating key pair for cosign...)
	@set -o errexit; \
	source .env; \
	cosign generate-key-pair

.PHONY:
sign: \
		$(addsuffix --sign,$(TOOLS_RAW))

.PHONY:
keyless-sign: \
		$(addsuffix --keyless-sign,$(TOOLS_RAW))

.PHONY:
$(addsuffix --sign,$(ALL_TOOLS_RAW)):%--sign: \
		$(HELPER)/var/lib/uniget/manifests/cosign.json \
		cosign.key \
		; $(info $(M) Signing image for $*...)
	@set -o errexit; \
	source .env; \
	cosign sign --key cosign.key $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(DOCKER_TAG)

.PHONY:
$(addsuffix --keyless-sign,$(ALL_TOOLS_RAW)):%--keyless-sign: \
		$(HELPER)/var/lib/uniget/manifests/cosign.json \
		; $(info $(M) Keyless signing image for $*...)
	@set -o errexit; \
	COSIGN_EXPERIMENTAL=1 cosign sign $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(DOCKER_TAG) --yes

.PHONY:
sbom: \
		$(addsuffix /sbom.json,$(TOOLS))

.PHONY:
$(addsuffix --sbom,$(ALL_TOOLS_RAW)):%--sbom: \
		$(TOOLS_DIR)/%/sbom.json

$(addsuffix /sbom.json,$(ALL_TOOLS)):$(TOOLS_DIR)/%/sbom.json: \
		$(HELPER)/var/lib/uniget/manifests/syft.json \
		$(TOOLS_DIR)/%/manifest.json \
		$(TOOLS_DIR)/%/Dockerfile \
		; $(info $(M) Creating sbom for $*...)
	@set -o errexit; \
	TOOL_VERSION="$$(jq --raw-output '.tools[].version' tools/$*/manifest.json)"; \
	VERSION_TAG="$$( echo "$${TOOL_VERSION}" | tr '+' '-' )"; \
	./helper/usr/local/bin/syft packages $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(VERSION_TAG) --quiet --output cyclonedx-json=$(TOOLS_DIR)/$*/sbom.json

.PHONY:
bov: \
		$(addsuffix /bov.json,$(TOOLS))

.PHONY:
$(addsuffix --bov,$(ALL_TOOLS_RAW)):%--bov: \
		$(TOOLS_DIR)/%/bov.json

$(addsuffix /bov.json,$(ALL_TOOLS)):$(TOOLS_DIR)/%/bov.json: \
		$(HELPER)/var/lib/uniget/manifests/grype.json \
		$(TOOLS_DIR)/%/sbom.json \
		; $(info $(M) Creating bov for $*...)
	@./helper/usr/local/bin/grype sbom:$(TOOLS_DIR)/$*/sbom.json --quiet --file $(TOOLS_DIR)/$*/bov.json --output cyclonedx-json

.PHONY:
sarif: \
		$(addsuffix /sarif.json,$(TOOLS))

.PHONY:
$(addsuffix --sarif,$(ALL_TOOLS_RAW)):%--sarif: \
		$(TOOLS_DIR)/%/sarif.json

$(addsuffix /sarif.json,$(ALL_TOOLS)):$(TOOLS_DIR)/%/sarif.json: \
		$(HELPER)/var/lib/uniget/manifests/grype.json \
		$(TOOLS_DIR)/%/bov.json \
		; $(info $(M) Creating sarif for $*...)
	@grype sbom:$(TOOLS_DIR)/$*/bov.json --quiet --file $(TOOLS_DIR)/$*/sarif.json --output sarif

# make report | column --separator ';' --table --table-columns Tool,ID,purl,Score
.PHONY:
report: \
		$(addsuffix --report,$(TOOLS_RAW))

.PHONY:
$(addsuffix --report,$(ALL_TOOLS_RAW)):%--report: \
		$(TOOLS_DIR)/%/bov.json
	@jq --raw-output --arg tool "$*" '.vulnerabilities[] | "\($$tool);\(.id);\(.affects[].ref);\(.ratings[] | select(.method == "CVSSv31") | .score)"' $(TOOLS_DIR)/$*/bov.json

.PHONY:
attest: \
		$(addsuffix --attest,$(TOOLS_RAW))

.PHONY:
$(addsuffix --scan,$(ALL_TOOLS_RAW)):%--scan: \
		$(HELPER)/var/lib/uniget/manifests/grype.json \
		$(TOOLS_DIR)/%/sbom.json \
		; $(info $(M) Scanning sbom for $*...)
	@set -o errexit; \
	grype sbom:$(TOOLS_DIR)/$*/sbom.json --quiet --add-cpes-if-none --output table

.PHONY:
$(addsuffix --attest,$(ALL_TOOLS_RAW)):%--attest: \
		$(HELPER)/var/lib/uniget/manifests/cosign.json \
		sbom/%.json \
		cosign.key \
		; $(info $(M) Attesting sbom for $*...)
	@set -o errexit; \
	source .env; \
	cosign attest --predicate sbom/$*.json --type cyclonedx --key cosign.key $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(DOCKER_TAG)
