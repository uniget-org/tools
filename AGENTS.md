# Plan: Adding New Tools to Uniget

This document captures the planning methodology and execution steps for adding new tools to the uniget tools repository.

## Planning Phase

### 1. Tool Selection Criteria

Before starting implementation, verify:

- **Source availability**: GitHub releases, PyPI, GitLab, etc.
- **Platform support**: Confirm amd64 and/or arm64 Linux artifacts exist
- **Release format**: Binary tarball, direct binary, source archive?
- **License**: Open source with clear licensing
- **Dependencies**: Keep runtime dependencies minimal

### 2. Upstream Research

For each new tool, validate:

```bash
# Example: GitHub releases
curl -s https://api.github.com/repos/{owner}/{repo}/releases/latest | jq '.tag_name, .assets[].name'

# Example: PyPI
curl -s https://pypi.org/pypi/{package-name}/json | jq '.info.version, .releases | keys'
```

Key questions:

- What naming convention does upstream use for multi-architecture releases?
- How do I extract the version number (is there a leading 'v')?
- Are there any non-standard target triples (e.g., musl vs gnu)?

### 3. Template Selection

Identify which existing tool is most similar:

| Upstream Pattern | Use as Template | Reason |
|------------------|-----------------|--------|
| GitHub release tarball (x86_64-unknown-linux-gnu) | `tools/crane/` | Clean binary extraction pattern |
| Rust cargo-dist releases | `tools/goose/` or `tools/rustfs/` | Native Rust triple handling |
| Python PyPI package with CLI | `tools/httpie/` or `tools/mcp-cli/` | Shiv packaging pattern |
| Go from source | `tools/cobra-cli/` | go build pattern |

### 4. Define Decisions Up Front

Make explicit choices:

- **Artifact flavor**: GNU vs MUSL libc for C tools
- **Version extraction**: How to parse the release tag (e.g., `^v(?<version>.+)$`)
- **Platform coverage**: amd64 only, or also arm64?
- **Binary naming**: Does binary name differ from tool name?

## Implementation Checklist

### Phase 1: Manifest Creation

- [ ] Create `tools/{name}/` directory
- [ ] Write `manifest.yaml` with all required fields
- [ ] Set `renovate.datasource` to appropriate source (github-releases, pypi, etc.)
- [ ] Set `renovate.package` to upstream identifier
- [ ] Verify version regex in `renovate.extractVersion`
- [ ] Add appropriate tags for discoverability

**Example manifest.yaml structure:**

```yaml
# yaml-language-server: $schema=https://tools.uniget.dev/schema.yaml
name: {toolname}
version: "{version}"
binary: {binary-name}  # Only if different from tool name
check: ${binary} --version  # Command to verify installation
platforms: [linux/amd64, linux/arm64]
tags: [category/{category}, lang/{language}, type/cli]
homepage: https://github.com/{owner}/{repo}
repository: https://github.com/{owner}/{repo}
description: Brief tool description
renovate:
  datasource: github-releases  # or: pypi, gitlab-releases, etc.
  package: {owner}/{repo}      # or: {package-name} for PyPI
  extractVersion: ^v(?<version>.+)$
  priority: high
license:
  name: {License Type}
  link: https://github.com/{owner}/{repo}/blob/main/LICENSE
```

### Phase 2: Dockerfile Template Creation

- [ ] Copy standard header from existing tool
- [ ] Choose installation pattern (GitHub release binary, Python CLI, Go build, etc.)
- [ ] Implement architecture variable mapping for target platform names
- [ ] Add cache mounts for downloads and dependencies
- [ ] Implement fail-fast validation (check-github-release-asset, etc.)
- [ ] Test extraction command (tar, unzip, etc.) against actual artifacts

**Validation checks:**

```bash
# Verify release artifacts exist (example for Rust binary with target triples)
for t in x86_64-unknown-linux-musl aarch64-unknown-linux-musl; do
  url="https://github.com/{owner}/{repo}/releases/download/v{version}/{binary-name}-${t}.tar.gz"
  curl -fsSL "${url}" -o /tmp/{binary-name}-${t}.tar.gz
  tar -tzf /tmp/{binary-name}-${t}.tar.gz | head -n 5
done
```

## Installation Patterns by Language

The Dockerfile.template provides examples for multiple installation methods. Choose the pattern that matches your tool's distribution format.

