#!/bin/bash
set -o errexit -o pipefail

if test -z "${GITHUB_TOKEN}"; then
    echo "ERROR: Missing GITHUB_TOKEN."
    exit 1
fi

: "${GITHUB_REPOSITORY:=uniget-org/tools}"

curl --silent --show-error --fail --header "Authorization: token ${GITHUB_TOKEN}" \
    --url "https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls" \
| jq --compact-output '.[]' \
| while read -r PR_JSON; do
    PR="$( jq '.number' <<<"${PR_JSON}" )"
    if ! jq --raw-output '.labels[].name' <<<"${PR_JSON}" | grep -q "^type/renovate$"; then
        echo "PR ${PR} does not have label type/renovate. Skipping"
        continue
    fi

    COMMIT_SHA="$( jq --raw-output '.head.sha' <<<"${PR_JSON}" )"
    echo "Latest commit in PR ${PR} is ${COMMIT_SHA}"

    REVIEW_ID="$(
        curl --silent --show-error --fail --header "Authorization: token ${GITHUB_TOKEN}" \
            --url "https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls/${PR}/reviews" \
        | jq --raw-output --arg sha "${COMMIT_SHA}" '.[] | select(.state == "APPROVED" and .commit_id == $sha) | .id' \
        | xargs echo
    )"
    if test -n "${REVIEW_ID}"; then
        echo "PR ${PR} is already approved (ID ${REVIEW_ID}). Skipping"
        continue
    fi

    echo "Approving PR ${PR}"
    NEW_REVIEW_ID="$(
        curl --silent --show-error --fail --header "Authorization: token ${GITHUB_TOKEN}" \
            --url "https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls/${PR}/reviews" \
            --request POST \
            --data '{"commit_id": "'${COMMIT_SHA}'", "body": "Auto-approved because label type/renovate is present.", "event": "APPROVE"}' \
        | jq --raw-output '.id'
    )"
    echo "Review ID is ${NEW_REVIEW_ID}"
done