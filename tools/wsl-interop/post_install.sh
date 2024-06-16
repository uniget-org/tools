#!/bin/bash
set -o errexit


if systemctl >/dev/null 2>&1; then
    echo "Reload systemd"
    systemctl daemon-reload

    systemctl enable wslinterop-force.service wslinterop-monitor.path
    systemctl start wslinterop-force.service wslinterop-monitor.path
fi