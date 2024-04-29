#!/bin/bash
set -o errexit -o pipefail

mkdir -p \
    "${target}/etc/containers"
cp "${target}/etc/containers/registries.conf" /etc/containers/
