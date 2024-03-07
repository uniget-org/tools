#!/bin/bash
set -o errexit -o pipefail

cp "${target}/etc/containers/registries.conf" /etc/containers/
