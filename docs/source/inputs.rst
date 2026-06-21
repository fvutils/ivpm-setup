Inputs
======

All inputs are optional and have sensible defaults.

.. list-table::
   :header-rows: 1
   :widths: 20 18 62

   * - Input
     - Default
     - Description
   * - ``version``
     - ``""`` (latest)
     - IVPM version spec, e.g. ``2.14.0`` or ``>=2.14,<3``. Pin for
       reproducibility.
   * - ``python-version``
     - ``""``
     - If set, the action runs ``actions/setup-python`` with this version before
       installing IVPM.
   * - ``installer``
     - ``auto``
     - ``auto``, ``pip``, or ``uv``. ``auto`` uses ``uv`` if it is on ``PATH``
       (markedly faster), otherwise falls back to ``pip``.
   * - ``run-update``
     - ``true``
     - If ``false``, only install IVPM and restore the cache (setup-only mode).
   * - ``dep-set``
     - ``""``
     - Dependency set(s) to update; passed as repeated ``-d``. Newline-, comma-,
       or space-separated for multiple.
   * - ``project-dir``
     - ``.``
     - Project directory; passed as ``-p``.
   * - ``jobs``
     - ``""``
     - Parallel fetch jobs; passed as ``-j``.
   * - ``args``
     - ``""``
     - Extra raw args appended to ``ivpm update`` (escape hatch).
   * - ``cache``
     - ``true``
     - Enable restore + save of the IVPM content-addressed cache.
   * - ``cache-dir``
     - ``${RUNNER_TEMP}/ivpm-cache``
     - Directory exported as ``IVPM_CACHE``.
   * - ``cache-key-prefix``
     - ``ivpm``
     - Prefix for the cache key; namespace caches by OS/matrix.
   * - ``cache-dependency-path``
     - ``**/ivpm.yaml``, ``**/*.ivpm.yaml``, ``**/package-lock.json``
     - Glob(s) hashed into the cache key. Covers single- and multi-file IVPM
       manifests and any committed lock.
   * - ``cache-python``
     - ``true``
     - Also cache the pip/uv download caches (``~/.cache/pip``, ``~/.cache/uv``).
   * - ``token``
     - ``${{ github.token }}``
     - Token for private git deps and GitHub API rate limits. See
       :doc:`authentication`.

Notes
-----

* ``installer: auto`` is the recommended default — see :doc:`caching` for how the
  chosen installer affects which download cache is persisted.
* For private cross-repo dependencies, the default ``github.token`` is not
  sufficient; provide a PAT or App token (see :doc:`authentication`).
