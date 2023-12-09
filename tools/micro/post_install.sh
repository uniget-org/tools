#!/bin/bash
set -o errexit

echo "Install systemd unit"
cat "${target}/etc/systemd/system/micro.service" \
| sed "s|ExecStart=/usr/local/bin/microd|ExecStart=${target}/bin/micro|" \
>/etc/systemd/system/micro.service

if systemctl >/dev/null 2>&1; then
    echo "Reload systemd"
    systemctl daemon-reload
fi