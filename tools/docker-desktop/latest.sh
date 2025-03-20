#!/bin/bash
set -o errexit

curl --silent --show-error --location --fail \
    "https://github.com/docker/docs/raw/main/content/manuals/desktop/release-notes.md" \
| grep '{{< desktop-install-v2 all=true' \
| head -n 1 \
| sed -E 's/^.+version="([^"]+)".+$/\\1/'
