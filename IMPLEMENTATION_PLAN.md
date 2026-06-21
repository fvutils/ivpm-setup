# `ivpm-setup` — Implementation, Test & Documentation Plan

**Status:** Scaffold complete — pending first CI run
**Date:** 2026-06-21
**Companion design:** `../ivpm/github-action-design.md` (the design of record)

## Progress at a glance

The full repository is scaffolded and **locally validated** (shellcheck clean,
actionlint clean, Sphinx builds warning-free):

- ✅ **Action** — `action.yml` (composite) + `scripts/{install-ivpm,configure,run-update}.sh`
  (I1–I5 implemented).
- ✅ **Static CI** — `.github/workflows/ci.yml` (actionlint + shellcheck +
  action.yml validation) (T1).
- ✅ **Integration tests** — `.github/workflows/test.yml` + `test/fixtures/*` +
  `test/assert-minimal.sh` (T2–T3).
- ✅ **Docs** — Sphinx (`docs/`, 8 pages, rtd theme) + `docs.yml` direct Pages
  deploy (D1–D3).
- ✅ **Release** — `README.md`, `CHANGELOG.md`, `release.yml` (R1–R2).

**Remaining before public v1:**

1. **Push & green-light CI** — `test.yml`/`docs.yml` only run on GitHub; first
   push validates the cache lifecycle + installer matrix behaviorally.
2. **Pin third-party actions to SHAs** — every `uses:` currently carries a
   `# TODO: pin to full SHA before v1` marker.
3. **Enable Pages** — repo Settings → Pages → Source = "GitHub Actions" (one-time).
4. **Deferred test coverage** — stale/prefix-restore, pinned-version, private-dep,
   macOS (see §3.2).
5. **Tag `v1.0.0` + publish to Marketplace** (R3, manual UI step).

This plan turns the `github-action-design.md` design into a concrete, sequenced
build-out of the `fvutils/ivpm-setup` GitHub Action repository. It covers three
tracks — **implementation**, **testing**, and **documentation** — plus the CI
and GitHub Pages deployment that ties them together.

Scope reminder: this action performs **one** operation for consumers — install
IVPM, restore/save its content-addressed cache, and run `ivpm update`. We ship a
**composite action** for v1 (per design §4–§5). A JS rewrite is explicitly out of
scope for v1.

---

## 1. Target repository layout

```
ivpm-setup/
├── action.yml                      # the composite action (repo-root → usable as fvutils/ivpm-setup@v1)
├── README.md                       # Marketplace landing page + quickstart
├── LICENSE                         # (present)
├── CHANGELOG.md                    # keep-a-changelog format; drives release notes
├── .gitignore                      # (present)
├── scripts/                        # extracted shell logic, kept out of action.yml for testability
│   ├── install-ivpm.sh
│   ├── configure.sh                # compute cache dir/key, export env, wire git auth
│   └── run-update.sh               # assemble + exec `ivpm update` args safely
├── test/
│   ├── assert-minimal.sh           # workspace assertions for the minimal fixture
│   ├── fixtures/
│   │   ├── minimal/                # 2 pypi deps + 1 git dep (six)
│   │   │   └── ivpm.yaml
│   │   └── multi-depset/           # exercises -d / multiple dep-sets
│   │       └── ivpm.yaml
│   └── bats/                       # (future) bats-core unit tests for scripts/*.sh
├── docs/
│   ├── Makefile
│   ├── requirements.txt            # sphinx + sphinx_rtd_theme (+ myst-parser)
│   └── source/
│       ├── conf.py
│       ├── index.rst
│       ├── getting_started.rst
│       ├── inputs.rst
│       ├── outputs.rst
│       ├── caching.rst
│       ├── authentication.rst
│       ├── examples.rst
│       ├── troubleshooting.rst
│       ├── _static/
│       └── imgs/
└── .github/
    └── workflows/
        ├── ci.yml                  # actionlint + shellcheck + (optional) bats
        ├── test.yml                # integration: self-test the action across a matrix
        ├── docs.yml                # build Sphinx → deploy to GitHub Pages
        └── release.yml             # move the `v1` tag on version-tag push
```

Rationale for `scripts/`: keeping non-trivial shell out of `action.yml` lets us
**shellcheck** and **bats-test** it directly, and sidesteps the YAML-interpolation
injection surface flagged in design §8 (scripts read inputs from `env:`, never
from `${{ }}` interpolation).

