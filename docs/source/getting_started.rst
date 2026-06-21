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

See :doc:`inputs` for the full set of options and :doc:`examples` for more
complete workflows.