### GitHub Releases - Binary Tarball

For tools distributed as pre-built tarballs with architecture-specific names:

```dockerfile
RUN --mount=type=cache,target=/var/cache/uniget/download <<EOF
url="https://github.com/{owner}/{repo}/releases/download/v${version}/{binary-name}-${arch}-unknown-linux-gnu.tar.gz"
filename="$( basename "${url}" )"

check-github-release-asset "{owner}/{repo}" "v${version}" "${filename}"
curl --silent --show-error --location --fail --output "${uniget_cache_download}/${filename}" "${url}"

tar --file="${uniget_cache_download}/${filename}" --extract --gzip --directory="${prefix}/bin" --no-same-owner
EOF
```

**Best for:** Rust, compiled Go binaries, and other statically-linked tools

### Go from Source

For Go projects distributed as source code:

```dockerfile
COPY --link --from=go / /usr/local/
COPY --link --from=make / /usr/local/
WORKDIR /go/src/github.com/{owner}/{repo}
RUN --mount=type=cache,target=/root/go/pkg/mod <<EOF
check-clone "https://github.com/{owner}/{repo}" "v${version}"
git clone -q --config advice.detachedHead=false --depth 1 --branch "v${version}" https://github.com/{owner}/{repo} .
make
cp {binary-name} "${prefix}/bin/"
EOF
```

**Best for:** Go CLI tools (gh, kind, cobra-cli, etc.)

### Rust from Source

For Rust projects with cargo:

```dockerfile
COPY --link --from=rust / /usr/local/
WORKDIR /tmp/github.com/{owner}/{repo}
RUN <<EOF
git clone -q --config advice.detachedHead=false --depth 1 --branch "${version}" https://github.com/{owner}/{repo} .
export CARGO_HOME=/usr/local/cargo
export RUSTUP_HOME=/usr/local/rustup
export RUSTFLAGS='-C target-feature=+crt-static'
cargo build --release --target "${arch}-unknown-linux-gnu"
cp "target/${arch}-unknown-linux-gnu/release/{binary-name}" "${prefix}/bin/"
EOF
```

**Best for:** Rust CLI tools with cargo-dist releases

### Python with Shiv

For Python packages with console scripts (single-file distribution):

```dockerfile
COPY --link --from=python / /usr/local/
COPY --link --from=shiv / /usr/local/
RUN --mount=type=cache,target=/root/.cache/pip <<EOF
shiv --output-file "${prefix}/bin/{binary-name}" --console-script {binary-name} "{package-name}==${version}"
EOF
```

**Best for:** Python CLI tools with simple dependencies (httpie, mcp-cli, opensandbox-cli)

### Python with Pipx

For Python packages requiring virtual environment isolation:

```dockerfile
COPY --link --from=python / /usr/local/
COPY --link --from=pipx / /usr/local/
RUN --mount=type=cache,target=/root/.cache/pip <<EOF
export PIPX_HOME="${prefix}/libexec/pipx"
export PIPX_BIN_DIR="${prefix}/bin"
pipx install {package-name}
pipx-fix-venv-pyvenv-cfg {package-name}
ln --symbolic --relative --force "${prefix}/libexec/pipx/venvs/{package-name}/bin/{binary-name}" "${prefix}/bin/{binary-name}"
sed -i "s|#\!${prefix}/|#\!/|" "${prefix}/libexec/pipx/venvs/{package-name}/bin/{binary-name}"
EOF
```

**Best for:** Python tools with complex dependency trees

### Node.js with npm

For JavaScript/Node.js tools:

```dockerfile
COPY --link --from=node / /usr/local/
COPY --link --from=npm / /usr/local/
WORKDIR ${prefix}/libexec/{name}
RUN <<EOF
npm install \
    --omit=dev \
    "{package-name}@${version}"
ln --symbolic --relative --force "${prefix}/libexec/{name}/node_modules/.bin/{binary-name}" "${prefix}/bin/"
EOF
```

**Best for:** Node.js/TypeScript CLI tools

### C/Make Build

For C/C++ projects with configure/make:

```dockerfile
COPY --link --from=make / /usr/local/
WORKDIR /tmp/{name}
RUN <<EOF
git clone -q --config advice.detachedHead=false --depth 1 --branch "${version}" https://github.com/{owner}/{repo} .
./configure --prefix="${prefix}"
make LDFLAGS=-static
make install
EOF
```

