#!/usr/bin/env bash
#
# Check every factual claim a skill makes about Libra that a machine can check.
#
# Libra ships breaking changes several times a week, so a skill that documents it
# rots quietly. These three rules are mechanical, and between them they catch the
# class of error that is otherwise only found by reading the source:
#
#   1. every `libra <cmd>` mentioned in a code span or block is a real command
#   2. every `LBR-<NS>-<NNN>` and every `LBR-<NS>-*` namespace really exists
#   3. every flag written after `libra <cmd>` appears in that command's doc
#
# Only code spans and fenced blocks are scanned, so prose like "a libra
# repository" is never mistaken for a command.
#
# Usage:
#   LIBRA_SRC=/path/to/libra scripts/check-against-libra.sh [--verbose]
#
# Without LIBRA_SRC the check skips (exit 0): most contributors do not have the
# Libra source tree checked out, and this must not block them.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

src="skills"
verbose=false
[ "${1:-}" = "--verbose" ] && verbose=true

libra_src="${LIBRA_SRC:-}"
if [ -z "$libra_src" ]; then
  echo "LIBRA_SRC is not set — skipping the Libra cross-check."
  echo "Run it with: LIBRA_SRC=/path/to/libra scripts/check-against-libra.sh"
  exit 0
fi
if [ ! -d "$libra_src/docs/commands" ] || [ ! -f "$libra_src/docs/error-codes.md" ]; then
  echo "error: '$libra_src' does not look like a Libra source tree" >&2
  echo "       (expected docs/commands/ and docs/error-codes.md)" >&2
  exit 2
fi

# Command aliases and help topics are not files under docs/commands/.
alias_of() {
  case "$1" in
    wt) echo worktree ;;
    *)  echo "$1" ;;
  esac
}
# Accepted after `libra` but not a documented command surface.
is_help_topic() { [ "$1" = "help" ]; }

# Tokens the skill names on purpose even though they are not commands.
allow_file="$repo_root/scripts/libra-check-allow.txt"
allowed_tokens=" $(sed 's/#.*//' "$allow_file" 2>/dev/null | tr -s '[:space:]' ' ') "

# Global flags live on the root parser, not in any command doc.
global_flags=" --json --machine --quiet --color --offline --verbose --help -h --version -V --exit-code-on-warning "

