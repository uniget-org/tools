-include .env.mk
include make/vars.mk
include make/dev.mk
include make/metadata.mk
include make/tool.mk
include make/sbom.mk
include make/ghcr.mk
include make/git.mk

check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $2, ($2))))

.PHONY:
all: $(ALL_TOOLS_RAW)

.PHONY:
info: ; $(info $(M) Runtime info...)
	@echo "BUILDKIT_COLORS:    $(BUILDKIT_COLORS)"
	@echo "NO_COLOR:           $(NO_COLOR)"
	@echo "GIT_BRANCH:         $(GIT_BRANCH)"
	@echo "GIT_COMMIT_SHA:     $(GIT_COMMIT_SHA)"
	@echo "VERSION:            $(VERSION)"
	@echo "DOCKER_TAG:         $(DOCKER_TAG)"
	@echo "DOCKER_NETWORK:     $(DOCKER_NETWORK)"
	@echo "OWNER:              $(OWNER)"
	@echo "PROJECT:            $(PROJECT)"
	@echo "REGISTRY:           $(REGISTRY)"
	@echo "REPOSITORY_PREFIX:  $(REPOSITORY_PREFIX)"
	@echo "TOOLS_RAW:          $(TOOLS_RAW)"
	@echo "SUPPORTED_ARCH:     $(SUPPORTED_ARCH)"
	@echo "SUPPORTED_ALT_ARCH: $(SUPPORTED_ALT_ARCH)"
	@echo "ARCH:               $(ARCH)"
	@echo "ALT_ARCH:           $(ALT_ARCH)"

.PHONY:
clean: ## Remove all temporary files
	@set -o errexit; \
	rm -f metadata.json; \
	rm -rf helper; \
	for TOOL in $(ALL_TOOLS_RAW); do \
		rm -f \
			$(TOOLS_DIR)/$${TOOL}/manifest.json \
			$(TOOLS_DIR)/$${TOOL}/Dockerfile \
			$(TOOLS_DIR)/$${TOOL}/build.log \
			$(TOOLS_DIR)/$${TOOL}/sbom.json; \
	done

.PHONY:
list: ## List available tools
	@echo "$(ALL_TOOLS_RAW)"

.PHONY:
$(addsuffix --show,$(ALL_TOOLS_RAW)):%--show: $(TOOLS_DIR)/$* ## Display directory contents
	@ls -l $(TOOLS_DIR)/$*
