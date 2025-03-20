#!/bin/bash
set -o errexit

curl --silent --show-error --location --fail \
    --url "https://api.github.com/repos/rancher/rke2/releases/latest" \
| jq --raw-output '.tag_name' \
| sed -E 's/^v([[:digit:]]+\\.[[:digit:]]+\\.[[:digit:]]+)\\+rke2r([[:digit:]]+)$/\\1.\\2/'
