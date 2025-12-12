#!/bin/bash
set -o errexit

TMPDIR="$(mktemp -d)"
trap "rm -rf ${TMPDIR}" EXIT

make metadata.json

all_tools="$(
    jq --raw-output '.tools[] | .name' metadata.json \
    | sort \
    | xargs
)"

declare -A tool_json
mapfile tool_json_array < <(jq --raw-output --compact-output '.tools[] | "\(.name)=\(.)"' metadata.json)
i=0
while test "$i" -lt "${#tool_json_array[@]}"; do
    name_json=${tool_json_array[$i]}

    name="${name_json%%=*}"
    json="${name_json#*=}"
    tool_json[${name}]="${json}"

    i=$((i + 1))
done

curl -sSLf https://github.com/cncf/landscape/raw/refs/heads/master/landscape.yml \
| yq --output-format=json eval . \
| jq --raw-output '.landscape[].subcategories[].items[] | select(.project != null)' \
>"${TMPDIR}/repo_maturity.json"
jq --raw-output '"\(.repo_url)=\(.project)"' "${TMPDIR}/repo_maturity.json" \
>"${TMPDIR}/repo_maturity.txt"

declare -A repo_maturity
mapfile repo_maturity_array <"${TMPDIR}/repo_maturity.txt"
i=0
while test "$i" -lt "${#repo_maturity_array[@]}"; do
    key_value=${repo_maturity_array[$i]}

    key="${key_value%%=*}"
    value="${key_value#*=}"
    repo_maturity[${key}]="$( echo "${value}" | tr -d '\n' |tr -d '\r' )"

    i=$((i + 1))
done

for NAME in ${all_tools}; do
    echo "${NAME}"
    if ! test -f "tools/${NAME}/manifest.yaml"; then
        echo "+ No manifest.yaml found"
        continue
    fi

    graduated="$(
        if jq --exit-status 'select(.tags[] | contains("cncf/graduated"))' <<<"${tool_json[${NAME}]}" >/dev/null; then
            echo true
        else
            echo false
        fi
    )"
    incubating="$(
        if jq --exit-status 'select(.tags[] | contains("cncf/incubating"))' <<<"${tool_json[${NAME}]}" >/dev/null; then
            echo true
        else
            echo false
        fi
    )"
    sandbox="$(
        if jq --exit-status 'select(.tags[] | contains("cncf/sandbox"))' <<<"${tool_json[${NAME}]}" >/dev/null; then
            echo true
        else
            echo false
        fi
    )"
    archived="$(
        if jq --exit-status 'select(.tags[] | contains("cncf/archived"))' <<<"${tool_json[${NAME}]}" >/dev/null; then
            echo true
        else
            echo false
        fi
    )"

    repo_url="$(
        if jq --exit-status 'select(.repository != null)' <<<"${tool_json[${NAME}]}" >/dev/null; then
            echo "${tool_json[${NAME}]}" \
            | jq --raw-output '.repository'
        else
            echo ""
        fi
    )"
    if test -z "${repo_url}"; then
        echo "+ No repo_url found"
        continue
    fi
    echo "+ repo_url: ${repo_url}"
    echo "+ repo_maturity: ${repo_maturity[${repo_url}]}"

    if test "${repo_maturity[${repo_url}]}" == "graduated"; then
        if ! ${graduated}; then
            echo "+ Add cncf/graduated"
            yq --inplace '.tags += "cncf/graduated"' "tools/${NAME}/manifest.yaml"
        fi
    else
        if ${graduated}; then
            echo "+ Remove cncf/graduated"
            yq --inplace 'del( .tags[] | select(. == "cncf/graduated") )' "tools/${NAME}/manifest.yaml"
        fi
    fi
    if test "${repo_maturity[${repo_url}]}" == "incubating"; then
        if ! ${incubating}; then
            echo "+ Add cncf/incubating"
            yq --inplace '.tags += "cncf/incubating"' "tools/${NAME}/manifest.yaml"
        fi
    else
        if ${incubating}; then
            echo "+ Remove cncf/incubating"
            yq --inplace 'del( .tags[] | select(. == "cncf/incubating") )' "tools/${NAME}/manifest.yaml"
        fi
    fi
    if test "${repo_maturity[${repo_url}]}" == "sandbox"; then
        if ! ${sandbox}; then
            echo "+ Add cncf/sandbox"
            yq --inplace '.tags += "cncf/sandbox"' "tools/${NAME}/manifest.yaml"
        fi
    else
        if ${sandbox}; then
            echo "+ Remove cncf/sandbox"
            yq --inplace 'del( .tags[] | select(. == "cncf/sandbox") )' "tools/${NAME}/manifest.yaml"
        fi
    fi
    if test "${repo_maturity[${repo_url}]}" == "archived"; then
        if ! ${archived}; then
            echo "+ Add cncf/archived"
            yq --inplace '.tags += "cncf/archived"' "tools/${NAME}/manifest.yaml"
        fi
    else
        if ${archived}; then
            echo "+ Remove cncf/archived"
            yq --inplace 'del( .tags[] | select(. == "cncf/archived") )' "tools/${NAME}/manifest.yaml"
        fi
    fi

    sed -i -E 's/^  -/-/' "tools/${NAME}/manifest.yaml"
done
