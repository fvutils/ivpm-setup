#!/usr/bin/env bash
#
# Install IVPM into the runner's Python environment.
#
# Inputs (env):
#   IVPM_VERSION    version spec, e.g. "2.14.0" or ">=2.14,<3" (empty => latest)
#   IVPM_INSTALLER  auto | pip | uv  (auto => uv if on PATH, else pip)
#
# Outputs (to $GITHUB_OUTPUT):
#   version    resolved installed IVPM version
#   installer  the installer actually used (pip or uv)
#
set -euo pipefail

version="${IVPM_VERSION:-}"
installer="${IVPM_INSTALLER:-auto}"

# Prefer `python`, fall back to `python3` (some runners only ship python3).
py="python"
if ! command -v python >/dev/null 2>&1; then
  py="python3"
fi

spec="ivpm"
if [ -n "$version" ]; then
  spec="ivpm==${version}"
fi

# Resolve `auto` to a concrete installer.
if [ "$installer" = "auto" ]; then
  if command -v uv >/dev/null 2>&1; then
    installer="uv"
  else
    installer="pip"
  fi
fi

echo "Installer: $installer"
echo "Spec:      $spec"

case "$installer" in
  uv)
    if ! command -v uv >/dev/null 2>&1; then
      "$py" -m pip install uv
    fi
    uv pip install --system "$spec"
    ;;
  pip)
    "$py" -m pip install "$spec"
    ;;
  *)
    echo "::error::Unknown installer '$installer' (expected: auto, pip, uv)" >&2
    exit 1
    ;;
esac

# IVPM has no `--version` flag (its CLI requires a subcommand), so probe the
# installed package metadata instead.
resolved="$("$py" -c 'import importlib.metadata as m; print(m.version("ivpm"))')"
echo "Installed IVPM version: $resolved"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "version=$resolved"
    echo "installer=$installer"
  } >> "$GITHUB_OUTPUT"
fi