**Best for:** C/C++ tools with autotools or make build systems

### Architecture Variable Mapping

When implementing binary downloads, map architecture variables correctly:

| Variable | x86_64 | ARM64 |
|----------|--------|-------|
| `${arch}` | `x86_64` | `aarch64` |
| `${alt_arch}` | `amd64` | `arm64` |
| Rust target | `x86_64-unknown-linux-gnu` | `aarch64-unknown-linux-gnu` |
| Go runtime | `linux/amd64` | `linux/arm64` |

Use explicit case statements for conditional logic:

```dockerfile
case "${arch}" in
    x86_64)
        export target_triple="x86_64-unknown-linux-musl"
        ;;
    aarch64)
        export target_triple="aarch64-unknown-linux-musl"
        ;;
    *)
        echo "ERROR: Unsupported architecture ${arch}."
        exit 1
        ;;
esac
```

### Phase 3: Generate Artifacts

- [ ] Run Make to generate manifest.json, manifest-minimal.json, Dockerfile
- [ ] Fix environment-specific issues in generated Dockerfile (remove cert injection)
- [ ] Verify no schema validation errors

```bash
cd /path/to/tools
make tools/{name}/manifest.json tools/{name}/manifest-minimal.json tools/{name}/Dockerfile
```

### Phase 4: Validation

- [ ] Check generated files have no errors
- [ ] Optionally build for single architecture to test:

```bash
make {name}--build-amd64
```

### Phase 5: Testing (Optional)

For confidence in production builds:

```bash
# Test the binary extraction inside container
docker run --rm -it ghcr.io/uniget-org/tools/{name}:{version}-linux-amd64 \
  {binary} --version
```

## Known Issues & Solutions

### Issue 1: Version extraction regex not matching

**Problem:** Renovate datasource cannot parse upstream version tags.

**Solution:** Test regex locally:

```bash
# For github-releases, test against actual tags
curl -s https://api.github.com/repos/{owner}/{repo}/releases | jq -r '.[].tag_name' | head -5

# Then validate your regex
echo "your-tag-example" | grep -oE '^v?(?<version>.+)$'  # Won't work with named groups in grep
# Use Python for named groups:
echo "v1.0.0" | python3 -c "import sys, re; m=re.match(r'^v(?P<version>.+)$', sys.stdin.read().strip()); print(m.group('version') if m else 'NO MATCH')"
```

### Issue 2: Binary name differs from tool name

**Problem:** The installed binary has a different name than the tool directory.

**Solution:** Set `binary` field in manifest and use in `check` command:

```yaml
name: {toolname}
binary: {binary-name}
check: ${binary} --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
```

## Multi-Tool Batch Workflow

When adding multiple related tools:

1. **Research all tools first** — understand their patterns and dependencies
2. **Create manifests in parallel** — each tool's manifest is independent
3. **Write Dockerfile templates in parallel** — use same patterns for similar tools
4. **Generate artifacts in series** — Make may have ordering dependencies
5. **Validate all together** — catch cross-tool schema issues early

## Tracking Decisions

For each new tool, record:

- [ ] **Source URL**: Where upstream releases are hosted
- [ ] **Latest version**: Pin version number and link to release
- [ ] **Platform support**: Which architectures are supported
- [ ] **Artifact naming**: Exact filename patterns for each architecture
- [ ] **Installation method**: Binary tarball, PyPI package, etc.
- [ ] **Dependencies**: What other uniget tools are required at build/runtime
- [ ] **Version command**: How to verify the tool is installed correctly

Example decision record template:

```yaml
Tool: {name}
Source: {upstream-release-url}
Version: {version} (latest as of {date})
Platforms: linux/amd64, linux/arm64
Artifacts: {filename-pattern}
Method: {installation-method}
Check: {version-check-command}
Dependencies: {list-of-dependencies}
```

## Future Improvements

Considerations for scaling tool additions:

1. **Templating system**: Generate manifest.yaml + Dockerfile.template from a wizard
2. **Pre-flight checks**: Validate upstream artifacts exist before committing
3. **Batch validation**: Run schema checks across all tools
4. **CI/CD integration**: Automatically test new tools in PR before merge
5. **Dependency tracking**: Build a graph of tool dependencies for impact analysis

## References

- Uniget schema: https://tools.uniget.dev/schema.yaml