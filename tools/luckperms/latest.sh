#!/bin/bash
set -o errexit

LUCKPERMS_BUILD="$(
    curl --silent --show-error --location --fail "https://ci.lucko.me/job/LuckPerms/api/json?pretty=true" \
    | jq --raw-output '.builds[0].number'
)"
LUCKPERMS_VERSION="$(
    curl -sSLf "https://ci.lucko.me/job/LuckPerms/${LUCKPERMS_BUILD}/api/json?pretty=true" \
    | jq -r '.artifacts[] | select(.relativePath | contains("bukkit/")) | select(.relativePath | contains("-Bukkit-")) | .relativePath' \
    | cut -d/ -f5 \
    | cut -d- -f3 \
    | cut -d. -f1-3
)"
echo "${LUCKPERMS_VERSION}-${LUCKPERMS_BUILD}"