#!/usr/bin/env bash
#
# Configure the environment for `ivpm update`:
#   - resolve and export IVPM_CACHE (content-addressed cache dir)
#   - when a token is present, set IVPM_GIT_AUTH_ORDER and wire `gh` for https
#
# Inputs (env):
#   IVPM_CACHE_DIR_IN  explicit cache dir (empty => ${RUNNER_TEMP}/ivpm-cache)
#   IVPM_TOKEN         token for private git deps / API rate limits (may be empty)
#   GH_TOKEN/GITHUB_TOKEN  consumed by `gh auth setup-git`
#
# Outputs (to $GITHUB_OUTPUT):
#   cache-dir   absolute path exported as IVPM_CACHE
#
# Note: the cache *key* is computed in action.yml via hashFiles(), which is only
# available in workflow-expression context -- not here.
#
set -euo pipefail

cache_dir="${IVPM_CACHE_DIR_IN:-}"
if [ -z "$cache_dir" ]; then
  cache_dir="${RUNNER_TEMP:-/tmp}/ivpm-cache"
fi
mkdir -p "$cache_dir"

echo "IVPM_CACHE=$cache_dir" >> "$GITHUB_ENV"
echo "cache-dir=$cache_dir" >> "$GITHUB_OUTPUT"
echo "Resolved IVPM_CACHE=$cache_dir"

if [ -n "${IVPM_TOKEN:-}" ]; then
  echo "IVPM_GIT_AUTH_ORDER=gh,https" >> "$GITHUB_ENV"
  echo "Configured IVPM_GIT_AUTH_ORDER=gh,https"
  if command -v gh >/dev/null 2>&1; then
    # Make the token usable for https clones performed by IVPM.
    gh auth setup-git || echo "::warning::'gh auth setup-git' failed; https token auth may not work"
  else
    echo "::warning::gh CLI not found; skipping 'gh auth setup-git'"
  fi
fi
