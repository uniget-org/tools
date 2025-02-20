#!/bin/bash
set -o errexit -o pipefail

function process_prs() {
    jq '
        [
            .[] |
            select(.merged_at != null and .created_at != null) |
            {
                "repo": .base.repo.full_name,
                "number": "\(.number)",
                "link": "\(.base.repo.full_name)#\(.number)",
                "title": .title,
                "createdAt": .created_at,
                "createdAtDay": (.created_at | fromdateiso8601 | strftime("%Y-%m-%d")),
                "mergedAt": .merged_at,
                "openMilliseconds": ( ( (.merged_at | fromdateiso8601) - (.created_at | fromdateiso8601) ) / 1000 )
            }
        ]
    '
}

if ! test -f data/prs.json; then
    echo "Fetching PRs from uniget-org/tools"
    gh api --paginate "repos/uniget-org/tools/pulls?state=closed" >data/prs.json
fi
if ! test -f data/prs-old.json.gz; then
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
    >data/prs-old.json
else
    gunzip data/prs-old.json.gz
fi
echo "Compiling reduced-prs.json"
cat data/prs-old.json data/prs.json \
| jq --slurp '
    [
        .[][] as $pr |
            $pr.labels[] | select(.name == "type/renovate") | $pr
    ]
' \
| process_prs \
>data/reduced-prs.json
gzip data/prs-old.json

echo "Total PRs"
cat data/reduced-prs.json \
| jq 'length'
echo "Analyzing PRs by day"
cat data/reduced-prs.json \
| jq 'group_by(.createdAtDay)' \
| jq ' [ .[] | { "date": .[0].createdAtDay, "count": (. | length) } ]' \
| mlr --j2x stats1 -a min,mean,max -f count

echo "Analyzing duration of PRs"
cat data/reduced-prs.json \
| mlr --j2x stats1 -a min,median,mean,max,p90,p95,p98 -f openMilliseconds