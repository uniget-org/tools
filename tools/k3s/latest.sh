#!/bin/bash
set -o errexit

curl --silent --show-error --location --fail \
    --url "https://api.github.com/repos/k3s-io/k3s/releases/latest" \
| jq --raw-output '.tag_name' \
| sed -E 's/^v([[:digit:]]+\\.[[:digit:]]+\\.[[:digit:]]+)\\+k3s([[:digit:]]+)$/\\1.\\2/'
