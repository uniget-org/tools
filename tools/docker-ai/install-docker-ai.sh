#!/bin/bash
set -o errexit -o pipefail

target="${1:-/usr/local}"
: "${docker_desktop_version:=4.41.2.191736}"
echo "Using Docker Desktop version ${docker_desktop_version}"
docker_desktop_real_version="$( cut -d. -f1-3 <<<"${docker_desktop_version}" )"
docker_desktop_build="$( cut -d. -f4 <<<"${docker_desktop_version}" )"
if test -z "${docker_desktop_build}"; then
    echo "Failed to find build for Docker Desktop version ${docker_desktop_version}"
    exit 1
fi
echo "Using Docker Desktop version ${docker_desktop_real_version} build ${docker_desktop_build}"

TEMP_DIR="$(mktemp -d)"
trap "rm -rf ${TEMP_DIR}" EXIT

curl --location --fail --output "${TEMP_DIR}/docker-desktop-amd64.deb" "https://desktop.docker.com/linux/main/amd64/${docker_desktop_build}/docker-desktop-amd64.deb"
ar -x "${TEMP_DIR}/docker-desktop-amd64.deb" data.tar.xz --output "${TEMP_DIR}"
rm "${TEMP_DIR}/docker-desktop-amd64.deb"

echo "Extracting to ${target}/libexec/docker/cli-plugins"
mkdir -p "${target}/libexec/docker/cli-plugins"
tar --extract --xz --file "${TEMP_DIR}/data.tar.xz" --directory "${target}/libexec/" --strip-components=3 --no-same-owner \
    ./usr/lib/docker/cli-plugins/docker-ai
