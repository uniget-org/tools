#!/bin/bash
set -o errexit

curl --silent --location --fail https://github.com/nodejs/Release/raw/main/schedule.json \
| jq -r 'to_entries[] | select(.value.maintenance > (now | todate)) | select(.value.lts != null) | select(.value.lts < (now | todate)) | .key' \
| xargs -I{} \
    git ls-remote https://github.com/nodejs/node "refs/tags/{}.*" \
| grep -v '\\^{}' \
| cut -f2 | cut -d/ -f3 | tr -d v \
| sort -Vr | head -1
