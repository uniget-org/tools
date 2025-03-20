#!/bin/bash
set -o errexit

curl --silent --show-error --location --fail https://github.com/namespacelabs/homebrew-namespace/raw/main/nsc.rb \
| grep version \
| cut -d'"' -f2
