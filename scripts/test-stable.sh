#!/bin/bash
set -o errexit -o pipefail

if test -z "${TOOL}"; then
    echo "TOOL is not set"
    exit 1
fi

docker run \
    --interactive \
    --rm \
    --env TOOL \
    registry.gitlab.com/uniget-org/cli:noble \
        bash -o errexit <<EOF
uniget install ${TOOL}
uniget healthcheck "${TOOL}"
uniget version "${TOOL}"
EOF