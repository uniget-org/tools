#!/bin/bash
set -o errexit -o pipefail

if test -z "${GITHUB_TOKEN}"; then
    echo "ERROR: Missing GITHUB_TOKEN."
    exit 1
fi

: "${GITHUB_REPOSITORY:=uniget-org/tools}"

# Get branch protection from API and extract required checks
# https://api.github.com/repos/ORG/REPO/branches/PROTECTED_BRANCH_NAME/protection/required_status_checks

curl --silent --show-error --fail --header "Authorization: token ${GITHUB_TOKEN}" \
    --url "https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls" \
| jq --compact-output '.[]' \
| while read -r PR_JSON; do
    PR="$( jq '.number' <<<"${PR_JSON}" )"
    echo
    echo "Processing PR ${PR}"

    if ! jq --raw-output '.labels[].name' <<<"${PR_JSON}" | grep -q "^type/renovate$"; then
        echo "PR ${PR} does not have label type/renovate. Skipping"
        continue
    fi

    # Alternative solution:
    # Get PR and check .mergeable_state
    # If 'unknown' retry after short delay
    # If 'blocked' continue
    # If 'clean' merge

    # Check for approval if required by branch protection
    # https://docs.github.com/en/rest/pulls/reviews?apiVersion=2022-11-28#list-reviews-for-a-pull-request
    # https://api.github.com/repos/OWNER/REPO/pulls/PULL_NUMBER/reviews

    HEAD_REF="$( jq --raw-output '.head.ref' <<<"${PR_JSON}" )"
    echo "HEAD reference in PR ${PR} is ${HEAD_REF}"

    CHECK_SUITE_ID="$(
        curl --silent --show-error --fail --header "Authorization: token ${GITHUB_TOKEN}" \
            --url "https://api.github.com/repos/${GITHUB_REPOSITORY}/commits/${HEAD_REF}/check-suites" \
        | jq --raw-output '.check_suites[] | select(.status == "completed" and .conclusion == "success") | .id' \
        | xargs echo
    )"
    # Fetch check run and check for status of required actions
    # .check_runs_url in JSON of check suite
    if test -z "${CHECK_SUITE_ID}"; then
        echo "PR ${PR} has not completed the checks"
        continue
    fi

    echo "PR ${PR} is ready for auto-merge"

    #break
done
