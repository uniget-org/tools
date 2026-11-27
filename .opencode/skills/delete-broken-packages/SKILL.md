---
name: Delete Broken Packages
description: Delete ghcr.io/uniget-org/tools/<name> packages whose failed Check build was caused by "permission_denied: read_package", then rerun check.yml for the affected PRs
---

Delete container packages that can no longer be pushed because the package is
unreadable to the workflow token. Use the `gh` CLI (authenticated for
github.com). The repository is `uniget-org/tools`; the packages live in the
`uniget-org` organization on `ghcr.io`.

## Workflow

### 1. Find open pull requests without a `stuck/*` label

```sh
gh pr list --repo uniget-org/tools --state open \
  --json number,title,headRefName,headRefOid,labels
```

Discard every PR that has a label starting with `stuck/` before doing anything
else. The remaining PRs are the candidates to inspect.

For each remaining PR, find the most recent run of `check.yml` on its head
branch and pick the run whose `headSha` matches the PR's current head commit:

```sh
gh run list --repo uniget-org/tools --workflow check.yml \
  --branch <headRefName> --limit 5 --json databaseId,headSha,conclusion
```

Only the PRs whose latest run for the head commit has `conclusion == "failure"`
are candidates. Skip PRs whose run succeeded or that have no run for the head
commit.

### 2. Parse the failed log

```sh
gh run view <run-id> --repo uniget-org/tools --log-failed \
  | grep -oE 'ghcr\.io/uniget-org/tools/[^:]+:[^:]+: denied: permission_denied: read_package'
```

The full error line looks like:

```text
ERROR: failed to build: failed to solve: failed to push ghcr.io/uniget-org/tools/<name>:<version>: denied: permission_denied: read_package
```

The build is a matrix (one job per tool), so a single run may contain several
matches. Extract the package names (the part after `uniget-org/`, without the
tag):

```sh
... | sed -E 's#^ghcr\.io/uniget-org/(tools/[^:]+):[^:]+:.*#\1#' | sort -u
```

Skip PRs whose log contains no such line and note the actual failure reason in
the report.

### 3. Collect and display the packages

Collect every matched package from every candidate PR into one list **before
deleting anything**. Do not delete packages as you inspect each PR.

Display the full list to the human, including for each entry:

- Package name (`tools/<name>`)
- Version from the error line
- PR number and run ID

Deletion is destructive: it removes every version and tag of the package, not
just the version in the error. State that explicitly in the display.

### 4. Request approval

Do not delete anything until the human explicitly approves. If the `question`
tool is available, use it to present the collected packages (one option per
package, plus `Delete all listed packages` and `Cancel`; allow multiple
selections). Otherwise, ask in plain text which packages to delete.

Proceed only with the packages the human approved. If the answer is `Cancel`,
ambiguous, empty, or no answer is received, delete nothing and stop.

Never treat the original task request as approval — approval must come after
the package list has been displayed.

### 5. Delete the approved packages

For each approved package name, delete the whole package:

```sh
gh api --method DELETE "/orgs/uniget-org/packages/container/tools%2F<name>"
```

The slash in the package name must be URL-encoded as `%2F`. Deleting the
package removes every version and tag of `tools/<name>`, which is what lets the
next build create it fresh and regain write access. Do not delete only a
single version.

A `404` means the package is already gone; treat that as success. Any other
error (especially `403`/`401`) should be reported and the package left alone.

Deleting organization packages requires a token with the `delete:packages`
scope. If `gh api` fails with a permission error, ask the user to refresh the
token:

```sh
gh auth refresh -s delete:packages
```

### 6. Verify

Confirm each package no longer exists:

```sh
gh api "/orgs/uniget-org/packages/container/tools%2F<name>"
```

A `404` confirms deletion.

### 7. Retry `check.yml`

After the packages have been deleted, retry the failed `check.yml` run for each
affected PR. Use the run ID collected in step 3:

```sh
gh run rerun <run-id> --repo uniget-org/tools --failed
```

Retry each run at most once, even if it matched several packages. Only retry a
run when every package matched in that run was deleted (or was already absent).
If any matched package in the run was declined or could not be deleted, skip
the retry and report why — it would fail again with the same
`permission_denied: read_package` error.

Confirm the rerun was accepted, then report the run as in progress (or its
final conclusion if it already finished).

## Reporting

Summarize per PR:

- PR number and run ID
- Each matched package name (`tools/<name>`) and the version from the error line
- Whether the package was approved, declined, deleted, was already absent, or
  could not be deleted (with the error)
- Whether `check.yml` was rerun, skipped, or failed to start (with the error)

If approval was not given, report that the collected packages were left
untouched.

Do not touch the `stuck/*` labels — label management is left to the
repository's automation or the user.
