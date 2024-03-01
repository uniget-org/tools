#!/bin/bash
set -o errexit

echo "Install systemd unit"
cat "${target}/etc/systemd/system/traefik.service" \
| sed "s|#ExecStart=/usr/bin/traefik|ExecStart=${target}/bin/traefik|" \
>/etc/systemd/system/traefik.service

if systemctl >/dev/null 2>&1; then
    echo "Reload systemd"
    systemctl daemon-reload
fi