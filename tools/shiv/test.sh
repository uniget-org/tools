#!/bin/bash

if test -z "${name}" || test -z "${version}"; then
    echo "Usage: name=... version=... $0"
    exit 1
fi

container="$(mktemp --dry-run | cut -d. -f2)"

function cleanup() {
    echo "### Cleaning up container ${container}"
    docker rm -f "${container}"
}
trap cleanup EXIT

echo "Testing ${name} ${version}"

echo "### Creating container ${container}"
if ! docker run \
    --name "${container}" \
    --detach \
    --privileged \
    --cgroupns=host \
    --volume /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --pull always \
    ghcr.io/uniget-org/cli:latest \
        sleep infinity
then
    echo "### Failed to create container"
    exit 1
fi
        
echo "### Executing test"
if ! time docker exec --interactive --env name --env version "${container}" bash -e <<"EOF"
uniget --version

uniget update
uniget install jq
mv /var/cache/uniget/metadata.json /var/cache/uniget/metadata.json.bak
jq --arg name "${name}" --arg version "${version}" '(.tools[] | select(.name == "\($name)") | .version) |= "\($version)"' /var/cache/uniget/metadata.json.bak > /var/cache/uniget/metadata.json
SHIV_VERSION="$( jq -r --arg name "${name}" '.tools[] | select(.name == "\($name)") | .version' /var/cache/uniget/metadata.json )"

uniget install shiv
shiv --version
shiv --output-file=/usr/local/bin/semgrep --console-script=semgrep semgrep
semgrep --version
EOF
then
    echo "### Failed to complete test"
    exit 1
fi