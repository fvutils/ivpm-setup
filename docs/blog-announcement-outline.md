# Blog Announcement — Outline & Titles (for review)

**Status:** Draft for review
**Date:** 2026-06-21
**Topic:** Announce the `fvutils/ivpm-setup` GitHub Action + remote-manifest
(`--from`) support, pitched as *simplifying setup and raising efficiency for
open-source silicon CI pipelines*.

---

## Title proposals

1. **"Stop Copy-Pasting CI Boilerplate Into Every Silicon Project"**
   — leads with the core thesis: the install + cache wiring you'd hand-roll in
   every workflow, pulled into one step.

2. **"`ivpm-setup`: One Step Instead of Your Whole CI Setup Block"**
   — concrete and DX-first; names the action and the before/after collapse.

3. **"From `pip install` to a Warm, Cached Toolchain in One Action"**
   — spells out exactly what the action folds together (no venv/pip step,
   automatic caching).

*(Recommendation: #1 for the thesis; #2 as a plainer alternative if we want the
action name in the headline.)*

---

## Audience & framing

- **Who:** maintainers and contributors of open-source silicon / EDA projects
  (RTL, FPGA, ASIC, formal, RISC-V) who run CI on GitHub Actions.
- **The core thesis (state it plainly, early):** IVPM already does the heavy
  lifting — declaring deps, fetching tools, building the venv, managing a
  content-addressed cache. What's left over in a CI run is *glue*: install
  IVPM into the runner (the pip/venv step) and wire up `actions/cache` so the
  store and Python downloads survive between runs. Both are doable by hand in a
  workflow — but you'd copy that same setup block into every project, and keep
  it in sync forever. **`ivpm-setup` is that glue, pulled into one step you
  reference instead of duplicate.**
- **What the action does — one step, three jobs:**
  1. **Setup** — installs IVPM for you (uv-or-pip), so there's no `pip install`
     / venv-bootstrap step in your workflow.
  2. **Caching** — wires `actions/cache` around IVPM's content store *and* the
     pip/uv download caches, keyed on your manifest, with safe stale-restore.
  3. **Runs `ivpm update`** — drives the actual dependency resolution/fetch from
     your manifest, so the workspace is populated and ready. (Update itself is
     IVPM; the action just invokes it, so CI is *only* the action — no separate
     `ivpm update` line.) Can be turned off with `run-update: false` for
     setup-only mode.
- **What it is *not*:** new dependency-resolution capability. The action is a
  thin, well-tested orchestration layer over things IVPM already supports —
  the value is *not duplicating that wiring everywhere*.
- **The remote-catalog feature (`--from` + EDAPack)** is IVPM capability, not
  the action — framed as a complementary "and here's how setup gets even
  simpler" beat, not a co-headline.
- **Tone:** practical, before/after, copy-pasteable YAML.

---

## Outline

### 1. Hook — IVPM already drives your build; CI just makes you repeat yourself
- Start from a position of strength: if you use IVPM, your project already
  *declares* its tools and deps in one manifest, and `ivpm update` already
  fetches them and builds the venv. Locally, setup is already one command.
- The "but" — in CI you end up writing the same supporting block in every
  repo's workflow:
  - a `pip install ivpm` / venv-bootstrap step to get IVPM onto the runner, and
  - an `actions/cache` block (path globs, key, restore-keys) so the tool store
    and Python downloads don't get re-fetched on every run.
- Show that hand-rolled "before" workflow in full — it's not *hard*, it's just
  ~15 lines of glue that has to be **copied into every project and kept in
  sync** (cache paths, key strategy, IVPM version). That duplication is the
  problem we're solving.
- Thesis line: *the resolver isn't the missing piece — the missing piece is not
  re-implementing the CI plumbing in every repo.*

### 2. Announcing `fvutils/ivpm-setup` — the glue, factored out
- One-paragraph what-it-is: a composite GitHub Action that does the two
  CI-specific jobs for you — **installs IVPM** (no pip/venv step) and **wires
  the caching** — then runs `ivpm update`. One reference instead of a setup
  block.
- The "after" snippet (the simpler description):
  ```yaml
  - uses: actions/checkout@v4
  - uses: fvutils/ivpm-setup@v1
    with:
      dep-set: ci
  # IVPM installed, cache restored, deps in ./packages — no boilerplate
  ```
- Side-by-side before/after: the ~15-line hand-rolled block vs. the 3-line
  reference. The point isn't that the action does something you *couldn't* — it
  centralizes it, so improvements to the caching strategy land everywhere at
  once via a moving `@v1` tag instead of N copied workflows.
- Honest-by-design note: it's a thin composite action (readable YAML, no
  compiled blob) — you can see exactly what glue it replaces.

### 3. The two CI jobs, in detail — setup and caching

#### 3a. Setup: no pip/venv step
- The action installs IVPM onto the runner for you — `uv` if present (fast),
  else `pip` — and resolves/pins the version. That's the whole "get IVPM" step
  you no longer write.
- Optional `python-version` runs `actions/setup-python` first; outputs the
  resolved `ivpm-version`. Brief — this is the small win that removes one step.

#### 3b. Caching: built-in GitHub Actions cache integration
*The efficiency pitch. **Keep this light in the published post** — the headline
is "it integrates with GitHub's cache for you," not a tour of the mechanics.*
- **The one claim to make:** the action **integrates with the GitHub Actions
  cache out of the box** — it wires up `actions/cache` around IVPM's dependency
  store *and* the pip/uv download caches, keyed on your manifest, so tools and
  Python packages survive between runs. No `actions/cache` block to write or
  keep in sync.