---

## 2. Implementation plan

### 2.1 `action.yml` (composite)

Follow the step flow from design §4.1, but with every input passed through
`env:` and consumed as `"$VAR"` inside `scripts/*.sh` — no `${{ inputs.* }}`
inside any `run:` body.

Steps:

1. **Setup Python** — `actions/setup-python` *only if* `python-version != ''`.
2. **Install IVPM** — `scripts/install-ivpm.sh` (installer resolved per §2.3;
   honor `version` spec; emit resolved `version` to `$GITHUB_OUTPUT`).
   ⚠️ **Version probe:** IVPM's CLI has **no `--version` flag** (its subcommand is
   required), so the resolved version comes from
   `python -c 'import importlib.metadata as m; print(m.version("ivpm"))'`, **not**
   `ivpm --version`. (Corrects design §3.2.)
3. **Configure** — `scripts/configure.sh`:
   - resolve `cache-dir` (default `${RUNNER_TEMP}/ivpm-cache`), `mkdir -p`;
   - export `IVPM_CACHE` to `$GITHUB_ENV`;
   - if a token is present, export `IVPM_GIT_AUTH_ORDER=gh,https` and run
     `gh auth setup-git`;
   - emit `cache-dir` to `$GITHUB_OUTPUT`. (The cache *key* is **not** computed
     here — `hashFiles()` only works in workflow-expression context, so the key
     lives in `action.yml`'s restore step.)
4. **Restore cache** — `actions/cache/restore@<sha>` (guarded by `cache`), with
   the key/restore-keys strategy from design §4.2 and pip/uv cache paths added
   when `cache-python == 'true'`.
5. **ivpm update** — `scripts/run-update.sh` (guarded by `run-update`); builds
   the argv array (`-p`, repeated `-d`, `-j`, raw `args`) and execs `ivpm`.
6. **Save cache** — `actions/cache/save@<sha>` (guarded by `cache` AND
   `cache-hit != 'true'`), keyed on `steps.restore.outputs.cache-primary-key`.

Inputs/outputs are exactly the tables in design §3.1/§3.2. Keep the `name:`
field as **`Setup IVPM`** (human-readable Marketplace title) — distinct from the
repo slug `ivpm-setup`.

### 2.2 Input → env mapping (injection hardening)

In `action.yml`, each script step declares an `env:` block mapping inputs to
named vars, e.g.:

```yaml
- name: Run update
  if: inputs.run-update == 'true'
  shell: bash
  env:
    IVPM_DEP_SET:     ${{ inputs.dep-set }}
    IVPM_PROJECT_DIR: ${{ inputs.project-dir }}
    IVPM_JOBS:        ${{ inputs.jobs }}
    IVPM_EXTRA_ARGS:  ${{ inputs.args }}
    GH_TOKEN:         ${{ inputs.token }}
    GITHUB_TOKEN:     ${{ inputs.token }}
  run: ${{ github.action_path }}/scripts/run-update.sh
```

`run-update.sh` then reads `$IVPM_DEP_SET` etc. with proper quoting. `dep-set`
is split on whitespace/commas into repeated `-d` flags; `args` is the documented
escape hatch (word-split, caller's responsibility).

### 2.3 Installer resolution (`installer: auto` default)

`install-ivpm.sh` resolves the installer as follows:

- `auto` (default): if `command -v uv` succeeds, use `uv pip install --system`;
  otherwise use `python -m pip install`. Log which was chosen.
- `uv`: force uv — `python -m pip install uv` (if absent) then `uv pip install
  --system`. Errors loudly if uv can't be obtained.
- `pip`: force `python -m pip install`.

Rationale: GitHub-hosted runners increasingly ship `uv`, so `auto` gives the
faster path with zero config while staying correct on runners without it. The
chosen installer is surfaced in the step log (and feeds the `cache-python` paths
— `~/.cache/uv` vs `~/.cache/pip`). Note the `installer` default in design §3.1
changes from `pip` to **`auto`**.

### 2.4 Pinning

Pin all third-party actions (`actions/setup-python`, `actions/cache`,
`actions/checkout` in test workflows) to full commit SHAs with a version
comment, per design §8.

### 2.5 Implementation milestones

| # | Deliverable | Done-when | Status |
|---|---|---|---|
| I1 | `action.yml` + `scripts/` skeleton (install + configure + update) | `ivpm-setup` runs `ivpm update` against a fixture in a throwaway workflow | ✅ code written; shellcheck-clean, YAML valid — CI-verified via `test.yml` (T2) |
| I2 | Cache restore/save split wired in | second run on unchanged manifest → `cache-hit == true`, update near-instant | ✅ wired in `action.yml` — CI-verify pending (T2) |
| I3 | Git auth + private-dep path | private git dep clones using `github.token` | ✅ `configure.sh` — CI-verify pending (T4) |
| I4 | Installer resolution (`auto`/`uv`/`pip`) + `cache-python` | `auto` picks uv when present, pip otherwise; pip/uv download caches persist | ✅ `install-ivpm.sh` — CI-verify pending (T3) |
| I5 | Outputs (`cache-hit`, `ivpm-version`, `cache-dir`) finalized | consumed by a downstream step in `test.yml` | ✅ wired — `ivpm-version` via `importlib.metadata`; CI-verify pending (T2) |

> **All implementation milestones I1–I5 are implemented in one composite
> `action.yml` + three scripts.** They are locally validated (shellcheck clean,
> YAML parses); behavioral verification happens in CI via `test.yml`.

---

## 3. Test plan

Two layers: **static checks** (fast, every push) and **integration self-tests**
(the action exercising itself across a matrix).

### 3.1 Static checks — `.github/workflows/ci.yml`

- **actionlint** — validate `action.yml` and all workflow YAML.
- **shellcheck** — lint `scripts/*.sh` (these are real files, so this works).
- **bats-core** (optional) — unit-test pure logic in `configure.sh`
  (cache-key/cache-dir resolution, dep-set splitting) with `IVPM_*` env stubbed
  and `gh`/`ivpm` shimmed onto `PATH`.

### 3.2 Integration self-tests — `.github/workflows/test.yml`

The action lives in this repo, so reference it locally as `uses: ./`. Drive it
against `test/fixtures/*` and assert outcomes.

**Fixtures (implemented):**

- `minimal/` — 2 PyPI deps (`toposort`, `iniconfig`) + 1 git dep (`six`). Tiny,
  pure-Python, very stable. Exercises the pip/uv download cache *and* the
  IVPM_CACHE git-clone cache.
- `multi-depset/` — `default` + `ci` dep-sets for the `dep-set` input.
- ~~`locked/`~~ **dropped**: `package-lock.json` carries an internal checksum
  that IVPM verifies (`package_lock.py`), so a committed lock can't be
  hand-authored. The lock/stale-restore scenarios are deferred (see below).

All test jobs pass `python-version: "3.12"` (via `actions/setup-python`) to get a
clean, pip-installable interpreter and avoid PEP 668 "externally-managed"
failures on the runner's system Python.

**Scenario coverage (implemented in `test.yml`):**

| Scenario | Job | Assertion |
|---|---|---|
| **Cold cache** | `cold` | `cache-hit == 'false'`; `ivpm-version` set; workspace populated (`assert-minimal.sh`) |
| **Exact hit** | `warm` (`needs: cold`, fresh runner) | `cache-hit == 'true'`; workspace restored |
| **Installer** | `installer` (matrix `auto`/`pip`/`uv`) | install succeeds; workspace populated |
| **Setup-only** | `setup-only` | `ivpm` on PATH; `IVPM_CACHE` exported; `packages/` NOT populated; manual `ivpm update` then works |
| **Multiple dep-sets** | `multi-depset` | both `default` + `ci` deps importable from venv |
| **Outputs** | every job | downstream steps read `cache-hit`/`ivpm-version`/`cache-dir` |

**Deferred scenarios (post-scaffold):**

- **Stale/prefix restore** — bump a dep pin in-workflow and assert restore via
  `restore-keys` + only-delta refetch. (Needs a controlled pin change.)
- **Pinned version** — assert `ivpm-version` equals a pinned `version` input.
- **Private dep (auth)** — needs a private fixture repo + token; add once a
  test-org private repo exists.
- **macOS** — add `os: macos-latest` once Linux is green.

Assertion mechanics: `test/assert-minimal.sh <project-dir>` checks the git dep
clone, the venv python, and importability of the PyPI deps. Cross-runner cache
behavior is validated by `warm` `needs: cold` with a shared `cache-key-prefix`
made unique per run via `${{ github.run_id }}-${{ github.run_attempt }}` (so each
attempt is a genuine cold miss).

> **Note on cache isolation:** GitHub scopes caches per branch, so the
> cold→warm sequence runs within one workflow run (job ordering via `needs:`),
> not across PRs.

Flaky-network caveat: integration tests fetch real deps. Fixture deps are tiny
and stable to limit flakiness. (Mirrors the existing
[[flaky-network-integration-tests]] concern in the ivpm repo.)

### 3.3 Test milestones

| # | Deliverable | Done-when | Status |
|---|---|---|---|
| T1 | `ci.yml` (actionlint + shellcheck) | every push lints clean | ✅ written; locally actionlint+shellcheck clean |
| T2 | `test.yml` cold/exact-hit on `minimal` | both pass on `ubuntu-latest` | ✅ written; CI-run pending (needs push) |
| T3 | Installer matrix + multi-dep-set + setup-only | green | ✅ written; CI-run pending |
| T4 | Stale-restore, pinned-version, private-dep, macOS | green | ⏳ deferred (see above) |

---

## 4. Documentation plan (Sphinx)

Match the ivpm repo's doc tooling for consistency: **Sphinx** +
**`sphinx_rtd_theme`**, sources under `docs/source/`, `.rst` pages, `.nojekyll`
on the published output. We **omit** ivpm's Python-specific extensions
(`sphinx-jsonschema`, `sphinxarg.ext`) — there's no Python package or argparse
CLI to document here. Add **`myst-parser`** so the README can be reused if
helpful.

### 4.1 `docs/source/conf.py`

```python
project   = 'ivpm-setup'
copyright = '2026, Matthew Ballance'
author    = 'Matthew Ballance'
extensions = ['myst_parser']          # rst-first; markdown allowed
html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']
exclude_patterns = []
```

(No `sys.path` injection — unlike ivpm, this repo has no `src/` to import.)

### 4.2 `docs/requirements.txt`

```
sphinx
sphinx_rtd_theme
myst-parser
```

### 4.3 Page outline (`index.rst` toctree)

1. **introduction** — what the action does, the one-operation model, the CI
   wall-clock/caching motivation (condensed design §1).
2. **getting_started** — minimal workflow (checkout → `fvutils/ivpm-setup@v1` →
   run tests); prerequisites.
3. **inputs** — full table from design §3.1, one subsection per input with
   examples and defaults.
4. **outputs** — `cache-hit`, `ivpm-version`, `cache-dir` and how to consume them.
5. **caching** — key strategy (design §4.2), what is/isn't cached (design §6),
   the content-addressed → safe-partial-restore rationale, GitHub cache limits.
6. **authentication** — `token` input, `IVPM_GIT_AUTH_ORDER`, private cross-repo
   deps needing a PAT/App token with `contents:read` (design §8).
7. **examples** — minimal, pinned+matrix+uv, setup-only (design §9).
8. **troubleshooting** — cache misses, private-dep auth failures, uv vs pip,
   venv-not-cached expectations.

### 4.4 Single source of truth for the inputs table

The inputs/outputs tables exist in both `README.md` and `docs/inputs.rst`.
To avoid drift, keep `README.md` authoritative and link to the hosted docs for
detail; or generate both from `action.yml` with a small script run in `ci.yml`
that fails if they're out of sync. **Decision (default):** keep README concise
(quickstart + link), put the exhaustive reference only in Sphinx.

### 4.5 Doc milestones

| # | Deliverable | Done-when | Status |
|---|---|---|---|
| D1 | `docs/` scaffold builds locally | clean HTML, no warnings | ✅ built locally with `sphinx-build -W --keep-going`, zero warnings |
| D2 | All eight pages drafted | content complete, examples copy-paste runnable | ✅ all 8 pages written |
| D3 | README quickstart + Marketplace metadata | renders well on GitHub & Marketplace | ✅ README + `branding:` in `action.yml` |

---

## 5. CI & GitHub Pages deployment — `.github/workflows/docs.yml`

**Decided:** direct deploy via the **current GitHub Pages Actions flow** (OIDC
artifact upload — no `gh-pages` branch). We keep the *Sphinx + rtd-theme*
tooling identical to ivpm; only the publish mechanism is modernized (ivpm uses a
`gh-pages` branch via `JamesIves/github-pages-deploy-action`; we do not).

```yaml
name: Docs
on:
  push:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: pages
  cancel-in-progress: true
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha>
      - uses: actions/setup-python@<sha>
        with: { python-version: '3.x' }
      - run: pip install -r docs/requirements.txt
      - run: sphinx-build -M html docs/source docs/_build
      - run: touch docs/_build/html/.nojekyll
      - uses: actions/upload-pages-artifact@<sha>
        with: { path: docs/_build/html }
  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deploy.outputs.page_url }}
    steps:
      - id: deploy
        uses: actions/deploy-pages@<sha>
```

One-time manual step: in repo **Settings → Pages**, set **Source = GitHub
Actions**. Document this in `CONTRIBUTING.md`.

Result: docs publish to `https://fvutils.github.io/ivpm-setup/` on every push to
`main`.

---

## 6. Release & versioning — `.github/workflows/release.yml`

Per design §7: immutable `vX.Y.Z` tags plus a **moving `v1`** major tag that
consumers reference.

- On push of a `v*.*.*` tag: create a GitHub Release (`gh release create
  --generate-notes --verify-tag`; `CHANGELOG.md` is maintained alongside), then
  force-move the `v1` major tag to that commit.
- **Marketplace:** publish from a release via the GitHub "Publish this Action to
  the Marketplace" flow (requires the `name:`/`description:`/`branding:` fields
  in `action.yml` — add `branding: { icon: 'package', color: 'blue' }`).

Release milestones:

| # | Deliverable | Done-when | Status |
|---|---|---|---|
| R1 | `branding:` + Marketplace-ready `action.yml` metadata | passes Marketplace validation | ✅ `branding:` + `name`/`description`/`author` present |
| R2 | `release.yml` moves `v1` on tag | tagging `v1.0.0` updates `v1` | ✅ written; exercised on first real tag |
| R3 | v1.0.0 published to Marketplace | listed; `fvutils/ivpm-setup@v1` resolves | ⏳ manual UI step at first release |

---

## 7. Overall sequencing

```
I1 → I2 → (I3 ∥ I4) → I5          implementation
        ↘ T1 (early, parallel)
I2 done → T2 → T3 → T4            testing
D1 → D2 → D3                      docs (parallel with impl after I1)
docs.yml after D1                 pages live early, content fills in
R1 → R2 → R3                      release, last (gated on T3 + D2 green)
```

Critical path to a usable internal action: **I1→I2→T2**. Critical path to a
public v1: add **T3 + D2 + R1→R3**.

---

## 8. Decisions (resolved)

1. **Deploy mechanism** — ✅ **Decided:** direct deploy via `actions/deploy-pages`
   (OIDC artifact, no `gh-pages` branch). See §5.
2. **Default cache-key inputs** — ✅ **Decided:** hash `**/ivpm.yaml`,
   `**/*.ivpm.yaml` (multi-file manifests), and `**/package-lock.json` by
   default. The `*.ivpm.yaml` glob is added to `cache-dependency-path`'s default
   (design §10.3 resolved → yes).
3. **Installer** — ✅ **Decided:** default `installer: auto` — probe for `uv` on
   PATH and use it, else fall back to `pip`. Explicit `pip` / `uv` force a
   specific installer (and `uv` errors if not installable). See §2.5.
4. **Lock-verify post-step** — ✅ **Deferred to post-v1.** No `ivpm status`/lock
   assertion in v1 (design §10.5).
5. **README/inputs sync** — ✅ **Decided:** manual — README stays concise
   (quickstart + link to hosted docs); exhaustive reference lives only in Sphinx.

---

## 9. Pointers

- Design of record: `../ivpm/github-action-design.md`
- IVPM CLI surface used: `ivpm update -p <dir> [-d <set>]… [-j N] [--git-auth-order …]`
- Env contract: `IVPM_CACHE`, `IVPM_GIT_AUTH_ORDER` (verified in
  `ivpm/src/ivpm/site_config.py`, `cache.py`, `utils.py`)
- Doc tooling parity target: `ivpm/docs/source/conf.py`,
  `ivpm/.github/workflows/ci.yml` (Build/Publish Docs steps)
```

