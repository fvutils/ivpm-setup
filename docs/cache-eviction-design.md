# Design: Cache Eviction for `ivpm-setup`

**Status:** Draft for review
**Date:** 2026-06-21
**Related:** `ivpm-setup` action (`action.yml`), IVPM
`cache-stale-tracking-plan.md` (last-used GC), IVPM `cache-provider-design.md`.

## 1. Problem

`ivpm-setup` persists IVPM's content-addressed store across CI runs via
`actions/cache` (restore + inline save). The store is keyed on the dependency
manifest:

```
key:          ${prefix}-${runner.os}-${hashFiles(cache-dependency-path)}
restore-keys: ${prefix}-${runner.os}-
```

The `restore-keys` prefix fallback means a *changed* manifest does **not** dump
the cache — it restores the most recent same-OS cache and IVPM re-fetches only
the deltas (the store is content-addressed by commit/version, so partial
restore is always safe). We then save under the new key.

That same mechanism causes **unbounded growth**. The store lays entries out as
`<cache>/<pkg>/<version-or-commit>/`, so successive versions coexist:

```
run A: ivpm.yaml@hashA  → cold → fetch verilator v1 → save {v1}        under key-A
run B: bump to v2 @hashB → restore {v1} (prefix) → fetch v2            store = {v1, v2}
                          → save {v1, v2}                              under key-B  ← v1 stale, still saved
run C: @hashB exact hit  → {v1, v2} carried forward forever
```

Nothing sheds `v1`. GitHub's own 7-day eviction acts on *cache keys*, not on
content *inside* a carried-forward entry — it will eventually evict the whole
entry (forcing a cold rebuild) but never selectively drops the stale version.
**The failure mode is keeping too much, not too little:** the store trends
toward the union of every tool version ever built, drifting up against the
10 GB/repo ceiling, slowing restore/save (larger tarball), and eventually
triggering a cold rebuild when the whole entry is evicted.

### Goal

After a version bump, the **stale version is evicted** so the persisted store
trends toward the project's *live* tool set rather than its cumulative history —
without sacrificing the safe-partial-restore property or thrashing
matrix/branch builds that legitimately share versions.

## 2. Background: IVPM already evicts; the action doesn't invoke it

Eviction is an **IVPM capability**, not something the action must invent:

| Capability | State |
|---|---|
| `ivpm cache clean -c <dir> -d <days>` — remove entries older than N days (default 7) | **Exists today** (`cmd_cache.py`, `clean_older_than`). Age = **version-dir mtime** (store-time). |
| `ivpm cache info` — sizes / per-version listing | Exists today. |
| Last-*used* GC (last-linked sidecar + optional atime), `--dry-run` | **Designed, approved, not yet implemented** — IVPM `cache-stale-tracking-plan.md`. Replaces store-time age with `max(stored, last_linked, last_read?)`. |
| `ivpm cache gc --keep-live` — prune to the current resolved lock | **Proposed here** — does not exist yet (§5, Option B). |

The current `action.yml` has **no prune step**: it restores, runs `ivpm
update`, and saves. The fix is to invoke IVPM's eviction at the right moment.

## 3. The mechanism: prune before save

The save step captures `$IVPM_CACHE`, so the eviction point is a prune wedged
between update and save:

```
1. (optional) setup-python
2. Install IVPM
3. Configure (export IVPM_CACHE, auth)
4. actions/cache/restore
5. ivpm update
6. ivpm cache clean / gc        ← NEW: prune $IVPM_CACHE before it is captured
7. actions/cache/save           (if cache && !exact-hit)
```

Pruning **before** save means the saved tarball excludes the stale version, so
the next restore cannot resurrect it — it is genuinely gone. Pruning *after*
save would be a no-op against the persisted artifact.

### Why this composes with "save only on cache miss"

Save today is gated on `steps.restore.outputs.cache-hit != 'true'` — i.e. it
fires only when the manifest hash changed. That is **exactly when accumulation
happens**:

- A pinned-manifest version bump changes the hash → key miss → restore old →
  fetch new → **prune drops the old** → save. The new keyed entry is captured
  *already pruned*. ✅
- A stable pinned manifest exact-hits → update fetches nothing → the store does
  not grow → nothing to prune, save skipped. No work, correctly. ✅

So prune-before-save runs precisely when the store would otherwise accumulate.
(The one case this does *not* cover — floating refs that change content without
changing the manifest — is a **freshness** problem, not eviction; see §6.)

## 4. Prune trigger relative to `cache-hit`

