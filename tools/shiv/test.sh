#!/bin/bash

: "${VERSION:=latest}"

container="$(mktemp --dry-run | cut -d. -f2)"

function cleanup() {
    echo "### Cleaning up container ${container}"
    docker rm -f "${container}"
}
trap cleanup EXIT

echo "### Creating container ${container}"
docker run \
    --name "${container}" \
    --detach \
    --privileged \
    --cgroupns=host \
    --volume /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --pull always \
    ghcr.io/uniget-org/cli:latest \
        sleep infinity
        
time docker exec --interactive "${container}" bash <<EOF
uniget --version

uniget install shiv
shiv --version
shiv --output-file=/usr/local/bin/semgrep --console-script=semgrep semgrep
semgrep --version
EOF
