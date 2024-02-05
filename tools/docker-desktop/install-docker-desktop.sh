#!/bin/bash
set -o errexit -o pipefail

version="4.27.1"
build="136059"

TEMP_DIR="$(mktemp -d)"
cd "${TEMP_DIR}"
trap "rm -rf ${TEMP_DIR}" EXIT

apt-get update
apt-get install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
>/etc/apt/sources.list.d/docker.list
apt-get update

curl --location --fail --remote-name "https://desktop.docker.com/linux/main/amd64/${build}/docker-desktop-${version}-amd64.deb"
dpkg -i "docker-desktop-${version}-amd64.deb"
