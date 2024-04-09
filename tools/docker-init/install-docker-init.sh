#!/bin/bash
set -o errexit -o pipefail

target="${1:-/usr/local}"
: "${docker_desktop_version:=4.29.0}"
echo "Using Docker Desktop version ${docker_desktop_version}"
docker_desktop_build="$(
    curl --silent --show-error --location --fail "https://github.com/docker/docs/raw/main/content/desktop/release-notes.md" \
    | grep "{{< desktop-install all=true version=\"${docker_desktop_version}\" " \
    | sed -E 's|^.+build_path="/([0-9]+)/".+$|\1|'
)"
if test -z "${docker_desktop_build}"; then
    echo "Failed to find build for Docker Desktop version ${docker_desktop_version}"
    exit 1
fi
echo "Using Docker Desktop version ${docker_desktop_version} build ${docker_desktop_build}"

TEMP_DIR="$(mktemp -d)"
trap "rm -rf ${TEMP_DIR}" EXIT

curl --location --fail --output "${TEMP_DIR}/docker-desktop-${docker_desktop_version}-amd64.deb" "https://desktop.docker.com/linux/main/amd64/${docker_desktop_build}/docker-desktop-${docker_desktop_version}-amd64.deb"
ar -x "${TEMP_DIR}/docker-desktop-${docker_desktop_version}-amd64.deb" data.tar.xz --output "${TEMP_DIR}"
rm "${TEMP_DIR}/docker-desktop-${docker_desktop_version}-amd64.deb"

echo "Extracting to ${target}/libexec/docker/cli-plugins"
mkdir -p "${target}/libexec/docker/cli-plugins"
tar --extract --xz --file "${TEMP_DIR}/data.tar.xz" --directory "${target}/libexec/" --strip-components=3 --no-same-owner \
    ./usr/lib/docker/cli-plugins/docker-init
