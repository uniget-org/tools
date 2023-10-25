#!/bin/bash
set -o errexit

echo "Install systemd unit"
cat "${target}/etc/systemd/system/cni-dhcp.service" \
| sed "s|ExecStart=/opt/cni/bin/dhcp|ExecStart=${target}/libexec/cni/dhcp|" \
>"/etc/systemd/system/cni-dhcp.service"
cat "${target}/etc/systemd/system/cni-dhcp.socket" \
>"/etc/systemd/system/cni-dhcp.socket"

if systemctl >/dev/null 2>&1; then
    echo "Reload systemd"
    systemctl daemon-reload
fi