# Is <flag> a real option of the command documented in <doc>?
#
# A substring search is not enough: commit.md contains the text `-S` twice, once
# in the sentence saying `-S`/`--gpg-sign` is NOT exposed and once inside a
# `git commit -S` cell of the Git-comparison table. Libra's command docs give a
# real option either a `### `-m, --message <VALUE>`` heading or the first cell of
# an option table row, so only those two positions count, and only as a whole
# backticked token.
flag_documented() {
  awk -v flag="$1" '
    function bare(text,   toks, n, i, t) {
      n = split(text, toks, /[ \t]+/)
      for (i = 1; i <= n; i++) {
        t = toks[i]
        sub(/=.*$/, "", t)
        gsub(/[][(),.]/, "", t)
        if (t == flag) return 1
      }
      return 0
    }
    function scan(text,   span, toks, n, i) {
      while (match(text, /`[^`]*`/)) {
        span = substr(text, RSTART + 1, RLENGTH - 2)
        n = split(span, toks, /[, ]+/)
        for (i = 1; i <= n; i++) if (toks[i] == flag) return 1
        text = substr(text, RSTART + RLENGTH)
      }
      return 0
    }
    /^```/                  { fence = !fence; next }
    /^#{1,6} +`/            { if (scan($0)) { found = 1; exit } }
    /^\|/                   { split($0, cells, "|"); if (scan(cells[2])) { found = 1; exit } }
    # A synopsis or example line. Only `libra ...` lines count, so a
    # `git commit -S` comparison example cannot vouch for a Libra flag.
    fence && /^libra /      { if (bare($0)) { found = 1; exit } }
    END { exit found ? 0 : 1 }
  ' "$2"
}

fail=0
note() { echo "  FAIL: $*" >&2; fail=1; }
say()  { $verbose && echo "  $*" || true; }

# Every line inside a fenced block, plus the contents of every inline code span.
extract_code() {
  awk '/^```/ { fence = !fence; next } fence { print }' "$1"
  grep -ohE '`[^`]+`' "$1" 2>/dev/null | sed 's/^`//; s/`$//' || true
}

files=""
for skill in "$src"/*/; do
  [ -d "$skill" ] || continue
  files="$files $skill/SKILL.md"
  [ -d "$skill/references" ] && files="$files $(ls "$skill"/references/*.md 2>/dev/null | tr '\n' ' ')"
done

code="$(for f in $files; do extract_code "$f"; done)"

# --- rule 1 + 3: commands and their flags ----------------------------------

# One record per `libra <cmd> [flags...]` occurrence.
invocations="$(printf '%s\n' "$code" \
  | grep -ohE '\blibra +((--?[A-Za-z][A-Za-z0-9-]*(=[A-Za-z0-9=,-]+)? +)*)[a-z][a-z0-9-]*[^`|]*' \
  || true)"

checked_cmds=""
while IFS= read -r line; do
  [ -n "$line" ] || continue

  # First token that is not a global/root flag is the command.
  cmd=""
  for tok in $line; do
    case "$tok" in
      libra) continue ;;
      -*) continue ;;
      *) cmd="$tok"; break ;;
    esac
  done
  [ -n "$cmd" ] || continue

  resolved="$(alias_of "$cmd")"
  if is_help_topic "$resolved"; then continue; fi
  # An allowlisted token is only accepted where the surrounding prose says it is
  # gone. Otherwise `libra db upgrade` could come back as advice and pass.
  case "$allowed_tokens" in
    *" $resolved "*)
      unmarked="$(grep -hn "libra $resolved" $files 2>/dev/null \
        | grep -vEi 'removed|no longer|does not exist|not exposed|was retired' || true)"
      if [ -n "$unmarked" ]; then
        note "\`libra $resolved\` is allowlisted as a removed command, but is written without saying so:"
        printf '%s\n' "$unmarked" | sed 's/^/          /' >&2
      fi
      continue
      ;;
  esac

  doc="$libra_src/docs/commands/$resolved.md"
  if [ ! -f "$doc" ]; then
    note "\`libra $cmd\` is not a Libra command (no docs/commands/$resolved.md)"
    continue
  fi
  case " $checked_cmds " in *" $resolved "*) ;; *) checked_cmds="$checked_cmds $resolved"; say "command ok: libra $resolved" ;; esac

  # Rule 3: every flag after the command must appear in that command's doc.
  seen_cmd=false
  for tok in $line; do
    if ! $seen_cmd; then
      [ "$tok" = "$cmd" ] && seen_cmd=true
      continue
    fi
    # A single line can chain two invocations ("libra add <files> -> libra
    # commit -s -m"). Flags after the next `libra` belong to that one.
    [ "$tok" = "libra" ] && break
    case "$tok" in
      -*) ;;
      *) continue ;;
    esac
    flag="${tok%%=*}"
    # Strip trailing punctuation picked up from prose.
    flag="$(printf '%s' "$flag" | sed 's/[.,;:)"]*$//')"
    case "$flag" in
      -|--) continue ;;
      *'<'*|*'>'*) continue ;;
      -[0-9]*) continue ;;   # `log -20` is a count shorthand, not a flag
    esac
    case "$global_flags" in *" $flag "*) continue ;; esac
    if ! flag_documented "$flag" "$doc"; then
      note "\`libra $resolved $flag\` — $flag is not documented in docs/commands/$resolved.md"
    fi
  done
done <<< "$invocations"

# --- rule 2: error codes ----------------------------------------------------

codes="$(printf '%s\n' "$code" | grep -ohE 'LBR-[A-Z]+-[0-9]{3}' | sort -u || true)"
while IFS= read -r c; do
  [ -n "$c" ] || continue
  if grep -qF -- "$c" "$libra_src/docs/error-codes.md"; then say "code ok: $c"
  else note "$c does not appear in docs/error-codes.md"; fi
done <<< "$codes"

# Namespaces written as `LBR-CLI-*` must exist too — four invented ones once
# shipped in this skill.
namespaces="$(printf '%s\n' "$code" | grep -ohE 'LBR-[A-Z]+-\*' | sed 's/-\*$//' | sort -u || true)"
while IFS= read -r ns; do
  [ -n "$ns" ] || continue
  if grep -qE "${ns}-[0-9]" "$libra_src/docs/error-codes.md"; then say "namespace ok: ${ns}-*"
  else note "the ${ns}-* namespace does not exist in docs/error-codes.md"; fi
done <<< "$namespaces"

# --- version anchor ---------------------------------------------------------

libra_version="$(grep -m1 '^version' "$libra_src/Cargo.toml" | sed 's/.*"\(.*\)".*/\1/' || true)"
for skill in "$src"/*/; do
  [ -d "$skill" ] || continue
  anchor="$(sed -n 's/^[[:space:]]*libra_version:[[:space:]]*//p' "$skill/SKILL.md" | head -n1 | tr -d '"')"
  name="$(basename "$skill")"
  if [ -z "$anchor" ]; then
    note "$name: SKILL.md frontmatter has no metadata.libra_version"
  elif ! grep -qF "Libra $anchor" "$skill/SKILL.md"; then
    note "$name: frontmatter says $anchor but the body does not say 'Libra $anchor' — two version claims that disagree"
  elif [ "$anchor" != "$libra_version" ]; then
    echo "  WARN: $name was verified against Libra $anchor; the source tree is $libra_version" >&2
  else
    say "version anchor ok: $anchor"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "skill claims do not match Libra $libra_version" >&2
  exit 1
fi
echo "all checkable claims match Libra $libra_version"
