#!/bin/bash
set -o errexit

curl --silent --show-error --location --fail \
    --url "https://api.adoptium.net/v3/info/available_releases" \
| jq --raw-output '.available_releases | max' \
| xargs -I{} \
    curl --silent --show-error --location --fail \
        --url "https://api.github.com/repos/adoptium/temurin{}-binaries/releases/latest" \
| jq --raw-output '.tag_name' \
| sed 's/^jdk-//' \
| sed -E 's/^([[:digit:]]+\\.[[:digit:]]+\\.[[:digit:]]+)\\+([[:digit:]]+)$/\\1-\\2/'
