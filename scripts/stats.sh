#!/bin/bash
set -o errexit -o pipefail

if ! test -f prs.json; then
    gh api --paginate "repos/uniget-org/tools/pulls?state=closed" >prs.json
fi

cat pors.json \
| jq '
    [
        .[] |
        {
            "number": .number,
            "title": .title,
            "createdAt": (.created_at | fromdateiso8601 | strftime("%Y-%m-%d")),
            "mergedAt": .merged_at
        }
    ]
' \
| jq 'group_by(.createdAtDay)' \
| jq ' [ .[] | { "date": .[0].createdAtDay, "count": (. | length) } ]'