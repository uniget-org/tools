#!/bin/bash

: "${UNIGET_VERSION:=latest}"

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
    ghcr.io/uniget-org/cli:${UNIGET_VERSION} \
        sleep infinity
        
if ! time docker exec --interactive "${container}" bash -xe <<EOF
uniget --version

apt-get update
apt-get -y install iptables
groupadd --system docker

uniget install docker
ls -l /etc/systemd/system/
systemctl daemon-reload
systemctl disable docker.service
systemctl enable docker.socket
systemctl start docker.socket
docker version
EOF
then 
    echo "### Failed to test docker"
    sleep 10
    docker exec --interactive "${container}" bash -xe <<EOF
ps faux
journalctl -xe
EOF
    exit 1
fi