# uniget CLI

This repository contains the definitions for tools distributed by the `uniget` CLI tool. Tool definitions are located in the subdirectory called `tools` and consist of a manifest in `manifest.yaml` as well as build instructions in `Dockerfile.template`. A template for adding new tools is located in the subdirectory `@template`. Please follow these guidelines when contributing:

## Development Flow

Given that tool `foo` was changed, the tool is tested using the following command:

```bash
make foo--build-amd64
```
