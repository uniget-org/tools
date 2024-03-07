#!/bin/bash
set -o errexit -o pipefail

cp "${target}/usr/share/containers/storage.conf" /usr/share/containers/
