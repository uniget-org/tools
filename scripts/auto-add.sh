#!/bin/bash
set -o errexit
set -o pipefail

if test -z "${GITHUB_TOKEN}" ; then
    echo "GITHUB_TOKEN is not set"
    exit 1
fi

: "${GITHUB_REPOSITORY:=$1}"
if test -z "${GITHUB_REPOSITORY}" ; then
    echo "GITHUB_REPOSITORY is not set"
    exit 1
fi

REPO_JSON="$(
    curl --silent --show-error --location --fail --header "Authorization: token ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}"
)"
#name
#description
#language

LATEST_RELEASE_JSON="$(
    curl --silent --show-error --location --fail --header "Authorization: token ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/latest"
)"
#tag_name
#asset

cat <<EOF
# yaml-language-server: \$schema=https://tools.uniget.dev/schema.yaml
\$schema: https://tools.uniget.dev/schema.yaml
name: $(echo "${REPO_JSON}" | jq --raw-output '.name')
version: "$(echo "${LATEST_RELEASE_JSON}" | jq --raw-output '.tag_name' | tr -d v)"
check: ""
build_dependencies:
- bar
runtime_dependencies:
- baz
platforms:
- linux/amd64
#- linux/arm64
tags:
- org/?
- category/?
- lang/?
- type/?
homepage: https://github.com/${GITHUB_REPOSITORY}
description: $(echo "${REPO_JSON}" | jq --raw-output '.description')
renovate:
  datasource: github-releases
  package: ${GITHUB_REPOSITORY}
  extractVersion: ^v(?<version>.+?)$
  priority: low
EOF

echo "${LATEST_RELEASE_JSON}" | jq
for ASSET in $( seq 1 $( echo "${LATEST_RELEASE_JSON}" | jq --raw-output '.assets | length' ) ); do
    echo "asset ${ASSET}"
    echo "  url: $(echo "${LATEST_RELEASE_JSON}" | jq --raw-output --arg asset "${ASSET}" '.assets[$asset]')"
done