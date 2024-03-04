#!/bin/bash
set -o errexit

arch="$(uname -m)"
case "${arch}" in
    x86_64)
        alt_arch=amd64
        ;;
    aarch64)
        alt_arch=arm64
        ;;
    *)
        echo "ERROR: Unknown architecture ${arch}."
        exit 1
        ;;
esac
export arch
export alt_arch

export uniget_cache=/var/cache/uniget
export uniget_lib=/var/lib/uniget
export uniget_contrib="${uniget_lib}/contrib"
export uniget_manifests="${uniget_lib}/manifests"
export uniget_post_install="${uniget_lib}/post_install"
export prefix=/uniget_bootstrap

mkdir -p \
    "${prefix}${uniget_cache}" \
    "${prefix}${uniget_contrib}" \
    "${prefix}${uniget_manifests}" \
    "${prefix}${uniget_post_install}" \
    "${prefix}/etc/profile.d" \
    "${prefix}/etc/systemd/system" \
    "${prefix}/bin" \
    "${prefix}/etc" \
    "${prefix}/include" \
    "${prefix}/lib" \
    "${prefix}/libexec/docker/cli-plugins" \
    "${prefix}/opt" \
    "${prefix}/sbin" \
    "${prefix}/var" \
    "${prefix}/share/man/man1" \
    "${prefix}/share/man/man2" \
    "${prefix}/share/man/man3" \
    "${prefix}/share/man/man4" \
    "${prefix}/share/man/man5" \
    "${prefix}/share/man/man6" \
    "${prefix}/share/man/man7" \
    "${prefix}/share/man/man8" \
    "${prefix}/share/man/man9" \
    "${prefix}/share/bash-completion/completions" \
    "${prefix}/share/fish/vendor_completions.d" \
    "${prefix}/share/zsh/vendor-completions"

set +o errexit
