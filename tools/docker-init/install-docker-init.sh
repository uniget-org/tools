#!/bin/bash
set -o errexit -o pipefail

target="${1:-/usr/local}"
version="4.29.0"
build="145265"

TEMP_DIR="$(mktemp -d)"
cd "${TEMP_DIR}"
trap "rm -rf ${TEMP_DIR}" EXIT

curl --location --fail --remote-name "https://desktop.docker.com/linux/main/amd64/${build}/docker-desktop-${version}-amd64.deb"
ar -x "docker-desktop-${version}-amd64.deb" data.tar.xz
rm "docker-desktop-${version}-amd64.deb"

mkdir -p "${target}/libexec/docker/cli-plugins"
tar --extract --xz --file data.tar.xz --directory "${target}/libexec/" --strip-components=3 --no-same-owner \
    ./usr/lib/docker/cli-plugins/docker-init
