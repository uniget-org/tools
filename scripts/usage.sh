#!/bin/bash

: "${REGISTRY:=ghcr.io}"
: "${OWNER:=uniget-org}"
: "${PROJECT:=tools}"
: "${VERSION:=latest}"

SUM=0
(
    for TOOL in $@; do
        SIZE_AMD64="$(
            regctl manifest get ${REGISTRY}/${OWNER}/${PROJECT}/${TOOL}:${VERSION} --platform linux/amd64 --format raw-body \
            | jq -r '.layers[].size' \
            | paste -sd+ \
            | bc
        )"
        SUM=$(( SUM + SIZE_AMD64 ))

        SIZE_ARM64="$(
            regctl manifest get ${REGISTRY}/${OWNER}/${PROJECT}/${TOOL}:${VERSION} --platform linux/arm64 --format raw-body \
            | jq -r '.layers[].size' \
            | paste -sd+ \
            | bc
        )"
        SUM=$(( SUM + SIZE_ARM64 ))

        SIZE=$(( SIZE_AMD64 + SIZE_ARM64 ))

        SIZE_HUMAN="$( echo "${SIZE}" | numfmt --to=iec --format=%7.1f )"
        echo "${SIZE_HUMAN} ${TOOL}"
    done

    SUM_HUMAN="$( echo "${SUM}" | numfmt --to=iec --format=%7.1f )"
    echo "${SUM_HUMAN}"

) | column --table --table-right=1
