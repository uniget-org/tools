#!/bin/bash
set -o errexit

SPARK_BUILD="$(
    curl --silent --show-error --location --fail "https://ci.lucko.me/job/spark/api/json?pretty=true" \
    | jq --raw-output '.builds[0].number'
)"
echo "Latest Spark build: ${SPARK_BUILD}"

SPARK_VERSION="$(
    curl -sSLf "https://ci.lucko.me/job/spark/${SPARK_BUILD}/api/json?pretty=true" \
    | jq -r '.artifacts[] | select(.relativePath | endswith("-bukkit.jar")) | .relativePath' \
    | cut -d/ -f4 \
    | cut -d- -f2
)"
echo "Latest Spark version: ${SPARK_VERSION}"

echo "Composite version: ${SPARK_VERSION}-${SPARK_BUILD}"