Run the prune step whenever `inputs.cache == 'true' && inputs.run-update ==
'true'`, i.e. alongside the save gate, **not** gated on a fresh fetch having
happened. Rationale: a cheap `cache clean --days N` on an unchanged store is a
near-no-op (it only deletes entries past the cutoff), and decoupling prune from
"did we fetch something new" keeps the age-based TTL honest — an entry can age
out on a run that fetched nothing. Skip the prune only when `cache == 'false'`
(nothing is persisted) or `run-update == 'false'` (setup-only; the store wasn't
touched this run).

## 5. Eviction policies

Expose both; default to the conservative one.

### Option A — Age / last-used TTL  *(recommended default)*

```bash
ivpm cache clean -c "$IVPM_CACHE" -d "$PRUNE_DAYS"
```

A bumped version's predecessor survives `PRUNE_DAYS` past its last use, then
falls out once nothing links it. Properties:

- **Matrix/branch-safe.** Restore is shared across a key prefix, but each
  variant saves its own keyed entry; recently-used versions stay warm, so a PR
  branch still on v1 and `main` on v2 do not thrash.
- **Bounded staleness, not immediate.** The store can briefly hold {v1, v2}
  but trends to the live set.
- **Correctness depends on the GC signal.** Today's `clean` ages by *store-time*
  mtime, which is wrong for a version cached long ago but used constantly (it
  would be evicted at day N+1, leaving dangling symlinks). The IVPM
  stale-tracking plan fixes this by aging on **last-linked** (refreshed every
  time IVPM materializes the entry). **This design assumes/depends on that
  plan landing** for the TTL to be trustworthy in long-lived caches; until
  then, set `PRUNE_DAYS` generously (e.g. ≥ the longest gap between builds of a
  stable branch) so store-time aging does not evict live entries.

### Option B — Prune to live set  *(opt-in, aggressive)*

```bash
ivpm cache gc --keep-live -c "$IVPM_CACHE"   # PROPOSED IVPM verb — does not exist yet
```

After update, drop every store entry **not referenced by the current resolved
lock** (`<deps-dir>/package-lock.json`). The stale version goes *immediately*.

- Right for a **single-pin project** on a tight size budget, where the cache
  namespace serves exactly one manifest.
- **Wrong when one cache namespace serves many manifests** (matrix, multiple
  branches via prefix restore, or a monorepo of projects): it would evict
  versions another variant still needs, causing re-fetch thrash.
