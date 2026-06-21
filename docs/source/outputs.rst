Outputs
=======

.. list-table::
   :header-rows: 1
   :widths: 22 78

   * - Output
     - Description
   * - ``cache-hit``
     - ``true`` if the primary IVPM-cache key matched exactly (no save needed).
   * - ``ivpm-version``
     - The resolved installed IVPM version. Probed via
       ``importlib.metadata.version("ivpm")`` (IVPM's CLI has no ``--version``
       flag).
   * - ``cache-dir``
     - The absolute path exported as ``IVPM_CACHE`` (useful for later steps).

Consuming outputs
-----------------

.. code-block:: yaml

   - uses: fvutils/ivpm-setup@v1
     id: ivpm
   - run: |
       echo "Installed IVPM ${{ steps.ivpm.outputs.ivpm-version }}"
       echo "Cache hit: ${{ steps.ivpm.outputs.cache-hit }}"
       echo "Cache dir: ${{ steps.ivpm.outputs.cache-dir }}"

Environment exported for later steps
------------------------------------

The action also writes to ``$GITHUB_ENV`` so subsequent steps inherit:

* ``IVPM_CACHE`` — the resolved cache directory.
* ``IVPM_GIT_AUTH_ORDER=gh,https`` — set when a ``token`` is provided.

This is what makes setup-only mode useful: after ``ivpm-setup`` with
``run-update: false``, a later ``run: ivpm update …`` step inherits the cache and
auth configuration automatically.
