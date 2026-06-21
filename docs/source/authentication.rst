Authentication
==============

Some IVPM dependencies are private git repositories, or you may simply want to
avoid GitHub's unauthenticated API rate limits when resolving GitHub releases.
The ``token`` input handles both.

Default token
-------------

By default the action uses ``${{ github.token }}`` (the automatically-provided
workflow token). When a token is present, the action:

* exports ``IVPM_GIT_AUTH_ORDER=gh,https`` so IVPM prefers token-based auth;
* runs ``gh auth setup-git`` so the token is usable for ``https`` clones.

The default workflow token has ``contents:read`` on **the repository running the
workflow**. That is enough for public deps and for private deps that live in the
same repo.

Private cross-repo dependencies
-------------------------------

The default ``github.token`` **cannot** read other private repositories. If your
manifest pulls private deps from other repos, provide a Personal Access Token or
GitHub App token with ``contents:read`` on those repos:

.. code-block:: yaml

   - uses: fvutils/ivpm-setup@v1
     with:
       token: ${{ secrets.IVPM_DEPS_TOKEN }}

Store the token as an encrypted repository or organization secret — never inline
it in the workflow.

How IVPM uses the auth order
----------------------------

``IVPM_GIT_AUTH_ORDER`` controls the order IVPM tries git authentication methods
(for example ``gh,https`` or ``gh,ssh,https``). The action sets ``gh,https`` when
a token is available; you can override it in later steps by exporting a different
value before invoking ``ivpm`` yourself.
