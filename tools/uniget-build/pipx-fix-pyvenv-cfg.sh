#!/bin/bash

function pipx-fix-shared-pyvenv-cfg() {
    if ! type pipx &>/dev/null; then
        echo "pipx is not installed, skipping pipx fix"
        return 1
    fi

    local pipx_home="$(pipx environment --value=PIPX_HOME)"
    local python_version="$(python --version | cut -d' ' -f2)"
    local python_minor_version="$(echo "${python_version}" | cut -d'.' -f1,2)"

    echo "### Fixing shared pyvenv.cfg"
    cat >${pipx_home}/shared/pyvenv.cfg.go-template <<EOF
home = {{ .Target }}/bin
include-system-site-packages = false
version = ${python_version}
executable = {{ .Target }}/bin/python${python_minor_version}
command = {{ .Target }}/bin/python${python_minor_version} -m venv --clear {{ .Target }}/libexec/pipx/shared
EOF
}

function pipx-fix-venv-pyvenv-cfg() {
    local venv="$1"

    if test -z "${venv}"; then
        echo "ERROR: No venv name provided."
        return 1
    fi

    if ! type pipx &>/dev/null; then
        echo "ERROR: pipx is not installed."
        return 1
    fi

    local pipx_home="$(pipx environment --value=PIPX_HOME)"
    echo "### Detected pipx home: ${pipx_home}"

    if ! test -d "${pipx_home}/venvs/${venv}"; then
        echo "ERROR: pipx venv ${venv} does not exist."
        return 1
    fi

    echo "### Fixing pyvenv.cfg for ${venv}"
    mv "${pipx_home}/venvs/${venv}/pyvenv.cfg" "${pipx_home}/venvs/${venv}/pyvenv.cfg.go-template"
    sed -i "s|/usr/local|{{ .Target }}|; s|${prefix}|{{ .Target }}|" "${pipx_home}/venvs/${venv}/pyvenv.cfg.go-template"
}