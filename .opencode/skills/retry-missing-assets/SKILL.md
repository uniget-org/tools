---
name: retry-missing-assets
description: Retry failed "Check / Build container image" workflow runs for PRs labeled stuck/missing-asset when the missing download URL is reachable again
---

Retry failed builds for pull requests whose builds failed because a download
URL was temporarily unreachable. Use the `gh` CLI (authenticated for
github.com). The repository is `uniget-org/tools`.

## Workflow

### 1. Find open pull requests with the label

```sh
gh pr list --repo uniget-org/tools --label stuck/missing-asset --state open \
  --json number,title,headRefName,headRepositoryOwner
```

If none are found, stop and report that.

### 2. Find the failed workflow run for each PR

The workflow is defined in `.github/workflows/check.yml` (name `Check`, job
`Build container image`; the GitHub UI displays it as
`Check / Build container image (<tool>)`).

For each PR, find the most recent failed run on its head branch:

```sh
gh run list --repo uniget-org/tools --workflow check.yml \
  --branch <headRefName> --status failure --limit 5 \
  --json databaseId,headSha,createdAt,event
```

Pick the run whose `headSha` matches the PR's current head commit. Skip the PR
if no failed run exists for its head branch.

### 3. Extract the URL from the failed log

Fetch the log of the failed steps and find the error line. It is emitted by
`tools/uniget-build/check-download.sh`:

```sh
gh run view <run-id> --repo uniget-org/tools --log-failed \
  | grep -E "ERROR: (Download|Asset)" \
  | sed -E 's/.*ERROR: (Download|Asset) ([^ ]+) not found.*/\2/'
```

Log lines are prefixed with `<job>\t<step>\t` — the `sed` above strips them.

- `ERROR: Download <url> not found` lines contain the URL directly.
- `ERROR: Asset <asset> not found for <owner/repo> <version>` lines are
  followed by a line ` at <url>` (emitted by
  `tools/uniget-build/check-github-release-asset.sh`); take the URL from
  there. It is always
  `https://github.com/<owner/repo>/releases/download/<version>/<asset>`.

The build is a matrix (one job per tool), so a single run may contain several
URLs. Collect all unique URLs. Skip the run if no `ERROR: Download` or
`ERROR: Asset` line is found and report why.

### 4. Check the URL

For each extracted URL, verify it is reachable. The build script uses
`curl --head --location --fail`, so mirror that with a HEAD request:

```sh
curl --silent --show-error --location --head \
  --output /dev/null --write-out '%{http_code}' '<url>'
```

Consider the URL reachable only if `curl` exits 0 and the HTTP code is < 400.

### 5. Retry the workflow

If every extracted URL from a run is reachable, retry only the failed jobs:

```sh
gh run rerun <run-id> --repo uniget-org/tools --failed
```

If any URL is still unreachable, do not retry that run.

## Reporting

Summarize per PR:

- Run ID and workflow URL (`https://github.com/uniget-org/tools/actions/runs/<run-id>`)
- Each URL with its HTTP code and the retry decision
- Whether the run was rerun

Do not remove the `stuck/missing-asset` label — leave label management to the
repository's automation or the user.
