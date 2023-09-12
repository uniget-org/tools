#!/bin/bash
set -o errexit

mkdir -p /etc/containers
ln --symbolic --force "${target}/etc/containers/registries.conf" "/etc/containers/"
ln --symbolic --force "${target}/etc/containers/registries.json" "/etc/containers/"

echo "Install systemd unit"
cat "${target}/etc/systemd/system/podman.service" \
| sed "s|ExecStart=/usr/local/bin/podman|ExecStart=${target}/bin/podman|" \
>"/etc/systemd/system/podman.service"

if systemctl >/dev/null 2>&1; then
    echo "Reload systemd"
    systemctl daemon-reload
fi