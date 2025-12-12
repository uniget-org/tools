#!/bin/bash
set -o errexit

make metadata.json

grep -l "^FROM ghcr.io/uniget-org/tools/" tools/*/Dockerfile.template \
| cut -d/ -f2 \
| while read -r TOOL; do
    DEPS="$(
        grep "^FROM registry.gitlab.com/uniget-org/tools/" tools/${TOOL}/Dockerfile.template \
        | cut -d' ' -f2 \
        | cut -d: -f1 \
        | cut -d/ -f4 \
        | xargs echo -n
    )"
    
    if test -n "${DEPS}"; then
        yq --inplace '.build_dependencies = []' tools/${TOOL}/manifest.yaml

        for DEP in $DEPS; do
            DEP=${DEP} yq --inplace '.build_dependencies += env(DEP)' tools/${TOOL}/manifest.yaml
        done

        sed -i -E 's/^\s{2}-/-/' tools/${TOOL}/manifest.yaml
    fi
done