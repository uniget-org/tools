#!/bin/bash
set -o errexit -o pipefail

function process_prs() {
    jq '
        [
            .[] |
            {
                "number": "\(.base.repo.full_name)#\(.number)",
                "title": .title,
                "createdAt": (.created_at | fromdateiso8601 | strftime("%Y-%m-%d")),
                "mergedAt": .merged_at
            }
        ]
    ' \
    | jq 'group_by(.createdAtDay)' \
    | jq ' [ .[] | { "date": .[0].createdAtDay, "count": (. | length) } ]'
}

if ! test -f prs.json; then
    gh api --paginate "repos/uniget-org/tools/pulls?state=closed" >prs.json
fi
if ! test -f prs-old.json; then
    gh api --paginate "repos/nicholasdille/docker-setup/pulls?state=closed" >prs-old.json
fi
cat prs-old.json prs.json \
| process_prs \
>plot.json

mlr --j2x --from plot.json stats1 -a min,mean,max -f count