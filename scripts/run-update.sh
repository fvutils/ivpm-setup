#!/usr/bin/env bash
#
# Assemble and execute `ivpm update` from action inputs.
#
# Inputs (env):
#   IVPM_PROJECT_DIR  project dir (-p), default "."
#   IVPM_DEP_SET      dep-set(s); newline/comma/space separated => repeated -d
#   IVPM_JOBS         parallel jobs (-j)
#   IVPM_EXTRA_ARGS   raw extra args appended verbatim (word-split escape hatch)
#
set -euo pipefail

project_dir="${IVPM_PROJECT_DIR:-.}"
dep_set="${IVPM_DEP_SET:-}"
jobs="${IVPM_JOBS:-}"
extra_args="${IVPM_EXTRA_ARGS:-}"

# Resolve project-dir to an absolute path. IVPM's pip venv backend resolves the
# venv python relative to the current directory and changes cwd during the
# install phase, so a relative -p (including the default ".") breaks it with
# "Unknown python virtual-environment structure". An absolute path is robust
# across both the pip and uv backends.
if [ -d "$project_dir" ]; then
  project_dir="$(cd "$project_dir" && pwd)"
fi

args=(update -p "$project_dir")

# dep-set: normalize commas/newlines/tabs to spaces, then split into -d flags.
if [ -n "$dep_set" ]; then
  normalized="$(printf '%s' "$dep_set" | tr ',\n\t' '   ')"
  read -r -a depsets <<< "$normalized"
  for d in "${depsets[@]}"; do
    [ -n "$d" ] && args+=(-d "$d")
  done
fi

if [ -n "$jobs" ]; then
  args+=(-j "$jobs")
fi

# extra_args: documented escape hatch -- intentional word-split, caller's job to
# quote correctly.
if [ -n "$extra_args" ]; then
  read -r -a extra <<< "$extra_args"
  args+=("${extra[@]}")
fi

echo "Running: ivpm ${args[*]}"
exec ivpm "${args[@]}"
