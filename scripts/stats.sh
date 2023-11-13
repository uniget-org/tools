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

if ! test -f prs.json; then
    echo "Fetching PRs from uniget-org/tools"
    gh api --paginate "repos/uniget-org/tools/pulls?state=closed" >prs.json
fi
if ! test -f prs-old.json; then
    echo "Fetching PRs from nicholasdille/docker-setup"
    gh api --paginate "repos/nicholasdille/docker-setup/pulls?state=closed" \
    jq '
        .[] |
        select(
            ( .number <= 603 ) or
            ( .number >= 3234 ) or
            ( .title | endswith(" (main)") )
        )
    ' \
    >prs-old.json
fi
echo "Compiling reduced-prs.json"
cat prs-old.json prs-plain.json \
| jq --slurp '
    [
        .[] as $pr |
            $pr.labels[] | select(.name == "type/renovate") | $pr
    ]
' \
| process_prs \
>reduced-prs.json

echo "Total PRs"
cat reduced-prs.json \
| jq 'length'
echo "Analyzing PRs by day"
cat reduced-prs.json \
| jq 'group_by(.createdAtDay)' \
| jq ' [ .[] | { "date": .[0].createdAtDay, "count": (. | length) } ]' \
| mlr --j2x stats1 -a min,mean,max -f count

echo "Analyzing duration of PRs"
cat reduced-prs.json \
| mlr --j2x stats1 -a min,median,mean,max,p90,p98 -f openMilliseconds