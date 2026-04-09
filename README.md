# Membrane Actions

GitHub Actions reusable workflows and composite actions for [Membrane Framework](https://membraneframework.org) Elixir projects. This is the GitHub Actions equivalent of the [`membraneframework/circleci-orb`](https://github.com/membraneframework/circleci-orb).

## Overview

| Component | Type | Description |
|---|---|---|
| `elixir-executor-setup` | Composite action | Installs hex and rebar |
| `get-mix-deps` | Composite action | Fetches mix deps with caching |
| `use-build-cache` | Composite action | Restores `_build/` cache |
| `run-dialyzer` | Composite action | Runs Dialyzer with PLT caching |
| `build-test` | Reusable workflow | Compiles project and checks for unused deps |
| `test` | Reusable workflow | Runs `mix test` |
| `lint` | Reusable workflow | Format, Credo, docs, Dialyzer |
| `hex-publish` | Reusable workflow | Publishes to hex.pm |
| `precompile-linux-x86` | Reusable workflow | Precompiles native lib for Linux x86 |
| `precompile-linux-arm` | Reusable workflow | Precompiles native lib for Linux ARM |
| `precompile-macos-arm` | Reusable workflow | Precompiles native lib for macOS ARM |
| `precompile-macos-intel` | Reusable workflow | Deprecated no-op |
| `publish-precompiled` | Reusable workflow | Publishes precompiled artifacts to GitHub Releases |

## Usage

### Basic CI (build, test, lint)

```yaml
# .github/workflows/ci.yml in your repo
name: CI

on:
  push:
    branches: [master]
  pull_request:

jobs:
  build_test:
    uses: membraneframework/membrane_actions/.github/workflows/build-test.yml@main

  test:
    uses: membraneframework/membrane_actions/.github/workflows/test.yml@main

  lint:
    uses: membraneframework/membrane_actions/.github/workflows/lint.yml@main
```

### Customizing inputs

```yaml
jobs:
  lint:
    uses: membraneframework/membrane_actions/.github/workflows/lint.yml@main
    with:
      dialyzer: false                  # disable Dialyzer
      docs: false                      # disable docs check
      cache-version: 2                 # bust all caches
      container-image: elixir:1.18    # use plain elixir image instead of docker_membrane
```

### Publishing to hex.pm

```yaml
jobs:
  hex_publish:
    uses: membraneframework/membrane_actions/.github/workflows/hex-publish.yml@main
    secrets:
      HEX_API_KEY: ${{ secrets.HEX_API_KEY }}
    # Or pass all secrets automatically:
    # secrets: inherit
```

### Precompiling native libraries and publishing a GitHub Release

Artifact sharing requires all precompile + publish jobs to be in **one coordinator workflow** (same workflow run). The publish job downloads all artifacts uploaded by the precompile jobs.

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'

jobs:
  precompile_linux_x86:
    uses: membraneframework/membrane_actions/.github/workflows/precompile-linux-x86.yml@main
    with:
      package-name: my_package
      expected-version: ${{ github.ref_name }}

  precompile_linux_arm:
    uses: membraneframework/membrane_actions/.github/workflows/precompile-linux-arm.yml@main
    with:
      package-name: my_package
      expected-version: ${{ github.ref_name }}

  precompile_macos_arm:
    uses: membraneframework/membrane_actions/.github/workflows/precompile-macos-arm.yml@main
    with:
      package-name: my_package
      expected-version: ${{ github.ref_name }}

  publish:
    needs: [precompile_linux_x86, precompile_linux_arm, precompile_macos_arm]
    uses: membraneframework/membrane_actions/.github/workflows/publish-precompiled.yml@main
    with:
      version: ${{ github.ref_name }}
    secrets: inherit
```

## Inputs Reference

### Common inputs (build-test, test, lint, hex-publish)

| Input | Type | Default | Description |
|---|---|---|---|
| `cache-version` | number | `1` | Increment to bust all caches |
| `container-image` | string | `membraneframeworklabs/docker_membrane:latest` | Full Docker image reference |

### lint workflow additional inputs

| Input | Type | Default | Description |
|---|---|---|---|
| `credo` | boolean | `true` | Run `mix credo` |
| `docs` | boolean | `true` | Check docs generate without warnings |
| `dialyzer` | boolean | `true` | Run `mix dialyzer` |

### Precompile workflow inputs

| Input | Type | Default | Description |
|---|---|---|---|
| `package-name` | string | required | Homebrew package name |
| `expected-version` | string | `'no check'` | Expected version tag, or `'no check'` to skip |

### publish-precompiled inputs

| Input | Type | Default | Description |
|---|---|---|---|
| `version` | string | required | GitHub release tag (e.g. `v1.2.3`) |

## Container Images

Pass any Docker image via `container-image`. Common choices:

| Image | When to use |
|---|---|
| `membraneframeworklabs/docker_membrane:latest` (default) | Projects using native Membrane multimedia libs |
| `membraneframeworklabs/docker_membrane:1.2.3` | Pin to a specific version |
| `elixir:1.18` | Pure Elixir projects without native deps |
| `elixir:latest` | Always the latest Elixir release |

## Secrets

| Secret | Used by | Description |
|---|---|---|
| `HEX_API_KEY` | `hex-publish` | hex.pm API key for publishing packages |
| `GITHUB_TOKEN` | `publish-precompiled` | Automatically provided by GitHub Actions |

## Cache Versioning

Each workflow uses caches keyed by `cache-version`. To invalidate all caches (e.g. after adding a native dependency), increment `cache-version`:

```yaml
with:
  cache-version: 2
```

## Notes

- **`use-build-cache` save pattern**: The composite action only *restores* the build cache. Workflows that need to *save* the build cache call `actions/cache/save@v4` explicitly after compilation, using the `cache-key` output from the action. This is why you may see separate save steps in the workflow files.

- **Artifact sharing**: Precompile and publish jobs must run in the same workflow (same `workflow_run`) so they share the artifact store. Calling them from separate workflow files will not work.

- **`runner.arch` vs CircleCI `arch`**: Build cache keys use `runner.arch` (`X64`, `ARM64`) rather than CircleCI's `amd64`/`arm64`. These caches are not interchangeable.
