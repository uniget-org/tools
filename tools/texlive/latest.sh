#!/bin/bash
set -o errexit

curl -sSLf https://texlive.info/historic/systems/texlive \
| xq --xpath '//a@href' \
| grep -E '^[0-9]' \
| cut -d/ -f1 \
| tail -n 1
