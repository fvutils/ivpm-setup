Troubleshooting
===============

``cache-hit`` is always ``false``
---------------------------------

* The cache key includes ``hashFiles(cache-dependency-path)``. If none of the
  globbed files exist, ``hashFiles`` returns an empty string and keys collide in
  unexpected ways — make sure ``cache-dependency-path`` matches your manifest(s).
* Caches are scoped per branch and per ``runner.os``. A first run on a new branch
  or OS is always a cold miss.
* GitHub evicts caches after 7 days of no access, and over the 10 GB ceiling.

Private dependency clone fails
------------------------------

* The default ``github.token`` cannot read *other* private repos. Provide a PAT
  or App token with ``contents:read`` on those repos via the ``token`` input —
  see :doc:`authentication`.
* Confirm ``IVPM_GIT_AUTH_ORDER`` is being set (it is, automatically, when a
  token is provided).

``pip install`` fails with "externally-managed-environment"
-----------------------------------------------------------

Some runner system Pythons are marked externally managed (PEP 668). Set
``python-version`` so the action provisions a clean interpreter via
``actions/setup-python`` before installing IVPM:

.. code-block:: yaml

   - uses: fvutils/ivpm-setup@v1
     with:
       python-version: "3.12"

``uv`` vs ``pip`` differences
-----------------------------

With ``installer: auto`` the action uses ``uv`` when it is on ``PATH`` and ``pip``
otherwise. If you need deterministic behavior across runners, set ``installer``
explicitly to ``pip`` or ``uv``.

The venv wasn't cached
----------------------

That's intentional. Virtual environments embed absolute paths and are large; the
action caches the IVPM content store and the pip/uv download caches instead, and
rebuilds the venv from those (fast and portable). See :doc:`caching`.
