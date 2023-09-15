#!/bin/bash
set -o errexit -o pipefail

if test -z "${GITHUB_TOKEN}"; then
    echo "ERROR: Missing GITHUB_TOKEN."
    exit 1
fi

GITHUB_REPOSITORY=uniget-org/test-pr-actions
PR=13

# Ensure PR has label type/renovate
LABELS="$(
    curl --silent --show-error --fail --header "Authorization: token ${GITHUB_TOKEN}" \
        --url "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/${PR}/labels" \
    | jq -r '.[].name'
)"
if ! echo "${LABELS}" | grep -q "^type/renovate$"; then
    echo "PR ${PR} does not have label type/renovate. Aborting"
    exit 0
fi

# Get the latest commit from PR
COMMIT_SHA=$(
    curl --silent --show-error --fail --header "Authorization: token ${GITHUB_TOKEN}" \
        --url "https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls/${PR}/commits" \
    | jq -r '.[0].sha'
)
echo "Latest commit in PR ${PR} is ${COMMIT_SHA}"

# Create a review for the latest commit in PR
curl --silent --show-error --fail --header "Authorization: token ${GITHUB_TOKEN}" \
    --url "https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls/${PR}/reviews" \
    --request POST \
    --data "{\"commit_id\": \"${COMMIT_SHA}\", \"body\": \"Auto-approved because label type/renovate is present.\", \"event\": \"APPROVE\"}"
