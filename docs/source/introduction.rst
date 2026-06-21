Introduction
============

Why this action
---------------

Projects that use IVPM in GitHub CI typically install and drive it by hand:

.. code-block:: yaml

   - run: python -m pip install ivpm
   - run: ivpm update

That works, but it gets **no dependency caching** — every CI run re-clones every
git dependency, re-downloads every HTTP archive and GitHub release, and rebuilds
the project's Python virtual environment from scratch. For projects with many
dependencies this dominates CI wall-clock and hammers upstream hosts (and
GitHub API rate limits).

``ivpm-setup`` replaces that boilerplate with a single, cache-aware step.

What it does
------------

#. **Installs IVPM** (pinned if you want), using ``uv`` when available for speed,
   otherwise ``pip``.
#. **Restores** IVPM's content-addressed cache (and, optionally, the pip/uv
   download caches) keyed on your dependency manifest.
#. **Runs** ``ivpm update`` to populate ``./packages`` — unless you ask for
   setup-only mode.
#. **Saves** the cache inline after the update (no fragile post-step).

Because IVPM's cache is **content-addressed** by commit/version, restoring a
*stale* cache is always safe: IVPM re-fetches only the dependencies whose pinned
commit/version isn't already present. That makes the prefix-based
``restore-keys`` fallback correct, not merely best-effort.

What it does not do
-------------------

* It does not cache the project virtual environment (venvs embed absolute paths
  and are large; rebuilding from a warm pip/uv cache is fast and correct).
* It does not cache the populated ``packages/`` workspace (that's derived output,
  cheap to rebuild from a warm cache).
* It is GitHub-specific, though the underlying environment-variable contract
  (``IVPM_CACHE``, ``IVPM_GIT_AUTH_ORDER``) works in any CI.
