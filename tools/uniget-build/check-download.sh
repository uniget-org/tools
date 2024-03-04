#!/bin/bash

function check-download() {
    local url="$1"
    if test -z "${url}"; then
        echo "Usage: $0 <url>"
        return 1
    fi

    echo "### Checking ${url}"
    if curl --silent --show-error --location --fail --head --url "${url}"; then
        echo "    Found :-)"
        return
    fi
    echo "    ERROR: Download ${url} not found"
    return 1
}