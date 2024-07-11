#!/bin/bash
set -o errexit

name=docker

if test -f "/etc/group"; then
    echo "Create group (@ ${SECONDS} seconds)"
    groupadd --prefix "" --system --force "${name}"
fi

if test -f "/etc/fstab"; then
    root_fs="$(cat "/etc/fstab" | grep -v "^#" | tr -s ' ' | grep " / " | cut -d' ' -f3)"
    if test -z "${root_fs}"; then
        root_fs="$(mount | grep " on / " | cut -d' ' -f5)"
    fi
    echo "Found ${root_fs} on /"

    if test "${root_fs}" == "overlay"; then

        if grep -qE "^[^:]+:[^:]*:/.+$" /proc/1/cgroup; then
            echo "Configuring storage driver for DinD"
            # shellcheck disable=SC2094
            cat <<< "$(jq '. * {"storage-driver": "fuse-overlayfs"}' "/etc/${name}/daemon.json")" >"/etc/${name}/daemon.json"
        fi
    fi
fi

if ! test "$(jq '."exec-opts" // [] | any(. | startswith("native.cgroupdriver="))' "/etc/${name}/daemon.json")" == "true"; then
    echo "Configuring native cgroup driver"

    if systemctl >/dev/null 2>&1; then
        # shellcheck disable=SC2094
        cat <<< "$(jq '."exec-opts" += ["native.cgroupdriver=systemd"]' "/etc/${name}/daemon.json")" >"/etc/${name}/daemon.json"
    else
        # shellcheck disable=SC2094
        cat <<< "$(jq '."exec-opts" += ["native.cgroupdriver=cgroupfs"]' "/etc/${name}/daemon.json")" >"/etc/${name}/daemon.json"
    fi
fi
