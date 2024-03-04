#!/bin/bash

function check-clone() {
    local repo="$1"
    if test -z "${repo}"; then
        echo "Usage: $0 <repo> <ref>"
        return 1
    fi
    shift

    local ref=$1
    if test -z "${ref}"; then
        echo "Usage: $0 <repo> <ref>"
        return 1
    fi

    echo "### Checking clone from repo ${repo} with ref ${ref}"
    if git ls-remote --exit-code "${repo}" "${ref}"; then
        echo "    Found :-)"
        return
    fi
    echo "    ERROR: Unable to find ref ${ref} in repo ${repo}"
    return 1
}