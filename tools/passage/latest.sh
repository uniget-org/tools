#!/bin/bash
set -o errexit

git clone --quiet https://github.com/FiloSottile/passage
echo "$(git -C passage rev-list --count --all).$(git -C passage rev-parse --short HEAD)"
