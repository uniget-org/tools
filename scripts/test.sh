#!/bin/bash
set -o errexit -o pipefail

if test -z "${TOOL}"; then
    echo "TOOL is not set"
    exit 1
fi

make metadata.json
make "${TOOL}--tar"

docker run \
    --interactive \
    --rm \
    --env TOOL \
    --env UNIGET_IGNORE_METADATA_SIGNATURE="true" \
    --volume "${PWD}/metadata.json:/var/cache/uniget/metadata.json" \
    --volume ${PWD}/tools/${TOOL}/image.tar:/tmp/${TOOL}.tar \
    registry.gitlab.com/uniget-org/cli:noble \
        bash -o errexit <<EOF
uniget --version
echo "UNIGET_IGNORE_METADATA_SIGNATURE: ${UNIGET_IGNORE_METADATA_SIGNATURE}"
uniget install --path-to-tar-mappings=${TOOL}=/tmp/${TOOL}.tar ${TOOL}
uniget list --installed
uniget healthcheck "${TOOL}"
uniget version "${TOOL}"
EOF