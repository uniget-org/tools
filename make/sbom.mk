cosign.key: \
		$(HELPER)/var/lib/uniget/manifests/cosign.json \
		; $(info $(M) Creating key pair for cosign...) ## Create cosign key pair
	@set -o errexit; \
	source .env; \
	cosign generate-key-pair

.PHONY:
sign: \
		$(addsuffix --sign,$(TOOLS_RAW)) ## Sign all container images

.PHONY:
keyless-sign: \
		$(addsuffix --keyless-sign,$(TOOLS_RAW)) ## ???

.PHONY:
$(addsuffix --sign,$(ALL_TOOLS_RAW)):%--sign: \
		$(HELPER)/var/lib/uniget/manifests/cosign.json \
		cosign.key \
		; $(info $(M) Signing image for $*...) ## Sign container image for specific tool
	@set -o errexit; \
	source .env; \
	cosign sign --key cosign.key $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(DOCKER_TAG)

.PHONY:
$(addsuffix --keyless-sign,$(ALL_TOOLS_RAW)):%--keyless-sign: \
		$(HELPER)/var/lib/uniget/manifests/cosign.json \
		; $(info $(M) Keyless signing image for $*...) ## ???
	@set -o errexit; \
	COSIGN_EXPERIMENTAL=1 cosign sign $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(DOCKER_TAG) --yes

.PHONY:
sbom: \
		$(addsuffix /sbom.json,$(TOOLS)) ## Create SBoM for all tools

.PHONY:
$(addsuffix --sbom,$(ALL_TOOLS_RAW)):%--sbom: \
		$(TOOLS_DIR)/%/sbom.json

$(addsuffix /sbom.json,$(ALL_TOOLS)):$(TOOLS_DIR)/%/sbom.json: \
		$(HELPER)/var/lib/uniget/manifests/gojq.json \
		$(HELPER)/var/lib/uniget/manifests/syft.json \
		$(TOOLS_DIR)/%/manifest.json \
		$(TOOLS_DIR)/%/Dockerfile \
		; $(info $(M) Creating sbom for $*...) ## Create SBoM for a specific tool
	@set -o errexit; \
	TOOL_VERSION="$$(jq --raw-output '.tools[].version' tools/$*/manifest.json)"; \
	VERSION_TAG="$$( echo "$${TOOL_VERSION}" | tr '+' '-' )"; \
	echo "Scanning image for $* v$${TOOL_VERSION} with tag $${VERSION_TAG}"; \
	./helper/usr/local/bin/syft packages $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$${VERSION_TAG} --quiet --output cyclonedx-json=$(TOOLS_DIR)/$*/sbom.json

.PHONY:
grype-db-update: \
		$(HELPER)/var/lib/uniget/manifests/grype.json \
		; $(info $(M) Updating grype database...) ## ???
	@set -o errexit; \
	grype db update

.PHONY:
bov: \
		grype-db-update \
		$(addsuffix /bov.json,$(TOOLS)) ## ???

.PHONY:
$(addsuffix --bov,$(ALL_TOOLS_RAW)):%--bov: \
		$(TOOLS_DIR)/%/bov.json ## ???

$(addsuffix /bov.json,$(ALL_TOOLS)):$(TOOLS_DIR)/%/bov.json: \
		$(HELPER)/var/lib/uniget/manifests/grype.json \
		$(TOOLS_DIR)/%/sbom.json \
		; $(info $(M) Creating bov for $*...) ## ???
	@./helper/usr/local/bin/grype sbom:$(TOOLS_DIR)/$*/sbom.json --quiet --file $(TOOLS_DIR)/$*/bov.json --output cyclonedx-json

.PHONY:
sarif: \
		grype-db-update \
		$(addsuffix /sarif.json,$(TOOLS)) ## ???

.PHONY:
$(addsuffix --sarif,$(ALL_TOOLS_RAW)):%--sarif: \
		$(TOOLS_DIR)/%/sarif.json ## ???

$(addsuffix /sarif.json,$(ALL_TOOLS)):$(TOOLS_DIR)/%/sarif.json: \
		$(HELPER)/var/lib/uniget/manifests/grype.json \
		$(TOOLS_DIR)/%/bov.json \
		; $(info $(M) Creating sarif for $*...) ## ???
	@grype sbom:$(TOOLS_DIR)/$*/bov.json --quiet --file $(TOOLS_DIR)/$*/sarif.json --output sarif

.PHONY:
report: \
		grype-db-update \
		$(addsuffix --report,$(TOOLS_RAW)) ## ???

.PHONY:
$(addsuffix --report,$(ALL_TOOLS_RAW)):%--report: \
		$(HELPER)/var/lib/uniget/manifests/gojq.json \
		$(TOOLS_DIR)/%/report.csv ## ???

$(addsuffix /report.csv,$(ALL_TOOLS)):$(TOOLS_DIR)/%/report.csv: \
		$(TOOLS_DIR)/%/bov.json ## ???
	@jq --raw-output --arg tool "$*" \
		'[ .vulnerabilities[] | "\($$tool);\(.id);\(.affects[].ref | split("?")[0]);\(.ratings[] | select(.method == "CVSSv31" and .score  >= 7.0) | .score)" ] | unique[]' $(TOOLS_DIR)/$*/bov.json \
		>$(TOOLS_DIR)/$*/report.csv

.PHONY:
table: \
		$(addsuffix /report.csv,$(ALL_TOOLS)) ## ???
	@column --separator ';' --table --table-columns Tool,ID,purl,Score */*/report.csv

.PHONY:
$(addsuffix --table,$(ALL_TOOLS_RAW)):%--table: \
		$(TOOLS_DIR)/%/report.csv ## ???
	@column --separator ';' --table --table-columns Tool,ID,purl,Score $(TOOLS_DIR)/$*/report.csv

.PHONY:
attest: \
		$(addsuffix --attest,$(TOOLS_RAW)) ## Attest SBoM for all tools

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
		; $(info $(M) Attesting sbom for $*...) ## Attest SBoM for specific tool
	@set -o errexit; \
	source .env; \
	cosign attest --predicate sbom/$*.json --type cyclonedx --key cosign.key $(REGISTRY)/$(REPOSITORY_PREFIX)$*:$(DOCKER_TAG)
