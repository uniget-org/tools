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
    --volume "${PWD}/metadata.json:/tmp/test/var/cache/uniget/metadata.json" \
    --volume ${PWD}/tools/${TOOL}/image.tar:/tmp/${TOOL}.tar \
    registry.gitlab.com/uniget-org/cli:noble \
        bash -o errexit <<EOF
uniget --version
uniget --prefix=/tmp/test install --path-to-tar-mappings=${TOOL}=/tmp/${TOOL}.tar ${TOOL}
uniget --prefix=/tmp/test list --installed
uniget --prefix=/tmp/test healthcheck "${TOOL}"
uniget --prefix=/tmp/test version "${TOOL}"
EOF