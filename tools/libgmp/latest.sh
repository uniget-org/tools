#!/bin/bash
set -o errexit

curl -sSLf https://ftp.gnu.org/gnu/gmp/ \
| xmllint -html --xpath "//a/@href" - \
| cut -d= -f2 \
| tr -d '"' \
| grep '.xz$' \
| sed -E 's/^gmp-(.+)\\.tar\\.xz$/\\1/' \
| sort -Vr \
| head -n 1
