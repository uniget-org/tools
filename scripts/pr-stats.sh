#!/bin/bash
set -o errexit -o pipefail

function process_prs() {
    jq '
        [
            .[] as $pr |
            $pr.labels[] | select(.name == "type/renovate") |
            select($pr.merged_at != null and $pr.created_at != null) |
            {
                "repo": $pr.base.repo.full_name,
                "number": "\($pr.number)",
                "link": "\($pr.base.repo.full_name)#\(.number)",
                "title": $pr.title,
                "createdAt": $pr.created_at,
                "createdAtDay": ($pr.created_at | fromdateiso8601 | strftime("%Y-%m-%d")),
                "mergedAt": $pr.merged_at,
                "openSeconds": ( ( ($pr.merged_at | fromdateiso8601) - ($pr.created_at | fromdateiso8601) ) / 1000 )
            }
        ]
    '
}

mkdir -p data
if ! test -f data/prs.json; then
    echo "Fetching PRs from uniget-org/tools"
    gh api --paginate "repos/uniget-org/tools/pulls?state=closed" \
    | process_prs \
    >data/prs.json
fi
if ! test -f data/prs-old.json; then
    echo "Fetching PRs from nicholasdille/docker-setup"
    gh api --paginate "repos/nicholasdille/docker-setup/pulls?state=closed" \
    | jq '
        [
            .[] |
            select(
                ( .number <= 603 ) or
                ( .number >= 3234 ) or
                ( .title | endswith(" (main)") )
            )
        ]
    ' \
    | process_prs \
    >data/prs-old.json
fi

cat data/prs.json data/prs-old.json \
| jq --slurp '.[0] + .[1]' \
>data/combined-prs.json

echo -n "Total PRs: "
cat data/combined-prs.json \
| jq 'length'

echo -n "First PR: "
cat data/combined-prs.json \
| jq -r 'sort_by(.createdAt) | .[0] | .createdAt'

echo "Analyzing PRs by day"
cat data/combined-prs.json \
| jq 'group_by(.createdAtDay)' \
| jq ' [ .[] | { "date": .[0].createdAtDay, "count": (. | length) } ]' \
| mlr --j2x stats1 -a min,mean,max -f count

echo "Analyzing duration of PRs"
cat data/combined-prs.json \
| mlr --j2x stats1 -a min,median,mean,p90,p95,p98,max -f openSeconds