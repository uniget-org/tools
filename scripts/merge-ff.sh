#!/bin/bash
set -o errexit

BRANCH="$1"
if test -z "${1}"; then
    echo "Usage: $0 <branch>"
    exit 1
fi

echo "### Fetching latest changes..."
git fetch origin

echo "### Rebasing branch ${BRANCH} onto main..."
git switch "${BRANCH}"
git rebase main

echo "### Merging branch ${BRANCH} into main (fast-forward)..."
git switch main
git merge --ff-only "${BRANCH}"
git push origin main

echo "### Pushing branch ${BRANCH}..."
git switch "${BRANCH}"
git push --force origin "${BRANCH}"
git switch main

echo "### Removing branch ${BRANCH}..."
git branch -d "${BRANCH}"
git push --delete origin "${BRANCH}"