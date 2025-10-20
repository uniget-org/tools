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
    --volume "${PWD}/metadata.json:/var/cache/uniget/metadata.json" \
    --volume ${PWD}/tools/${TOOL}/image.tar:/tmp/${TOOL}.tar \
    registry.gitlab.com/uniget-org/images/ubuntu:24.04 \
        bash -o errexit <<EOF
curl -sLf https://github.com/uniget-org/cli/releases/latest/download/uniget_linux_$(uname -m).tar.gz \
| tar -xzC /usr/local/bin uniget
uniget --prefix=test install --path-to-tar-mappings=${TOOL}=/tmp/${TOOL}.tar ${TOOL}
uniget --prefix=test list --installed
uniget --prefix=test healthcheck "${TOOL}"
uniget --prefix=test version "${TOOL}"
EOF