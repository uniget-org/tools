#!/bin/bash
set -o errexit

name=docker-preview

if test -f "/etc/group"; then
    echo "Create group (@ ${SECONDS} seconds)"
    groupadd --prefix "" --system --force "${name}"
fi
