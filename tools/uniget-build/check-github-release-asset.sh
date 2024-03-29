#!/bin/bash

function check-github-release-asset() {
    local repo="$1"
    if test -z "${repo}"; then
        echo "Usage: $0 <owner/repo> <version> <asset>"
        return 1
    fi
    shift

    local version=$1
    if test -z "${version}"; then
        echo "Usage: $0 <owner/repo> <version> <asset>"
        return 1
    fi
    shift

    local asset=$1
    if test -z "${asset}"; then
        echo "Usage: $0 <owner/repo> <version> <asset>"
        return 1
    fi

    local url="https://github.com/${repo}/releases/download/${version}/${asset}"
    echo "### Checking ${repo} ${version} ${asset}"
    if curl --silent --show-error --location --fail --head --url "${url}"; then
        echo "    Found :-)"
        return
    fi
    echo "    ERROR: Asset ${asset} not found for ${repo} ${version}"
    echo "           at ${url}"

    echo "### Fetching release assets for ${repo} ${version}"
    local id
    local url="https://api.github.com/repos/${repo}/releases/tags/${version}"
    id="$(curl --silent --show-error --location "${url}" | jq --raw-output '.id')"
    if test -z "${id}" || test "${id}" == "null"; then
        echo "    ERROR: Failed to fetch release id for ${repo} ${version}"
        echo "           at ${url}"
        return 1
    fi
    echo "    Found release id ${id} for ${repo} ${version}"

    echo "### Fetching release assets for ${repo} ${version} with id ${id}"
    local url="https://api.github.com/repos/${repo}/releases/${id}/assets"
    if ! curl --silent --show-error --location --fail "${url}" | jq --raw-output '.[].name'; then
        echo "    ERROR: Failed to fetch release assets for ${repo} ${version}"
        echo "           at ${url}"
        return 1
    fi
    return 1
}