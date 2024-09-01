#!/bin/bash
set -o errexit

if test -z "${GITHUB_TOKEN}"; then
    echo "ERROR: GITHUB_TOKEN is not set"
    exit 1
fi
: "${ref:=main}"
: "${workflow:=rebuild.yml}"
: "${repository:=uniget-org/tools}"
: "${batch_size:=100}"

function dispatch() {
    local repository="${1}"
    local ref="${2}"
    local workflow="${3}"
    local tools="${4}"
    local dryrun="${5:-false}"

    CURL="curl"
    if test -n "${dryrun}" && test "${dryrun}" == "true"; then
        CURL="echo curl"
    fi

    ${CURL} --silent --show-error --location --fail \
        --header "Authorization: Bearer ${GITHUB_TOKEN}" \
        --url "https://api.github.com/repos/${repository}/actions/workflows/${workflow}/dispatches" \
        --data "{\"ref\": \"${ref}\", \"inputs\": {\"tool\": \"$(echo "${tools}" | xargs echo)\"}}"
}

make metadata.json

TOOLS_DEPS="$(
    jq --raw-output '.tools[] | select(.build_dependencies != null) | .build_dependencies[]' <metadata.json \
    | sort \
    | uniq
)"
dispatch "${repository}" "${ref}" "${workflow}" "${TOOLS_DEPS}"
TOOLS_DEPS_REGEX_OR="$(
    echo "${TOOLS_DEPS}" \
    | jq --raw-input --raw-output '[inputs] | join("|")'
)"

TOOLS="$(
    jq --raw-output '.tools[].name' <metadata.json \
    | sort \
    | grep -E -v "(${TOOLS_DEPS_REGEX_OR})"
)"
SHUFFLED_TOOLS="$(
    echo "${TOOLS}" | shuf
)"
TOOLS_COUNT="$(echo "${TOOLS}" | wc -l)"

start_index=1
end_index="${TOOLS_COUNT}"
echo "### Processing ${TOOLS_COUNT} tools"
while test "${start_index}" -lt "${end_index}"; do
    echo "### Starting at ${start_index}"
    NEXT_TOOLS="$(
        echo "${SHUFFLED_TOOLS}" | tail -n +$(( start_index + 1 )) | head -n "${batch_size}"
    )"

    dispatch "${repository}" "${ref}" "${workflow}" "${NEXT_TOOLS}"

    start_index=$(( start_index + 100 ))
done
