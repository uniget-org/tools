#!/bin/bash
set -o errexit -o pipefail

: "${version:=VERSION}"
echo "Using Docker Desktop version ${version}"

build="$(
    curl --silent --show-error --location --fail "https://github.com/docker/docs/raw/main/content/manuals/desktop/release-notes.md" \
    | grep -P "{{< desktop-install-v2 all=true.+ version=\"${version}\" " \
    | sed -E 's|^.+build_path="/([0-9]+)/".+$|\1|'
)"
if test -z "${build}"; then
    echo "Failed to find build for Docker Desktop version ${version}"
    exit 1
fi
echo "Using Docker Desktop version ${version} build ${build}"

TEMP_DIR="$(mktemp -d)"
cd "${TEMP_DIR}"
trap "rm -rf ${TEMP_DIR}" EXIT

if ! test -f /etc/apt/keyrings/docker.asc; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
fi

if ! test -f /etc/apt/sources.list.d/docker.list; then
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    >/etc/apt/sources.list.d/docker.list
fi
apt-get update

url="https://desktop.docker.com/linux/main/amd64/${build}/docker-desktop-amd64.deb"
echo "  Downloading from ${url}"
curl --location --fail --remote-name "${url}"
apt-get -y install ./docker-desktop-amd64.deb
