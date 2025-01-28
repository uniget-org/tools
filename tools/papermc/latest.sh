#!/bin/bash

curl --silent --show-error --location --fail "https://api.papermc.io/v2/projects/paper" \
| jq --raw-output '.version_groups[-1]' \
| xargs -I{} \
    curl --silent --show-error --location --fail "https://api.papermc.io/v2/projects/paper/version_group/{}/builds" \
| jq --raw-output '.builds | map(select(.channel == "default")) | .[-1] | "\(.version)-\(.build)"'
