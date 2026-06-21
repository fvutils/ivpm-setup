# Setup IVPM (`ivpm-setup`)

A GitHub Action that installs [IVPM](https://github.com/fvutils/ivpm), restores
its content-addressed dependency cache, and runs `ivpm update` — collapsing the
usual CI boilerplate into one cache-aware step.

```yaml
- uses: actions/checkout@v4
- uses: fvutils/ivpm-setup@v1
  with:
    dep-set: ci
# deps are now populated in ./packages, and the cache is warm
```

Instead of this (no caching — re-clones/re-downloads every run):

```yaml
- run: python -m pip install ivpm
- run: ivpm update
```

## What it does

1. **Installs IVPM** (pinned if you want), using `uv` when available, else `pip`.
2. **Restores** IVPM's content-addressed cache (and optionally the pip/uv
   download caches), keyed on your dependency manifest.
3. **Runs** `ivpm update` to populate `./packages` (unless `run-update: false`).
4. **Saves** the cache inline after the update.

IVPM's cache is content-addressed by commit/version, so restoring a stale cache
is always safe — only changed deps are re-fetched.

## Quickstart

```yaml
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: fvutils/ivpm-setup@v1
      - run: ./packages/python/bin/python -m pytest
```

## Common inputs

| Input | Default | Description |
|---|---|---|
| `version` | latest | IVPM version spec to install (pin for reproducibility). |
| `python-version` | — | If set, runs `actions/setup-python` first. |
| `installer` | `auto` | `auto` (uv if available, else pip), `pip`, or `uv`. |
| `dep-set` | — | Dependency set(s); repeated `-d`. Newline/comma/space separated. |
| `run-update` | `true` | `false` for setup-only mode. |
| `token` | `${{ github.token }}` | Token for private deps / API limits. |

See the [full documentation](https://fvutils.github.io/ivpm-setup/) for **all**
inputs, outputs, caching details, and authentication.

## Outputs

| Output | Description |
|---|---|
| `cache-hit` | `true` if the primary cache key matched exactly. |
| `ivpm-version` | Resolved installed IVPM version. |
| `cache-dir` | Absolute path used as `IVPM_CACHE`. |

## Documentation

Full docs: <https://fvutils.github.io/ivpm-setup/>

## License

See [LICENSE](LICENSE).
