#!/bin/bash
set -o errexit

curl --silent --show-error --location --fail \
    --url "https://api.github.com/repos/indygreg/python-build-standalone/releases/latest" \
| jq --raw-output '.assets[].name' \
| grep -E -- '-x86_64-unknown-linux-musl-install_only.tar.gz$' \
| sed -E 's/^cpython-([^-]+)-.+$/\\1/' \
| grep -P '^3\\.12\\.' \
| sort -Vr \
| head -n 1
