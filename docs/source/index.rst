Setup IVPM — the ``ivpm-setup`` GitHub Action
=============================================

``fvutils/ivpm-setup`` is a GitHub Action that installs `IVPM
<https://github.com/fvutils/ivpm>`_, restores its content-addressed dependency
cache, and runs ``ivpm update`` — collapsing the usual CI boilerplate into a
single step:

.. code-block:: yaml

   - uses: actions/checkout@v4
   - uses: fvutils/ivpm-setup@v1
     with:
       dep-set: ci
   # deps are now populated in ./packages, and the cache is warm

It does **one** job for consumers: get an IVPM workspace ready in CI, fast,
with dependency caching that avoids re-cloning git deps and re-downloading
archives on every run.

.. toctree::
   :maxdepth: 2
   :caption: Contents:

   introduction
   getting_started
   inputs
   outputs
   caching
   authentication
   examples
   troubleshooting

Indices and tables
==================

* :ref:`genindex`
* :ref:`search`
