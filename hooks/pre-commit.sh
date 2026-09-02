#!/bin/sh
#
# Libra pre-commit hook for this repository.
#
# Installed into .libra/hooks/pre-commit.sh by scripts/install-hooks.sh
# (.libra/ is ignored, so the tracked copy lives at hooks/pre-commit.sh).
#
# Refuses a commit when a skill is invalid, or when a generated agent mirror
# has drifted from its canonical source in skills/.
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
repo_root=""
for cand in "$here/../.." "$here/.."; do
  if [ -d "$cand/skills" ] && [ -f "$cand/scripts/sync-skills.sh" ]; then
    repo_root="$(cd "$cand" && pwd)"
    break
  fi
done

if [ -z "$repo_root" ]; then
  echo "pre-commit: cannot locate the repository root from $here" >&2
  exit 1
fi

cd "$repo_root"
sh scripts/validate-skills.sh
sh scripts/sync-skills.sh --check
