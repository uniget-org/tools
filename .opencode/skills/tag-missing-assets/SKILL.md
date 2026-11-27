---
name: tag-missing-assets
description: Label open PRs with stuck/missing-asset when their failed Check build is caused by an unreachable download URL or missing release asset
---

Label pull requests whose Check build failed because a download URL or release
asset was missing. Use the `gh` CLI (authenticated for github.com). The
repository is `uniget-org/tools`.

This skill only applies labels. To retry runs whose asset is reachable again,
use the `retry-missing-assets` skill.

## Workflow

### 1. Find open pull requests with a failed Check run

The Check workflow is defined in `.github/workflows/check.yml` (name `Check`,
job `Build container image`; displayed in the UI as
`Check / Build container image (<tool>)`).

Only consider PRs that do not already carry a `stuck/*` label. Include labels
in the listing and filter out any PR whose labels contain an entry starting
with `stuck/`:

```sh
gh pr list --repo uniget-org/tools --state open \
  --json number,title,headRefName,headRefOid,labels
```

Discard every PR that has a label matching `stuck/*` before doing anything
else. The remaining PRs are the candidates to inspect.

For each remaining PR, find the most recent run of `check.yml` on its head
branch and
pick the run whose `headSha` matches the PR's current head commit:

```sh
gh run list --repo uniget-org/tools --workflow check.yml \
  --branch <headRefName> --limit 5 --json databaseId,headSha,conclusion
```

Only the PRs whose latest run for the head commit has `conclusion == "failure"`
are candidates. Skip PRs whose run succeeded or that have no run for the head
commit.

### 2. Check the log of the failed run

```sh
gh run view <run-id> --repo uniget-org/tools --log-failed
```

### 3. Find the error lines

Look for lines matching either pattern:

- `ERROR: Download <url> not found` — emitted by
  `tools/uniget-build/check-download.sh`; the token is the URL.
- `ERROR: Asset <asset> not found for <owner/repo> <version>` — emitted by
  `tools/uniget-build/check-github-release-asset.sh`, followed by a line
  ` at <url>` with the full URL
  (`https://github.com/<owner/repo>/releases/download/<version>/<asset>`).

```sh
gh run view <run-id> --repo uniget-org/tools --log-failed \
  | grep -E "ERROR: (Download|Asset)"
```

Log lines are prefixed with `<job>\t<step>\t`. The build is a matrix (one job
per tool), so one run may contain several error lines — one match is enough.

### 4. Add the label

If at least one error line is found, add the label `stuck/missing-asset` to
the PR:

```sh
gh pr edit <number> --repo uniget-org/tools --add-label stuck/missing-asset
```

Check the PR's existing labels first and skip PRs that already carry it. Do
not remove the label from PRs that no longer match — label removal is left to
the repository's automation or the user.

If no error line is found, leave the PR unlabeled and note the actual failure
reason in the report.

## Reporting

Summarize per PR:

- PR number and run ID
- Whether an error line was found (and which pattern)
- Whether the label was added, already present, or not applicable
