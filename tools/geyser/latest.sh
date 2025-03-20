#!/bin/bash
set -o errexit

curl -sSLf https://download.geysermc.org/v2/projects/geyser \
| jq --raw-output '.versions[-1]' \
| xargs -I{} \
    curl -sSLf https://download.geysermc.org/v2/projects/geyser/versions/{}/builds \
| jq --raw-output '"\(.version).\(.builds | map(select(.channel == "default")) | .[-1].build)"'
