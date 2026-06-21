# Blog Announcement — Outline & Titles (for review)

**Status:** Draft for review
**Date:** 2026-06-21
**Topic:** Announce the `fvutils/ivpm-setup` GitHub Action + remote-manifest
(`--from`) support, pitched as *simplifying setup and raising efficiency for
open-source silicon CI pipelines*.

---

## Title proposals

1. **"One Step to a Warm Toolchain: IVPM Comes to GitHub Actions"**
   — leads with the developer experience (one step) and the caching payoff.

2. **"Stop Re-Cloning Your EDA Tools on Every CI Run"**
   — pain-first, concrete; speaks directly to the open-source silicon CI
   audience that feels the re-download tax.

3. **"Curated EDA Toolchains, Cached and CI-Ready: Announcing `ivpm-setup`
   + Remote Catalogs"**
   — names both features and the EDAPack catalog angle; the "this is a
   platform, not just an action" framing.

*(Recommendation: #2 as the headline for reach, with #1 or #3 as the subtitle.)*

---

## Audience & framing

- **Who:** maintainers and contributors of open-source silicon / EDA projects
  (RTL, FPGA, ASIC, formal, RISC-V) who run CI on GitHub Actions.
- **The pain we name in the first paragraph:** every CI run re-installs IVPM,
  re-clones every git dep, re-downloads every tool release, and rebuilds the
  Python venv from scratch — slow wall-clock, hammered upstreams, GitHub API
  rate-limit failures.
- **The promise:** collapse all of that into one cache-aware step, and pull
  whole curated toolchains from a published catalog by name.
- **Tone:** practical, before/after, copy-pasteable YAML.

---

## Outline

### 1. Hook — the CI tax on silicon projects
- Open with a realistic "before" workflow: manual `pip install ivpm` +
  `ivpm update`, no caching.
- Quantify the pain narratively: re-clones, re-downloads, venv rebuilds every
  run; multiply by a PR matrix (OS × Python). Upstream hosts and API limits.
- Thesis: hardware/EDA dependencies are *big and slow* — caching isn't a
  nice-to-have here, it's the difference between a 30-second and a 10-minute job.

### 2. Announcing `fvutils/ivpm-setup`
- One-paragraph what-it-is: a composite GitHub Action that installs IVPM,
  restores its content-addressed dependency cache, and runs `ivpm update` —
  in a single step.
- The "after" snippet (the simpler description):
  ```yaml
  - uses: actions/checkout@v4
  - uses: fvutils/ivpm-setup@v1
    with:
      dep-set: ci
  # deps populated in ./packages, cache is warm
  ```
- Callout: side-by-side before/after to make the "simpler description" point
  visceral.

### 3. Automated caching, done right
*The efficiency pitch — two layers of caching, both automatic.*
- **EDA tool / dependency cache:** IVPM's content store (git clones, HTTP
  archives, GitHub Release tarballs) is persisted across runs via
  `actions/cache`, keyed on the dependency manifest(s) (`**/ivpm.yaml`,
  `**/*.ivpm.yaml`, lockfile).
- **Python package cache:** pip/uv download caches (`~/.cache/pip`,
  `~/.cache/uv`) are cached too, speeding the venv build.
- **Why it's safe to be aggressive:** the store is *content-addressed by
  commit/version*, so restoring a stale cache is always correct — IVPM
  re-fetches only the deltas. This makes prefix `restore-keys` fallback a
  correctness guarantee, not a gamble. (One short paragraph; link design doc
  for depth.)
- **Inline save, not a flaky post-step:** brief note that the composite action
  saves the cache inline right after update (sidesteps the nested-composite
  post-step problem) — credibility detail for the CI-savvy reader.
- Outcome line: warm runs go from full re-fetch to near-instant; only changed
  deps move.

### 4. Beyond one project: remote catalogs with `--from`
*The second feature — referencing remote `ivpm.yaml` files.*
- The shift: you no longer have to hand-maintain a dependency list per project.
  Point IVPM at a *published catalog manifest* and pull what you need by name.
