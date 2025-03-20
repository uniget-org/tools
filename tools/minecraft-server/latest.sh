#!/bin/bash
set -o errexit

curl -sSLf https://launchermeta.mojang.com/mc/game/version_manifest.json \
| jq --raw-output '.latest.release'
