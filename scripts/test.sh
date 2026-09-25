#!/bin/bash
set -o errexit -o pipefail

if test -z "${TOOL}"; then
    echo "TOOL is not set"
    exit 1
fi

if jq --raw-output --exit-status '.tools[0] | select(.lifecycle != null) | select(.lifecycle.renamed_to != null)' "tools/${TOOL}/manifest.json" >/dev/null; then
    echo "Tool has been renamed"
    exit 0
fi
if jq --raw-output --exit-status '.tools[0] | select(.lifecycle != null) | select(.lifecycle.removed_with_reason != null)' "tools/${TOOL}/manifest.json" >/dev/null; then
    echo "Tool has been removed"
    exit 0
fi

make metadata.json
make "${TOOL}--tar"

docker run \
    --interactive \
    --rm \
    --env TOOL \
    --env UNIGET_IGNORE_METADATA_SIGNATURE=foo \
    --volume "${PWD}/metadata.json:/var/cache/uniget/metadata.json" \
    --volume ${PWD}/tools/${TOOL}/image.tar:/tmp/${TOOL}.tar \
    registry.gitlab.com/uniget-org/cli:noble \
        bash -o errexit <<EOF
uniget --version
uniget install --path-to-tar-mappings=${TOOL}=/tmp/${TOOL}.tar ${TOOL}
uniget list --installed
uniget healthcheck "${TOOL}"
uniget version "${TOOL}"
EOF