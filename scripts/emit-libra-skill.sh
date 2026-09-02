#!/usr/bin/env bash
#
# Emit the Libra-native form of each canonical skill.
#
# `libra code` does not read the Agent Skills standard. Its runtime loads a
# single `<name>.md` with TOML frontmatter from, in order, `<repo>/.libra/skills/`,
# an overlay, `~/.config/libra/skills/`, and a tier embedded in the binary
# (src/internal/ai/skills/). So a skill installed for Claude Code, Codex, Gemini
# or opencode is invisible to `libra code` until it is converted.
#
# The conversion flattens the skill: references/ are inlined, because that format
# has no notion of bundled files. Libra's parser uses serde deny_unknown_fields,
# so only name/description/version/allowed-tools may be emitted.
#
# Usage:
#   scripts/emit-libra-skill.sh                 # -> ~/.config/libra/skills/
#   scripts/emit-libra-skill.sh <dir>           # -> <dir>/
#   scripts/emit-libra-skill.sh --stdout <name> # print one skill, write nothing
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

src="skills"
version="1.0.0"

# Copied from Libra's own embedded skill (src/internal/ai/skills/embedded/libra.md).
# An empty list parses fine but raises a `missing_allowed_tools` scan warning.
allowed_tools='"read_file", "list_dir", "grep_files", "search_files", "web_search", "shell", "apply_patch", "run_libra_vcs", "update_plan", "submit_task_complete"'

to_stdout=false
if [ "${1:-}" = "--stdout" ]; then to_stdout=true; shift; fi

# Escape a value for a TOML basic string.
toml_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

emit_one() {
  skill_dir="$1"
  name="$(basename "$skill_dir")"
  file="$skill_dir/SKILL.md"

  fm_end="$(awk 'NR>1 && $0=="---" {print NR; exit}' "$file")"
  [ -n "$fm_end" ] || { echo "error: $file has no closing frontmatter fence" >&2; exit 1; }
  fm="$(sed -n "2,$((fm_end - 1))p" "$file")"

  fm_name="$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -n 1)"
  fm_desc="$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -n 1)"
  [ -n "$fm_name" ] || fm_name="$name"

  printf -- '---\n'
  printf 'name = "%s"\n' "$(toml_escape "$fm_name")"
  printf 'description = "%s"\n' "$(toml_escape "$fm_desc")"
  printf 'version = "%s"\n' "$(toml_escape "$version")"
  printf 'allowed-tools = [%s]\n' "$allowed_tools"
  printf -- '---\n'

  # Command substitution strips trailing newlines; `sed '/./,$!d'` strips leading
  # blank lines. Together they are the trim the flat file needs — no reflowing,
  # so blank lines inside the body survive untouched.
  printf '%s\n' "$(emit_body "$skill_dir" "$fm_end" | sed '/./,$!d')"
}

emit_body() {
  skill_dir="$1"
  fm_end="$2"

  # Reference links cannot resolve in one flat file; keep the link text only.
  sed "1,${fm_end}d" "$skill_dir/SKILL.md" \
    | sed -E 's/\[([^]]+)\]\(references\/[^)]+\)/\1/g'

  if [ -d "$skill_dir/references" ]; then
    for ref in "$skill_dir"/references/*.md; do
      [ -f "$ref" ] || continue
      printf '\n\n---\n\n<!-- inlined from references/%s -->\n\n' "$(basename "$ref")"
      printf '%s\n' "$(sed '/./,$!d' "$ref")"
    done
  fi
}

if $to_stdout; then
  target_name="${1:-}"
  [ -n "$target_name" ] || { echo "error: --stdout needs a skill name" >&2; exit 2; }
  [ -d "$src/$target_name" ] || { echo "error: no skill '$target_name' in $src/" >&2; exit 1; }
  emit_one "$src/$target_name"
  exit 0
fi

dest="${1:-$HOME/.config/libra/skills}"
mkdir -p "$dest"

for skill in "$src"/*/; do
  [ -d "$skill" ] || continue
  name="$(basename "$skill")"
  emit_one "$skill" > "$dest/$name.md"
  echo "wrote $dest/$name.md"
done
