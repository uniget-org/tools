#!/bin/bash

tool=$1

if test -z "$tool"; then
  echo "Usage: $0 <tool>"
  exit 1
fi

git branch "${tool}"
git switch "${tool}"
git add --all
git commit --message "Add ${tool}"
git push --set-upstream origin "${tool}"

gh pr create --fill

git switch main