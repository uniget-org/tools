#!/bin/bash
set -o errexit -o pipefail

cp "${target}/etc/containers/policy.json" /etc/containers/
cp "${target}/etc/containers/registries.conf.d/shortnames.conf" /etc/containers/registries.conf.d/
cp "${target}/usr/share/containers/containers.conf" /usr/share/containers/
cp "${target}/usr/share/containers/seccomp.json" /usr/share/containers/
