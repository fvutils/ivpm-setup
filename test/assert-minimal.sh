#!/usr/bin/env bash
#
# Assert that the `minimal` fixture's workspace was populated correctly.
# Usage: assert-minimal.sh <project-dir>
#
set -euo pipefail

proj="${1:?usage: assert-minimal.sh <project-dir>}"
pkgs="$proj/packages"

echo "Asserting workspace at $pkgs"
test -d "$pkgs"      || { echo "::error::missing packages dir $pkgs"; exit 1; }
test -d "$pkgs/six"  || { echo "::error::git dep 'six' not cloned into $pkgs/six"; exit 1; }

py="$pkgs/python/bin/python"
test -x "$py" || { echo "::error::venv python missing at $py"; exit 1; }
"$py" -c "import toposort, iniconfig" \
  || { echo "::error::pypi deps (toposort, iniconfig) not importable from venv"; exit 1; }

echo "workspace OK"