- **Two things cached (name them, don't belabor):** the EDA tool / dependency
  store (git clones, archives, GitHub Release tarballs) and the pip/uv download
  caches.
- **One reassurance sentence:** restores are always safe and the cache stays
  bounded over time — you don't have to think about staleness. (Mechanism —
  content-addressing, prefix restore, prune-before-save — lives in
  `docs/cache-eviction-design.md`, *not* the post.)
- Outcome line: warm runs go from full re-fetch to near-instant; only changed
  deps move.

#### 3c. ...then it runs `ivpm update`
- Close the loop: with IVPM installed and the cache warm, the action runs
  `ivpm update` (honoring `dep-set`, `project-dir`, `jobs`, etc.) so later steps
  find a fully populated `./packages`. This is what makes the workflow a single
  step rather than action-plus-a-run-line. (`run-update: false` opts out.)

### 4. Going further: remote catalogs make the *manifest* simpler too (`--from`)
*Complementary beat — this is IVPM capability, not the action, but it extends
the same "stop duplicating setup" theme from the workflow to the manifest.*
- Transition: the action removes the CI *workflow* boilerplate; remote catalogs
  remove the per-project *dependency-list* boilerplate. Same philosophy, one
  layer down. (Keep this clearly distinct from the action so readers don't
  conflate the two.)
- The shift: you no longer have to hand-maintain a tool list per project.
  Point IVPM at a *published catalog manifest* and pull what you need by name.
- Two consumption modes — **lead with the project-reference one**, because it's
  what the CI example uses and it keeps the action as the only CI step:
  1. **Referenced from your own `ivpm.yaml`** *(the recommended pattern)* — your
     project manifest declares a dep with `src: ivpm.yaml` pointing at the
     catalog `url` and naming the `dep-set` (collection) it wants. A plain
     `ivpm update` then resolves *both* your project deps and the catalog
     collection together. Crucially: **the `ivpm-setup` action runs that
     `ivpm update` for you**, so CI stays a single step — no extra `--from`
     command in the workflow.
  2. **Standalone** — `ivpm update --from <url> -d <dep-set>` to pull a
     collection into the cwd with no local `ivpm.yaml` at all. Good for
     one-off / scratch use; show it, but as the secondary mode.
- `ivpm show deps --from <url>` — browse the catalog (descriptions + dep-sets)
  before referencing it. Introduce the new `description` field that makes
  catalogs self-documenting.
- Reassure on the persistence model (standalone mode): the manifest is *not*
  copied locally; the lock file records `source_manifest` so the workspace
  stays self-describing with a single source of truth. (One sentence — depth in
  design doc.)

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
*This is the section that shows everything clicking into place. Two files.*

- **The project's `ivpm.yaml`** declares its own deps *and* references the
  EDAPack catalog, requiring the `sim.rtl` collection from it — the dependency
  list lives here, once, as the single source of truth:
  ```yaml
  package:
    name: my-rtl-project
    dep-sets:
      - name: default
        deps:
          # Pull the RTL-simulation collection from the EDAPack catalog
          - name: edapack-sim
            src: ivpm.yaml
            url: https://edapack.github.io/ivpm.yaml
            dep-set: sim.rtl
          # ... plus this project's own deps
  ```
- **The workflow** is then *just the action* — it installs IVPM, warms the
  cache, and runs `ivpm update`, which resolves both the project deps and the
  `sim.rtl` collection (Verilator + Icarus) and puts the tools on `PATH`:
  ```yaml
  name: CI
  on: [push, pull_request]
  jobs:
    sim:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - uses: fvutils/ivpm-setup@v1   # install + cache + `ivpm update`
        - run: ./packages/python/bin/python -m pytest
  ```
- Drive the thesis home: no `pip install`, no `actions/cache` block, no
  `ivpm update` line, no per-tool install — the toolchain list is in the
  manifest, and the one action turns it into a warm, ready workspace.
- Mention the matrix/pinning knobs briefly (`version`, `python-version`,
  `installer: uv`, `dep-set`, `cache-key-prefix`) and point to full docs.

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
- *(No roadmap teaser in the post. The per-package GitHub Actions cache provider
  is a parallel IVPM track — internal, not announced here, so we don't
  over-promise unshipped work. See IVPM `gha-cache-provider-design.md`.)*

---

## Supporting assets to prepare
- Before/after YAML graphic for §2 — the ~15-line hand-rolled setup+cache block
  vs. the 3-line `ivpm-setup` reference. This is the post's hero image.
- A timing chart (cold vs. warm run) for §3b — even illustrative numbers help.
- EDAPack collections table (reuse from the EDAPack site) for §5.
- Links to: `ivpm-setup` design doc, remote-manifest design doc, EDAPack docs.

## Open questions for review
- Lead title — the boilerplate-thesis #1, or the action-named #2?
- Do we have real cold-vs-warm timing numbers to cite in §3b, or keep it
  qualitative for the announcement?
- Is `ivpm-setup@v1` tagged/published to the Marketplace at post time? (CTA in
  §8 depends on it.)
- Scope: the framing now makes the action the clear headline and remote catalogs
  a secondary beat (§4–5). Keep as one post, or split catalogs/EDAPack into a
  dedicated follow-up that the EDAPack site can own?
