#!/bin/bash
set -o errexit -o pipefail

if test -z "${TOOL}"; then
    echo "TOOL is not set"
    exit 1
fi
if test -z "${VERSION}"; then
    echo "VERSION is not set"
    exit 1
fi

make metadata.json
mkdir -p test/var/cache/uniget
cp metadata.json test/var/cache/uniget/metadata.json

uniget --prefix=test generate uniget "${TOOL}@${VERSION}" \
| docker build --tag test --load -

docker run --interactive --rm --env TOOL --env VERSION --volume "${PWD}/metadata.json:/var/cache/uniget/metadata.json" test bash <<EOF
mv /usr/local/var/lib/uniget /var/lib/
uniget list --installed
uniget healthcheck "${TOOL}"
uniget version "${TOOL}
EOF