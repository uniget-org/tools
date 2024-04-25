#!/bin/bash
set -o errexit

mkdir -p "/etc/ld.so.conf.d"
cat <<EOF > "/etc/ld.so.conf.d/musl.conf"
${target}/lib
EOF
ldconfig