- `ivpm update --from <url> -d <dep-set>` — install straight from a remote
  manifest into the current directory, no local `ivpm.yaml` required.
- `ivpm show deps --from <url>` — browse the catalog (descriptions + dep-sets)
  before committing to an install. Introduce the new `description` field that
  makes catalogs self-documenting.
- Two consumption modes, both worth showing:
  1. **Standalone** — `update --from … -d …` directly in a CI step.
  2. **Referenced from your own `ivpm.yaml`** — a `src: ivpm.yaml` dep that
     pulls a named dep-set/collection from the catalog into your project.
- Reassure on the persistence model: the manifest is *not* copied locally; the
  lock file records `source_manifest` so the workspace stays self-describing
  with a single source of truth. (One sentence — depth in design doc.)

### 5. Predefined packages and collections — the EDAPack catalog
*Make the abstract concrete with a real, live catalog.*
- Introduce EDAPack: portable, prebuilt binary packages of open-source EDA
  tools (Verilator, Yosys, OpenROAD, OpenSTA, nextpnr, IceStorm, Icarus,
  ngspice, the RISC-V toolchain, QEMU, GDB…), published at
  `https://edapack.github.io/ivpm.yaml`.
- **Individual packages:** one dep-set per tool — `-d verilator`, `-d yosys`.
- **Curated collections:** multi-tool bundles named by workflow category, e.g.
  - `sim.rtl` — Verilator + Icarus Verilog
  - `flow.fpga.ice40` — Yosys + nextpnr + IceStorm
  - `flow.asic` — Yosys + OpenROAD + OpenSTA
  - `embedded.riscv` — gcc-riscv + gdb-multiarch + qemu-riscv
- The payoff: a contributor gets a *complete, version-consistent ASIC flow*
  with `-d flow.asic` — no per-tool install scripts, no apt pinning, automatic
  platform-asset selection, and `bin/` auto-added to `PATH`.

### 6. Putting it together — a complete CI example
- A full, copy-pasteable workflow that combines all three ideas: `ivpm-setup`
  for the action + caching, pulling an EDAPack collection (via `--from` or a
  referenced catalog dep), and running the project's tests/flow.
  ```yaml
  name: CI
  on: [push, pull_request]
  jobs:
    sim:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - uses: fvutils/ivpm-setup@v1   # installs ivpm, warms the cache
        - run: ivpm update --from https://edapack.github.io/ivpm.yaml -d sim.rtl
        - run: ./packages/python/bin/python -m pytest
  ```
- Mention the matrix/pinning knobs briefly (`version`, `python-version`,
  `installer: uv`, `cache-key-prefix`) and point to full docs.

### 7. Why this matters for open-source silicon
*Tie the bow on the thesis.*
- Lower barrier to contribution: a green CI run on a fork without a
  hand-rolled toolchain setup.
- Faster, cheaper, more reliable pipelines: less wall-clock, fewer rate-limit
  flakes, kinder to upstream hosts.
- A shared, curated, versioned source of EDA tools the whole ecosystem can
  point at — instead of every project reinventing tool install.

### 8. Get started / call to action
- Links: `ivpm-setup` repo + Marketplace listing, IVPM docs (the `--from`
  / remote-catalog section), EDAPack catalog & docs.
- Invite contributions to the EDAPack catalog (add a tool, add a collection).
- Versioning note: `@v1` moving tag; pin a full SHA for supply-chain-strict
  setups.

---

## Supporting assets to prepare
- Before/after YAML graphic for §2.
- A timing chart (cold vs. warm run) for §3 — even illustrative numbers help.
- EDAPack collections table (reuse from the EDAPack site) for §5.
- Links to: `ivpm-setup` design doc, remote-manifest design doc, EDAPack docs.

## Open questions for review
- Do we have real cold-vs-warm timing numbers to cite in §3, or keep it
  qualitative for the announcement?
- Is `ivpm-setup@v1` tagged/published to the Marketplace at post time? (CTA in
  §8 depends on it.)
- Lead title — go with the pain-first #2, or the feature-complete #3?
- Scope: one combined post, or split into "the action" now and "remote
  catalogs + EDAPack" as a follow-up?
