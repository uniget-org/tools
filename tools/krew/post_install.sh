#!/bin/bash
set -o errexit

echo "Add to path"
cat >"${target}/etc/profile.d/krew.sh" <<"EOF"
export PATH="${HOME}/.krew/bin:${PATH}"
EOF