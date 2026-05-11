# Adding New Tools

This guide explains how to add a new tool to this repository, where each tool is defined under `tools/<toolname>/` with:

- `manifest.yaml` for metadata
- `Dockerfile.template` for build instructions

## 1. Create the tool directory

```bash
mkdir tools/<toolname>
```

Use the canonical command/binary name for the directory. If needed, use a qualified name (for example `node-lts` or `gojq-is-jq`).

## 2. Add `manifest.yaml`

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
- `version`: Current packaged version.
- `check`: Command that prints installed version, usually with `${binary}`.
- `binary`: Override if binary name differs from tool name.
- `build_dependencies`: Tools needed while building.
- `runtime_dependencies`: Tools required at runtime.
- `platforms`: Supported platforms, commonly `linux/amd64` and `linux/arm64`.
- `conflicts_with`: Tools that provide the same command.

### Renovate options

Use the matching datasource for the upstream source:

- GitHub releases: `github-releases`
- GitHub tags: `github-tags`
- npm: `npm`
- PyPI: `pypi`
- Custom git host tags: `git-tags`
- Branch refs only: `git-refs`
- GitLab releases: `gitlab-releases`
- GitLab tags: `gitlab-tags`

## 3. Add `Dockerfile.template`

Start from `@template/Dockerfile.template` and choose the right packaging pattern.

## 4. Packaging patterns

### A. Prebuilt executable download

Use when upstream publishes a single binary.

### B. Tarball extraction

Use for `.tar.gz` or `.tar.xz` archives.

### C. Zip extraction

Use when releases are `.zip` files.

### D. Architecture mapping

Use a `case` block to map `${arch}` or `${alt_arch}` to upstream naming.

### E. Build from source (Go)

Use `go` (and optionally `make`) build dependencies, clone tagged source, compile, copy binary to `${prefix}/bin`.

### F. Build from source (Rust)

Use `rust` build dependency, build release binary, copy into `${prefix}/bin`.

### G. Python with `shiv`

Create a self-contained executable for Python CLIs.

### H. Python with `pipx`

Install package into isolated venv and symlink the binary.

### I. Node via npm

Install package in `/uniget_bootstrap/libexec/<tool>` and symlink `.bin` executable.

### J. Alias/shim tool

For wrapper tools, create a symlink and set `binary: "false"` if no own binary exists.

## 5. Optional additions

- Generate shell completions (bash/fish/zsh) into `${prefix}/share/...`
- Install man pages into `${prefix}/share/man/man1`

## 6. Validation helpers in build scripts

Common helpers available in templates:

- `check-download <url>`
- `check-github-release-asset "owner/repo" "tag" "filename"`
- `check-clone <url> <ref>`

## 7. Test your tool locally

For a changed tool `foo`, run:

```bash
make foo--build-amd64
```

If supported, also test arm64:

```bash
make foo--build-arm64
```

## 8. Choosing the right option quickly

- Single binary artifact: executable install
- Compressed release archive: tar/zip extraction
- No reliable binary artifacts: source build (Go/Rust)
- Python package CLI: shiv or pipx
- JavaScript CLI package: npm installation
- Compatibility alias: shim/symlink

## 9. Practical checklist

- Create `tools/<toolname>/`
- Add `manifest.yaml`
- Add `Dockerfile.template`
- Define renovate source
- Validate `check` command
- Build with `make <toolname>--build-amd64`
- Build arm64 if declared in `platforms`
- Ensure tags and dependencies are correct