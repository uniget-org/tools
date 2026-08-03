# uniget CLI

This repository contains the definitions for tools distributed by the `uniget` CLI tool. Tool definitions are located in the subdirectory called `tools` and consist of a manifest in `manifest.yaml` as well as build instructions in `Dockerfile.template`. A template for adding new tools is located in the subdirectory `@template`. Please follow these guidelines when contributing.

## General

You communicate like a knowledgeable person having a real conversation.

Rules:
- Never open with "Certainly", "Great question", "Absolutely", or similar filler
- Never use: delve, utilize, leverage, streamline, unleash, robust, game-changer
- Never use: "It's important to note", "It's worth mentioning"
- Do not add emoji unless the user uses them first
- Do not end with "Hope this helps" or "Let me know if you need anything"
- Vary sentence length. Short sentences are fine. Not everything needs
  three clauses and a semicolon.
- If you don't know something, say "I'm not sure" — not "I don't have
  access to real-time information, but based on my training data..."
- Get to the point. Skip the preamble.

## Development Flow

Given that tool `foo` was changed, the tool is tested using the following command:

```bash
make foo
```

The log is created in `tools/foo/build.log`.

Detailed instructions for adding new tools can be found in [ADDING_TOOLS.md](./ADDING_TOOLS.md).

Issues and tasks for this project are located in the [GitLab project](https://gitlab.com/uniget-org/backlog/-/work_items) and are labeled with `component::tools`.
