Caching
=======

Caching is the primary reason to use this action. It persists IVPM's
content-addressed cache (and, optionally, the pip/uv download caches) across CI
runs.

Cache key strategy
------------------

::

   key:          <prefix>-<runner.os>-<hashFiles(cache-dependency-path)>
   restore-keys: <prefix>-<runner.os>-

* **Exact hit** (manifest unchanged): the cache restores fully, ``ivpm update``
  is near-instant, the save step is skipped, and ``cache-hit`` is ``true``.
* **Miss with prefix restore** (deps changed): the most recent same-OS cache is
  restored, ``ivpm update`` fetches only the changed deps (content-addressed → no
  redundant work), then the new cache is saved.
* **Cold** (first run): full fetch, then save.

The runner OS is part of the key because ``actions/cache`` does not restore
caches across operating systems.

Why stale restores are safe
---------------------------

IVPM's cache is **content-addressed** by commit/version
(``<cache>/<pkg>/<version-or-commit>/…``). Restoring an out-of-date cache can
never produce a wrong result: IVPM simply re-fetches the deltas (deps whose
pinned commit/version isn't already present). This is why the prefix
``restore-keys`` fallback is correct rather than best-effort.

What is and isn't cached
------------------------

.. list-table::
   :header-rows: 1
   :widths: 40 12 48

   * - Artifact
     - Cached?
     - Why
   * - ``IVPM_CACHE`` content store (git clones, HTTP archives, GH releases)
     - Yes
     - The primary win; content-addressed, so partial restores are safe.
   * - pip / uv download cache (``~/.cache/pip``, ``~/.cache/uv``)
     - Optional
     - Speeds the project venv build during update (``cache-python``).
   * - Project venv (``packages/python``)
     - No
     - venvs embed absolute paths and are large; rebuilding from a warm download
       cache is fast and correct.
   * - Populated ``packages/`` workspace
     - No
     - Derived output, not a cache; cheap to rebuild from a warm ``IVPM_CACHE``.

Limits
------

GitHub's per-repository cache ceiling (10 GB) and 7-day eviction apply. The
content store is the only thing that grows; stale entries fall out of the keyed
caches naturally.

Cache isolation
---------------

GitHub scopes caches by branch. A cache saved on a feature branch is visible to
that branch and to PRs from it, but does not leak into protected branches. Keys
include ``runner.os`` and your ``cache-key-prefix``.
