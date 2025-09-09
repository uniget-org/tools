# Contributing to uniget packages

Thank you for considering contributing to uniget! We welcome any contributions, whether it's bug fixes, new features, or improvements to the existing codebase.

## Contribution Prerequisites

Make sure that you have [Docker](https://www.docker.com/) and [buildx](https://github.com/docker/buildx) installed. The containerized build environment enables you to use the same tooling as in CI.

## Sending a Pull/Merge Request

1. Create an issue in the repository outlining the fix or feature
1. Fork the repository to your own account and clone it locally
1. Complete and test the change
1. Create a concise commit message and reference the issue(s) and pull request(s) adressed
1. Ensure that CI passes. If it fails, fix the failures
1. Every pull/merge request requires a review by a maintainer

Please refer to the [documentation about authoring tools](https://docs.uniget.dev/authoring/) for more details.

## What to contribute

### Are you missing a tool?

- Please check `uniget update && uniget search <tool>` or `https://tools.uniget.dev` to see if the tool is already available
- Please check the issues if the tools was already requested
- Please check issue [GitHub #57](https://github.com/uniget-org/tools/issues/57) and [GitLab #?]() if it is already listed
- If the tool is not yet available, please follow the instructions above and refer to the [documentation about authoring new tools](https://docs.uniget.dev/authoring/)

### Is a tool not up-to-date?

If a tool is missing information for Renovate, please refer to existing tools and update the `manifest.yaml` accordingly

### Is a tool packaged incorrectly?

If a tool is missing files, configuration or dependencies, please refer to existing tools, the [documentation about authoring new tools](https://docs.uniget.dev/authoring/) and update the `Dockerfile.template` and `manifest.yaml` accordingly

## Code of Conduct

uniget adheres to and enforces the [Contributor Covenant](http://contributor-covenant.org/version/1/4/) Code of Conduct.
Please take a moment to read the [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) document.
