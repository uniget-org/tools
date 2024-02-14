#!/bin/bash
set -o errexit -o pipefail

if test -z "${KCONFIG_CONFIG}"; then
    if test -z "$1"; then
        echo "ERROR: KCONFIG_CONFIG is not set and no argument was provided."
        return 1

    else
        KCONFIG_CONFIG="$1"
    fi
fi

if ! test -f "${KCONFIG_CONFIG}"; then
    echo "ERROR: KCONFIG_CONFIG is set to a non-existing file: ${KCONFIG_CONFIG}"
    return 1
fi

function assert_option() {
    local name="$1"

    if grep -q "^${name}=" "${KCONFIG_CONFIG}"; then
        echo "${name} is set"
        return 0
    fi

    if ! grep -q "^# ${name} is not set$" "${KCONFIG_CONFIG}"; then
        echo "ERROR: ${name} is not present"
        return 1
    fi
    
    echo "Adding ${name}=y"
    sed -i "s/^# ${name} is not set$/${name}=y/" "${KCONFIG_CONFIG}"
}

assert_option CONFIG_BPF
assert_option CONFIG_BPF_SYSCALL
assert_option CONFIG_NET_CLS_BPF
assert_option CONFIG_NET_ACT_BPF
assert_option CONFIG_BPF_JIT
assert_option CONFIG_HAVE_EBPF_JIT
assert_option CONFIG_BPF_EVENTS
assert_option CONFIG_IKHEADERS
assert_option CONFIG_NET_SCH_SFQ
assert_option CONFIG_NET_ACT_POLICE
assert_option CONFIG_NET_ACT_GACT
assert_option CONFIG_DUMMY
assert_option CONFIG_VXLAN
