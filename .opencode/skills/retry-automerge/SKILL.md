---
name: retry-automerge
description: Retry the Automerge workflow run for open PRs whose checks succeeded but whose automerge attempt failed
---

Retry failed automerges. Use the `gh` CLI (authenticated for github.com). The
repository is `uniget-org/tools`.

The `Automerge` workflow (`.github/workflows/automerge.yml`) is triggered by
`workflow_run` when a `Check` run completes successfully. Because of
`workflow_run`, every automerge run reports `main` as its branch, so a run
cannot be matched to a PR by branch. Instead, each automerge run's log echoes
`PR <number> uses branch <ref>` — that is the link between a run and a PR.

## Workflow

### 1. Find failed Automerge runs and map them to PRs

```sh
gh run list --repo uniget-org/tools --workflow automerge.yml \
  --status failure --limit 20 --json databaseId,createdAt
```

For each failed run, fetch the log and extract the PR number and branch:

```sh
gh run view <run-id> --repo uniget-org/tools --log-failed \
  | grep -oE "PR [0-9]+ uses branch [^ ]+$"
```

Skip runs whose log cannot be fetched or contains no such line, and report
why (logs expire; the run may have failed before the Test step echoed it).

### 2. Filter to open PRs with successful checks

For each mapped PR, verify:

- The PR is still open:

  ```sh
  gh pr view <number> --repo uniget-org/tools \
    --json state,headRefName,headRefOid,labels
  ```

- Its checks succeeded: find the latest `Check` run for the PR's head branch
  (`.github/workflows/check.yml`, job `Build container image`) and pick the
  run whose `headSha` matches the PR's current head commit:

  ```sh
  gh run list --repo uniget-org/tools --workflow check.yml \
    --branch <headRefName> --limit 5 --json databaseId,headSha,conclusion
  ```

  Only proceed if that run's `conclusion` is `success`. If it is `failure`,
  the automerge retry would be pointless — skip the PR (the
  `retry-missing-assets` skill covers that case).

- The PR has the `type/renovate` label. The automerge workflow cancels itself
  for PRs without it, so retrying is futile.

### 3. Retry the automerge

```sh
gh run rerun <run-id> --repo uniget-org/tools
```

Use a plain rerun (not `--failed`): the workflow has a single job, and the
retry re-runs the whole merge logic including its guard conditions.

Note that the retry will post comments on the PR again (`Attempting automerge.
See <url>.`) — that is the workflow's own behavior, not something to clean up.

## Reporting

Summarize per PR:

- PR number and branch
- Automerge run ID and URL (`https://github.com/uniget-org/tools/actions/runs/<run-id>`)
- Whether the PR's Check run succeeded
- Whether the automerge was rerun, and if not, why
