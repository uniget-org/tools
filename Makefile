M                   = $(shell printf "\033[34;1m▶\033[0m")
SHELL              := /bin/bash
GIT_BRANCH         ?= $(shell git branch --show-current)
GIT_COMMIT_SHA      = $(shell git rev-parse HEAD)
#VERSION            ?= $(patsubst v%,%,$(GIT_BRANCH))
VERSION            ?= main
DOCKER_TAG         ?= $(subst /,-,$(VERSION))
TOOLS_DIR           = tools
ALL_TOOLS           = $(shell find tools -type f -wholename \*/manifest.yaml | cut -d/ -f1-2 | sort)
ALL_TOOLS_RAW       = $(subst tools/,,$(ALL_TOOLS))
TOOLS              ?= $(shell find tools -type f -wholename \*/manifest.yaml | cut -d/ -f1-2 | sort)
TOOLS_RAW          ?= $(subst tools/,,$(TOOLS))
PREFIX             ?= /uniget_bootstrap
TARGET             ?= /usr/local

# Pre-defined colors: https://github.com/moby/buildkit/blob/master/util/progress/progressui/colors.go
BUILDKIT_COLORS    ?= run=light-blue:warning=yellow:error=red:cancel=255,165,0
NO_COLOR           ?= ""

OWNER              ?= uniget-org
PROJECT            ?= tools
REGISTRY           ?= ghcr.io
REPOSITORY_PREFIX  ?= $(OWNER)/$(PROJECT)/

HELPER              = helper
BIN                 = $(HELPER)/usr/local/bin
export PATH        := $(BIN):$(PATH)

SUPPORTED_ARCH     := x86_64 aarch64
SUPPORTED_ALT_ARCH := amd64 arm64
ARCH               ?= $(shell uname -m)
ifeq ($(ARCH),x86_64)
ALT_ARCH           := amd64
endif
ifeq ($(ARCH),aarch64)
ALT_ARCH           := arm64
endif
ifndef ALT_ARCH
$(error ERROR: Unable to determine alternative name for architecture ($(ARCH)))
endif

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
help:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo
	@echo "Reminder: foo-% => \$$@=foo-bar \$$*=bar"
	@echo
	@echo "Only some tools: TOOLS_RAW=\$$(jq -r '.tools[].name' metadata.json | grep ^k | xargs echo) make info"
	@echo

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

-include .env.mk
include make/dev.mk
include make/metadata.mk
include make/tool.mk
include make/sbom.mk
include make/ghcr.mk
include make/helper.mk
