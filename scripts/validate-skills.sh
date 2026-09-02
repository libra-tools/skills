#!/usr/bin/env bash
#
# Validate every canonical skill against the portability rules in AGENTS.md.
#
# Checks, per skills/<name>/:
#   1. SKILL.md exists and opens with a `---` frontmatter block
#   2. frontmatter uses only portable top-level keys
#   3. `name` equals the directory name, is lowercase/digits/single-hyphens, <= 64 chars
#   4. `description` is present and <= 1024 chars
#   5. frontmatter records metadata.libra_version (the version it was verified against)
#   6. every relative Markdown link resolves to a file inside the skill directory
#   7. SKILL.md stays within the line budget (deep material belongs in references/)
#
# Usage: scripts/validate-skills.sh
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

src="skills"
max_lines=400
portable_keys="name description license metadata version allowed-tools"
fail=0

err() { echo "  FAIL: $*" >&2; fail=1; }

[ -d "$src" ] || { echo "error: no $src directory found" >&2; exit 1; }

found=0
for skill in "$src"/*/; do
  [ -d "$skill" ] || continue
  found=1
  name="$(basename "$skill")"
  file="$skill/SKILL.md"
  echo "checking $name"

  if [ ! -f "$file" ]; then err "$skill has no SKILL.md"; continue; fi
  if [ "$(head -n 1 "$file")" != "---" ]; then err "SKILL.md must start with a '---' frontmatter line"; continue; fi

  fm_end="$(awk 'NR>1 && $0=="---" {print NR; exit}' "$file")"
  if [ -z "$fm_end" ]; then err "frontmatter is not closed with '---'"; continue; fi
  fm="$(sed -n "2,$((fm_end - 1))p" "$file")"

  # 2. top-level keys
  while IFS= read -r key; do
    [ -n "$key" ] || continue
    case " $portable_keys " in
      *" $key "*) ;;
      *) err "non-portable frontmatter key '$key' (allowed: $portable_keys)" ;;
    esac
  done <<< "$(printf '%s\n' "$fm" | grep -E '^[A-Za-z][A-Za-z0-9_-]*:' | sed 's/:.*//')"

  # 3. name
  fm_name="$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -n 1)"
  if [ -z "$fm_name" ]; then err "frontmatter has no 'name'"
  else
    [ "$fm_name" = "$name" ] || err "name '$fm_name' != directory name '$name'"
    printf '%s' "$fm_name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' \
      || err "name '$fm_name' must be lowercase letters, digits and single hyphens"
    [ "${#fm_name}" -le 64 ] || err "name is ${#fm_name} chars (max 64)"
  fi

  # 4. description
  fm_desc="$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -n 1)"
  if [ -z "$fm_desc" ]; then err "frontmatter has no 'description'"
  else
    [ "${#fm_desc}" -le 1024 ] || err "description is ${#fm_desc} chars (max 1024)"
  fi

  # 5. the Libra version this skill was verified against
  fm_version="$(printf '%s\n' "$fm" | sed -n 's/^[[:space:]]*libra_version:[[:space:]]*//p' | head -n 1 | tr -d '"')"
  if [ -z "$fm_version" ]; then
    err "frontmatter has no metadata.libra_version — every skill here documents Libra, and scripts/check-against-libra.sh needs to know which version was verified"
  fi

  # 6. relative links resolve inside the skill directory
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    case "$target" in
      http*|\#*|mailto:*) continue ;;
    esac
    target="${target%%#*}"
    [ -n "$target" ] || continue
    [ -e "$skill/$target" ] || err "broken relative link '$target' (nothing at $skill$target)"
  done <<< "$(grep -rhoE '\]\([^)]+\)' "$skill" | sed 's/^](//; s/)$//')"

  # 7. line budget
  lines="$(wc -l < "$file")"
  [ "$lines" -le "$max_lines" ] \
    || err "SKILL.md is $lines lines (budget $max_lines) — move depth into references/"
done

[ "$found" = 1 ] || { echo "error: no skills found in $src/" >&2; exit 1; }

if [ "$fail" -ne 0 ]; then
  echo "skill validation failed" >&2
  exit 1
fi
echo "all skills valid"
