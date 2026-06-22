Getting started
===============

Prerequisites
-------------

* A repository with an IVPM manifest (``ivpm.yaml``, and/or ``*.ivpm.yaml``
  multi-file manifests).
* A GitHub Actions workflow.

Minimal usage
-------------

.. code-block:: yaml

   name: CI
   on: [push, pull_request]
   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: fvutils/ivpm-setup@v1
         - run: ./packages/python/bin/python -m pytest

That single ``ivpm-setup`` step installs IVPM, restores the cache, and runs
``ivpm update`` so ``./packages`` is fully populated for subsequent steps.

Pinning IVPM
------------

For reproducible CI, pin the IVPM version:

.. code-block:: yaml

   - uses: fvutils/ivpm-setup@v1
     with:
       version: "2.14.0"

Choosing a Python
-----------------

By default the action uses whatever Python is already on the runner. To pick a
specific version (the action will run ``actions/setup-python`` for you):

.. code-block:: yaml

   - uses: fvutils/ivpm-setup@v1
     with:
       python-version: "3.12"

Running workspace tools
-----------------------

After ``ivpm update`` populates ``./packages``, you can invoke the workspace
tools two ways:

**Directly** (simplest for Python entry points):

.. code-block:: yaml

   - run: ./packages/python/bin/python -m pytest

**Via direnv** (recommended when your workspace pulls in tools that publish a
``export.envrc`` — e.g. EDA toolchains / EDAPack). ``ivpm update`` generates
``packages/packages.envrc``; a project-root ``.envrc`` that does
``source_env packages/packages.envrc`` activates the whole environment, and
``direnv exec . <command>`` runs a command inside it:

.. code-block:: yaml

   - uses: fvutils/ivpm-setup@v1
   - name: Enable direnv
     run: |
       sudo apt-get update && sudo apt-get install -y direnv
       direnv allow .
   - run: direnv exec . pytest

This requires three things in place:

#. **direnv installed** on the runner (not present by default).
#. **A project-root ``.envrc``** that sources ``packages/packages.envrc`` (see
   the `IVPM direnv docs <https://fvutils.github.io/ivpm/>`_). For Python entry
   points, also add the venv bin (``PATH_add packages/python/bin``).
#. **``direnv allow .``** before ``direnv exec`` — direnv refuses an unapproved
   ``.envrc``.

See :doc:`inputs` for the full set of options and :doc:`examples` for more
complete workflows.
