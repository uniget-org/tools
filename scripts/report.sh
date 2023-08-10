#!/bin/bash

if test -z "${GITHUB_TOKEN}"; then
    >&2 echo "ERROR: Missing environment variable GITHUB_TOKEN"
    exit 1
fi

today="$(date -d "yesterday" +%Y-%m-%dT00:00:00Z)"

cat <<EOF

############################################################
### Private packages
############################################################
EOF
curl --url "https://api.github.com/orgs/uniget-org/packages?package_type=container&visibility=private" \
    --silent \
    --fail \
    --header "Authorization: Bearer ${GITHUB_TOKEN}" \
| jq --raw-output '.[].name' \
| cut -d/ -f2

cat <<EOF

############################################################
### Closed pull requests
############################################################
EOF
curl 'https://api.github.com/repos/uniget-org/tools/pulls?state=closed&per_page=100' \
    --silent \
    --fail \
    --header "Authorization: token ${GITHUB_TOKEN}" \
| jq --raw-output --arg today "${today}" '
    .[]
    | select(.closed_at > $today)
    | "#\(.number) - \(.title) - https://github.com/uniget-org/tools/pull/\(.number)"
'

cat <<EOF

############################################################
### Failed workflow runs
############################################################
EOF
curl 'https://api.github.com/repos/uniget-org/tools/actions/runs?status=failure' \
    --silent \
    --fail \
    --header "Authorization: token ${GITHUB_TOKEN}" \
| jq --raw-output --arg today "${today}" '
    .workflow_runs[]
    | select(.run_started_at > $today)
    | "\(.display_title) (\(.name) #\(.run_number)) \(.html_url)"
'

cat <<EOF

############################################################
### Commits
############################################################
EOF
git --no-pager log \
    --since="${today}" \
    --stat