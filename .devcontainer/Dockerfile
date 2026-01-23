#syntax=docker/dockerfile:1

FROM ghcr.io/uniget-org/tools/uniget:latest AS uniget
FROM ghcr.io/uniget-org/tools/git:latest AS git
FROM ghcr.io/uniget-org/tools/make:latest AS make
FROM ghcr.io/uniget-org/tools/gh:latest AS gh
FROM ghcr.io/uniget-org/tools/jq:latest AS jq
FROM ghcr.io/uniget-org/tools/regclient:latest AS regclient
FROM ghcr.io/uniget-org/tools/fuse-overlayfs:latest AS fuse-overlayfs
FROM ghcr.io/uniget-org/tools/docker-manpages:latest AS docker-manpages
FROM ghcr.io/uniget-org/tools/docker:latest AS docker
FROM ghcr.io/uniget-org/tools/cosign:latest AS cosign
FROM ghcr.io/uniget-org/tools/syft:latest AS syft
FROM ghcr.io/uniget-org/tools/grype:latest AS grype

FROM ubuntu:24.04
COPY --link --from=ghcr.io/uniget-org/tools/uniget:latest / /usr/local
COPY --link --from=ghcr.io/uniget-org/tools/git:latest / /usr/local
COPY --link --from=ghcr.io/uniget-org/tools/make:latest / /usr/local
COPY --link --from=ghcr.io/uniget-org/tools/gh:latest / /usr/local
COPY --link --from=ghcr.io/uniget-org/tools/jq:latest / /usr/local
COPY --link --from=ghcr.io/uniget-org/tools/regclient:latest / /usr/local
COPY --link --from=ghcr.io/uniget-org/tools/fuse-overlayfs:latest / /usr/local
COPY --link --from=ghcr.io/uniget-org/tools/docker-manpages:latest / /usr/local
COPY --link --from=ghcr.io/uniget-org/tools/docker:latest / /usr/local
COPY --link --from=ghcr.io/uniget-org/tools/cosign:latest / /usr/local
COPY --link --from=ghcr.io/uniget-org/tools/syft:latest / /usr/local
COPY --link --from=ghcr.io/uniget-org/tools/grype:latest / /usr/local