- Requires a small new IVPM verb that reads the lock and removes non-live
  entries. Out of scope for the action's v1; gate behind `cache-prune-mode:
  live` and ship once the verb exists.

## 6. Out of scope (but adjacent): floating-ref freshness

The motivating scenario — *"a new verilator becomes available"* — splits:

- **Pinned** (`ivpm.yaml`/lock names the version, and you bump it): handled by
  §3 end-to-end (key miss → fetch new → prune old → save).
- **Floating** (gh-rls "latest", a branch ref): the manifest hash does **not**
  change, so the key exact-hits, save is skipped, and `ivpm update` may not even
  fetch the newer version (restored cache + lock already satisfy the old one).
  The cache never *picks up* the new version — a **freshness** problem upstream
  of eviction, which prune-before-save does not address.

Fixing freshness is a separate lever (recorded here so it is not conflated with
eviction):

- Key on the **post-update lock** (resolved versions). `**/package-lock.json` is
  already in `cache-dependency-path`, but `hashFiles` runs at *restore* — before
  update regenerates the lock — so this needs a **post-update key recompute** +
  save-when-lock-changed, not just adding the lock to the restore-time glob.
- Or add a periodic **epoch** component to the key (e.g. ISO week) to force a
  cold refresh on a cadence, accepting coarser freshness.

Recommend a follow-up design for floating-ref freshness; this note stops at
eviction.

## 6a. Alternatives: per-package caching (and why it supersedes this for v2)

Everything above caches the **whole store as one opaque entry** and prunes it.
An alternative is to cache **one GHA entry per `(pkg, resolved-version)`**. That
is strictly better on several axes:

- **Upload cost:** bump one tool → upload one package, not the multi-GB store
  (Model A re-uploads the whole pruned store under a new key on *every* manifest
  change; fetch is delta-only, but the *save* is not).
- **Hit precision:** unchanged tools exact-hit their own keys instead of relying
  on the coarse `restore-keys` prefix fallback.
- **Per-dep-set selectivity & matrix sharing:** a `sim.rtl` job restores only its
  packages; parallel matrix jobs caching the same `pkg@ver` collapse to one
  upload (first-writer-wins on an immutable key).
- **Eviction for free:** GitHub's native 7-day-unused LRU is *per key*, so a
  dropped tool ages out on its own — **this largely dissolves the prune problem
  this whole document solves.** Keyed on the *resolved* commit/version, it also
  fixes the §6 floating-ref freshness gap (new "latest" → new key → miss →
  fetch).

**Why it is not done in this action:** GitHub's cache API is *declare-keys-then-
restore*, which cannot express IVPM's **dynamic** dependency discovery (a git /
`--from` dep introduces transitive deps only found *during* update), and
composite actions cannot loop `uses:` over a package list. Per-package caching
therefore belongs **inside IVPM**, behind the existing `CacheProvider` seam
(`lookup`/`store`/`materialize` per `(pkg, version)`), as a
**`GithubActionsCacheProvider`** backend — not as steps here.

That provider is specified in **IVPM `gha-cache-provider-design.md`**. When it
lands, the action selects it via a `cache-provider: auto|gha|directory` input
and **drops the whole-store restore/save + prune** (this document's §3–§7); the
prune-before-save model here remains correct only for the **`directory`**
provider fallback (local dev, non-Actions CI, or when the GHA service is
unavailable). Granularity note: per-package routing covers coarse deps
(git/http/`gh-rls`); the Python wheel long-tail stays in the single pip/uv cache
entry either way.

## 7. Proposed action interface

New inputs on `action.yml`:

| Input | Default | Description |
|---|---|---|
| `cache-prune` | `true` | Run an eviction pass over `IVPM_CACHE` before save. |
| `cache-prune-mode` | `age` | `age` (`ivpm cache clean --days`) or `live` (`ivpm cache gc --keep-live`, when available). |
| `cache-prune-days` | `14` | Age cutoff for `mode: age`. Default chosen ≥ typical build gaps so store-time aging (pre stale-tracking) doesn't evict live entries; revisit down to ~7 once last-linked GC lands. |

New step in `runs.steps` (between `ivpm update` and `Save cache`):

```yaml
    - name: Prune cache
      if: inputs.cache == 'true' && inputs.run-update == 'true' && inputs.cache-prune == 'true'
      shell: bash
      env:
        IVPM_CACHE_DIR: ${{ steps.configure.outputs.cache-dir }}
        PRUNE_MODE: ${{ inputs.cache-prune-mode }}
        PRUNE_DAYS: ${{ inputs.cache-prune-days }}
      run: bash "$GITHUB_ACTION_PATH/scripts/prune-cache.sh"
```

`prune-cache.sh` (sketch — harden input handling per the action's shell-safety
convention of passing via `env:`):

```bash
set -euo pipefail
case "$PRUNE_MODE" in
  age)  ivpm cache clean -c "$IVPM_CACHE_DIR" -d "$PRUNE_DAYS" ;;
  live) ivpm cache gc --keep-live -c "$IVPM_CACHE_DIR" ;;   # requires IVPM support
  *)    echo "::error::unknown cache-prune-mode: $PRUNE_MODE"; exit 1 ;;
esac
```

Note: the pip/uv download caches (`~/.cache/pip`, `~/.cache/uv`) are *not*
content-addressed in IVPM's store and are managed by pip/uv's own eviction;
this prune covers only `IVPM_CACHE`.

## 8. Decisions & open questions

1. **Default policy** — ✅ `age` TTL (matrix/branch-safe); `live` opt-in. (§5)
2. **Default `cache-prune-days`** — ⏳ `14` as a safe pre-stale-tracking value;
   lower toward `7` once last-linked GC ships. Confirm the number.
3. **Depends on IVPM last-linked GC** (`cache-stale-tracking-plan.md`) for the
   TTL to be correct in long-lived caches — ⏳ track that work; until it lands,
   document the conservative-`days` caveat.
4. **`ivpm cache gc --keep-live`** for `mode: live` — ⏳ not implemented; design
   the verb (read lock → remove non-live entries, with `--dry-run`) before
   enabling that mode in the action.
5. **Floating-ref freshness** (§6) — ⏳ separate follow-up design; explicitly
   out of scope here.
6. **Save-on-exact-hit + prune** — accepted: stable manifests don't grow, so
   skipping save (and thus persisting a prune) on exact hit is correct. No
   periodic forced save needed for the eviction case.

---

### Sources (in-repo)

- IVPM `cache-stale-tracking-plan.md` — last-linked/atime GC, the signal the
  age-TTL depends on.
- IVPM `src/ivpm/cmds/cmd_cache.py`, `src/ivpm/cache.py` — current
  `cache clean --days` (store-time mtime) and `DirectoryCacheStore`.
- `ivpm-setup` `action.yml` — current restore/update/save flow (no prune step).
