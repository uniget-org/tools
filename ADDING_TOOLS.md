# Adding New Tools

This guide explains how to add a new tool to this repository, where each tool is defined under `tools/<toolname>/` with:

- `manifest.yaml` for metadata
- `Dockerfile.template` for build instructions

## 1. Development Workflow

To maintain a clean history, always follow this workflow:

### Create a feature branch

Never commit directly to `main`. Create a new branch for your tool:

```bash
git checkout -b <toolname> main
```

### Use semantic commit messages

We use [Conventional Commits](https://www.conventionalcommits.org/). Your commit messages should follow this format:

`<type>(<scope>): <description>`

**Common types:**
- `feat`: A new tool or feature.
- `fix`: A bug fix.
- `chore`: Maintenance tasks (e.g., updating documentation or tags).
- `docs`: Documentation only changes.

**Example:**
`feat(<toolname>): Added`

Use the following commands:

```bash
git add tools/<toolname>
git -c commit.gpgsign=false commit -m "feat(<toolname>): Added"
```

Make sure commit signing is disabled.

### Create a Pull Request

Committed your changes and push the branch and create a Pull Request (PR) on GitHub:

```bash
git push origin <toolname>
gh pr create --title "feat(<toolname>): Added" --base main --head <toolname> --label ai-generated
```

Then, visit the link provided in the terminal output to open your PR.

## 2. Create the tool directory

```bash
mkdir tools/<toolname>
```

Use the canonical command/binary name for the directory. If needed, use a qualified name (for example `node-lts` or `gojq-is-jq`).

## 3. Add `manifest.yaml`

Start from `@template/manifest.yaml`.

```yaml
# yaml-language-server: $schema=https://tools.uniget.dev/schema.yaml
$schema: https://tools.uniget.dev/schema.yaml
name: foo
description: Some description
license:
  name: Unknown
  link: ""
homepage: https://example.org
repository: https://example.org/repo
version: "0.1.0"
tags:
- org/?
- category/?
- lang/?
- type/?
check: ""
build_dependencies:
- bar
runtime_dependencies:
- baz
platforms:
- linux/amd64
#- linux/arm64
```

### Important manifest fields

- `name`: Must match directory name.
- `version`: Current packaged version. **Always quote it.** An unquoted `version: 2.10` parses as a YAML float and loses the trailing zero; `version: "2.10"` survives (real case: `cloc`).
- `check`: Command that prints the installed version. Renovate and CI compare this output against `version`, so it must evaluate to the bare version string without `v` prefix or tool name. If the binary prints extra text, trim it (see below).
- `binary`: Override if binary name differs from tool name. Can be a plain name or a full path under `${target}` for components not shipped on `PATH`, e.g. `binary: ${target}/libexec/docker/cli-plugins/docker-model` (`docker-model-cli`).
- `build_dependencies`: Tools needed while building.
- `runtime_dependencies`: Tools required at runtime. Node and npm CLIs typically need `node-lts` at runtime; single-script CLIs need their interpreter (e.g. `perl` for `cloc`).
- `platforms`: Supported platforms, commonly `linux/amd64` and `linux/arm64`.
- `conflicts_with`: Tools that provide the same command.

### Writing the `check` command

The `check` command must output the version and nothing else. Common trimming patterns:

```yaml
# "tool 1.2.3 (abc123)" -> cut second field
check: ${binary} --version | cut -d' ' -f2
# "tool version: v1.2.3 ..." -> grep digits, drop v
check: ${binary} --version | grep -oP '\d+\.\d+\.\d+'
# "v1.2.3" -> drop the v prefix
check: ${binary} --version | cut -d' ' -f2 | tr -d v
```

Other cases seen in practice:

- Noisy or non-version output can be filtered with multiple pipes, e.g. `check: ${binary} version 2>&1 | tr -d ' ' | grep Version | head -n 1 | cut -d':' -f2` (`docker-model-cli`).
- TUI tools that cannot print a version non-interactively may use an empty `check: ""` (e.g. `argoxd`).
- pipx-based tools with shebang issues can query the package version from the venv instead of running the CLI, e.g. `check: ${target}/libexec/pipx/venvs/cve-mcp-server/bin/python -c 'import importlib.metadata; print(importlib.metadata.version("cve-mcp-server"))'` (`cve-mcp`).

Validate `check` against the actual binary output before submission. Incorrect version extraction is one of the most frequent follow-up fixes (`freebuff`, `docker-model-cli`).

### Choosing tags

To ensure consistency, always use tags that already exist in the repository. You can generate an up-to-date list of all used tags by running:

```bash
make metadata.json
```

Then, search through the resulting `metadata.json` for the tags you want to use.

### Renovate options

The `renovate:` block tells Renovate where to look for upstream versions. It goes into `manifest.yaml` (see the commented examples at the bottom of `@template/manifest.yaml`). The datasource is the **version source**, not necessarily where the code lives — npm and PyPI are authoritative for their packages even when the repository is on GitHub:

- GitHub releases: `github-releases` - most common
- GitHub tags: `github-tags` - GitHub without releases
- npm: `npm`
- PyPI: `pypi`
- Custom git host tags (Codeberg, Gitea, Forgejo): `git-tags` with full URL as `package`
- Branch refs only (no releases/tags): `git-refs`
- GitLab releases: `gitlab-releases`
- GitLab tags: `gitlab-tags`

A typical complete block:

```yaml
renovate:
  datasource: github-releases
  package: gokrazy/rsync
  extractVersion: ^v(?<version>.+)$
```

- `package` is `owner/repo` for GitHub, the package name for npm/PyPI, and a full URL for `git-tags`.
- `extractVersion` strips decorations such as a leading `v` from the upstream tag: `^v(?<version>.+)$` yields exactly the string stored in `version`. Adjust the regex when upstream names differ (e.g. `curl/-` prefixes on GitLab).
- The npm package name often differs from the command name: directory `asm` tracks npm package `agent-skill-manager`; `openclaude` tracks scoped package `@twigpine/openclaude` (quote scoped names in YAML).

## 4. Add `Dockerfile.template`

Start from `@template/Dockerfile.template` and choose the right packaging pattern.

## 5. Packaging patterns

### A. Prebuilt executable download

Use when upstream publishes a single binary. Download into the cache and `install --mode=0755` into `${prefix}/bin/<tool>` (see `herdr`). Single-file scripts work the same way, e.g. `cloc` installs a `.pl` file directly and depends on `perl` at runtime.

### B. Tarball extraction

Use for `.tar.gz` or `.tar.xz` archives. Always `tar --list` the archive first, then extract into `${prefix}/bin` with `--no-same-owner` (see `tuicr`, `tailcat`). When the binary inside the archive carries an arch suffix, rename it afterwards with `mv`, unguarded (see `zerostack`).

### C. Zip extraction

Use when releases are `.zip` files.

### D. Architecture mapping

`${arch}` contains `amd64` or `arm64`, while `${alt_arch}` contains `x86_64` or `aarch64`.

**Do not write a `case` block by default.** Try plain interpolation first. A repeated pattern in review of new tools was deleting redundant `case` blocks (`tuicr`, `tailcat`, `fx-vercel`, `kern`, `herdr`, `clawk`, `zerostack`, `md2pdf`), usually because the case produced a string identical to `${arch}`. Reach for a `case` block only when upstream naming genuinely differs from both variables, e.g. `gokr-rsync` which ships `rsync_Linux_x86_64.tar.gz` and `rsync_Linux_arm64.tar.gz` (a hybrid of both conventions).

Check the actual asset names on the upstream release page before writing the URL - the suffix zoo includes `${alt_arch}`, `${arch}`, `x86_64-unknown-linux-musl`, `amd64-unknown-linux-musl`, `linux-arm64`, and more:

| Upstream name pattern | Used by |
|---|---|
| `<tool>_<version>_linux_x86_64.tar.gz` | `argoxd`, `tailcat` (`${alt_arch}`) |
| `<tool>-<version>-amd64-unknown-linux-musl.tar.gz` | `tuicr`, `kern` (`${arch}`) |
| `<tool>-linux-amd64.tar.gz` / unversioned binary | `fx-vercel`, `herdr` (`${arch}`) |
| `<tool>-v<version>-linux-x86_64.tar.gz` | `clawk` (`${alt_arch}`) |
| `Linux_x86_64` vs `Linux_arm64` (inconsistent) | `gokr-rsync` (case block) |

### E. Build from source (Go)

Use `go` (and optionally `make`) build dependencies, clone tagged source, compile, copy binary to `${prefix}/bin`. Always validate the tag with `check-clone` before cloning (see `ax`).

### F. Build from source (Rust)

Use `rust` build dependency, build release binary, copy into `${prefix}/bin`.

### G. Python with `shiv`

Create a self-contained executable for Python CLIs. Prefer `shiv` when the package ships cleanly with no binary wheel issues:

```bash
shiv --output-file "${prefix}/bin/foo" --console-script foo "foo==${version}"
```

Declare `python-3.12` and `shiv` as build dependencies plus `python-3.12` as runtime dependency.

### H. Python with `pipx`

Prefer `pipx` when `shiv` produces a broken binary or the package has multiple entry points / scripts. pipx requires fix-ups, all shown in `@template/Dockerfile.template` and `cve-mcp`:

```bash
export PIPX_HOME="${prefix}/libexec/pipx"
export PIPX_BIN_DIR="${prefix}/bin"
pipx install foo
pipx-fix-venv-pyvenv-cfg foo    # required for the venv to work at runtime
ln --symbolic --relative --force "${prefix}/libexec/pipx/venvs/foo/bin/foo" "${prefix}/bin/foo"
sed -i "s|#\!${prefix}/|#\!/|" "${prefix}/libexec/pipx/venvs/foo/bin/foo"    # fix baked shebang path
```

**Verify the PyPI identity first.** If the project name on PyPI differs from the command or belongs to someone else, install from the git repository instead (`cve-mcp`): `pipx install "git+https://github.com/foo/bar.git@v${version}"`. Renovate keeps tracking GitHub releases in that case.

### I. Node via npm

Install package in `${prefix}/libexec/<tool>` (using `WORKDIR /uniget_bootstrap/libexec/<tool>`), symlink the `.bin` executable, and declare `node-lts` as build **and** runtime dependency. The npm package name frequently differs from the command name (`asm` / `agent-skill-manager`, `openclaude` / `@twigpine/openclaude`).

### J. Alias/shim tool

For wrapper tools, create a symlink and set `binary: "false"` if no own binary exists.

### K. Command name collisions

When the canonical command name is taken by another tool, qualify the directory name but keep the upstream binary name and declare the conflict (`fx-vercel` provides `fx` alongside the existing `fx` tool):

```yaml
binary: fx
conflicts_with:
- fx
```

## 6. Optional additions

- Generate shell completions (bash/fish/zsh) into `${prefix}/share/...`
- Install man pages into `${prefix}/share/man/man1`

## 7. Validation helpers in build scripts

Common helpers available in templates:

- `check-download <url>`
- `check-github-release-asset "owner/repo" "tag" "filename"`
- `check-clone <url> <ref>`

## 8. Test your tool locally

For a changed tool `foo`, run:

```bash
make foo
```

The log is located in `tools/foo/build.log`.

Do not test for arm64.

## 9. Choosing the right option quickly

- Single binary artifact: executable install
- Compressed release archive: tar/zip extraction
- No reliable binary artifacts: source build (Go/Rust)
- Python package CLI: shiv or pipx
- JavaScript CLI package: npm installation
- Compatibility alias: shim/symlink

## 10. Practical checklist

- Create `tools/<toolname>/`
- Open the upstream release page and confirm asset names and version format
- Add `manifest.yaml` (quoted version, validated `check` command, `renovate:` block, `binary`/`conflicts_with` if names differ)
- Add `Dockerfile.template` copied from the closest template variant (no unnecessary `case` block)
- Validate `check` command against real binary output
- Ensure every download has a `check-download`/`check-github-release-asset`
- Build with `make <toolname>--build-amd64`
- Do not build arm64 even if declared in `platforms`
- Verify tags against `make metadata.json`, dependencies correct
