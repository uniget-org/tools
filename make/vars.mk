M                   = $(shell printf "\033[34;1m▶\033[0m")
SHELL              := /bin/bash
GIT_BRANCH         ?= $(shell git branch --show-current)
GIT_COMMIT_SHA      = $(shell git rev-parse HEAD)
#VERSION            ?= $(patsubst v%,%,$(GIT_BRANCH))
VERSION            ?= main
DOCKER_TAG         ?= $(subst /,-,$(VERSION))
DOCKER_NETWORK     ?= default
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
REGISTRY2          ?= registry.gitlab.com
REPOSITORY_PREFIX2 ?= $(OWNER)/$(PROJECT)/
SOURCE1_PREFIX     ?= $(REGISTRY)/$(REPOSITORY_PREFIX)
SOURCE2_PREFIX     ?= $(REGISTRY2)/$(REPOSITORY_PREFIX2)

HELPER              = helper
BIN                 = $(HELPER)/usr/local/bin
export PATH        := $(BIN):$(PATH)

REGCTL             ?= regctl

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
