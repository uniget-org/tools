#!/bin/bash
set -o errexit -o pipefail

mkdir -p "${target}/usr/share/containers"
cp "${target}/usr/share/containers/storage.conf" /usr/share/containers/
