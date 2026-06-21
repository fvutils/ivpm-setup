Examples
========

Minimal
-------

.. code-block:: yaml

   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: fvutils/ivpm-setup@v1
         - run: ./packages/python/bin/python -m pytest

Pinned + matrix + custom dep-set
--------------------------------

.. code-block:: yaml

   jobs:
     build:
       runs-on: ubuntu-latest
       strategy:
         matrix:
           python: ["3.10", "3.11", "3.12"]
       steps:
         - uses: actions/checkout@v4
         - uses: fvutils/ivpm-setup@v1
           with:
             version: "2.14.0"
             python-version: ${{ matrix.python }}
             installer: uv
             dep-set: ci
             cache-key-prefix: ivpm-${{ matrix.python }}

Note the per-matrix ``cache-key-prefix`` so each Python version keeps its own
cache.

Setup-only (drive update manually)
----------------------------------

.. code-block:: yaml

   steps:
     - uses: actions/checkout@v4
     - uses: fvutils/ivpm-setup@v1
       with:
         run-update: "false"
     - run: ivpm update -d gui-tools -j 4

The second step inherits ``IVPM_CACHE`` and the git-auth configuration from the
action.

Multiple dep-sets
-----------------

.. code-block:: yaml

   - uses: fvutils/ivpm-setup@v1
     with:
       dep-set: |
         default
         ci

Private cross-repo dependencies
-------------------------------

.. code-block:: yaml

   - uses: fvutils/ivpm-setup@v1
     with:
       token: ${{ secrets.IVPM_DEPS_TOKEN }}
