#!/bin/bash
set -o errexit -o pipefail

if test -z "${version}"; then
    echo "ERROR: Environment variable 'version' is not set."
    exit 1
fi
echo "Using Docker Desktop version ${version}"

real_version="$( cut -d. -f1-3 <<<"${version}" )"
build="$( cut -d. -f4 <<<"${version}" )"
if test -z "${build}"; then
    echo "Failed to find build for Docker Desktop version ${version}"
    exit 1
fi
echo "Using Docker Desktop version ${real_version} build ${build}"

TEMP_DIR="$(mktemp -d)"
cd "${TEMP_DIR}"
trap "rm -rf ${TEMP_DIR}" EXIT

if ! test -f /etc/apt/keyrings/docker.asc; then
    echo "  Adding Docker GPG key"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
fi

if ! test -f /etc/apt/sources.list.d/docker.list; then
    echo "  Adding Docker repository"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    >/etc/apt/sources.list.d/docker.list
fi
apt-get update

url="https://desktop.docker.com/linux/main/amd64/${build}/docker-desktop-amd64.deb"
echo "  Downloading from ${url}"
curl --location --fail --remote-name "${url}"
echo "  Installing"
apt-get -y install ./docker-desktop-amd64.deb
echo "  Done.
