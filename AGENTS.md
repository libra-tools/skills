# Repository conventions

This repository packages portable Agent Skills for Claude Code, Codex,
Gemini CLI and OpenCode.

## Canonical content and mirrors

Edit skills only in `skills/<name>/`. The `.agents/skills/`, `.claude/skills/`
and `.codex/skills/` directories are generated mirrors, not independent sources.
Run `bash scripts/sync-skills.sh` after editing canonical skill files.
Mirrors use real copies to work on Windows and in downloaded ZIPs.

Bundle references and helpers inside their skill directory so an ecosystem
install carries everything needed. Keep relative links resolvable and do not
depend on this checkout's sibling repositories being present at runtime.

## Validation

```bash
bash scripts/validate-skills.sh
bash scripts/sync-skills.sh --check
LIBRA_SRC=/path/to/libra bash scripts/check-against-libra.sh
```

Run shell syntax checks for changed scripts and an isolated install/uninstall
round trip when changing `install.sh`. Set `LIBRA_SKILLS_HOME` to a disposable
profile root; do not overwrite the developer's global skills to test an install.
Install local Libra hooks with `bash scripts/install-hooks.sh` only in a Libra
checkout. The canonical hook lives under `hooks/` because `.libra/` is untracked.

CI runs validation, mirror checks, shell parsing and standard-format installer
round trips on Linux. Its drift job sparse-checks Libra's command docs,
error-code table and Cargo manifest, then runs the same source cross-check.
The retired Code runtime's TOML emitter and its parser check are removed.

## Skill format

- Required frontmatter: `name` and `description`. Optional portable fields:
  `license`, `metadata`; avoid agent-specific policy fields.
- Names use lowercase letters, digits and single hyphens, match the directory
  name and are at most 64 characters. Descriptions are at most 1024 characters.
- Keep `SKILL.md` decision-level and at most 400 lines. Put conditional depth in
  bundled references linked near the top, loaded only for relevant tasks.
- Record `metadata.libra_version`; the body must state the same Libra version.
  Record the source commit when a specific source snapshot was checked.

Preserve the user's chosen scope and existing authorization. Skill instructions
do not independently authorize conversion, commits, pushes, publishing, installs
or external communications. Use the actual repository layout instead of assuming
every GitHub checkout contains `.libra/`.

## Keep Libra facts current

Prefer current source, `docs/commands/<name>.md`, `COMPATIBILITY.md` and binary
help over memory. Update version anchors only after checking the described
contracts. A version string alone does not establish schema compatibility or
support for a local unmerged feature.

The cross-check scans code spans/fences for commands, flags and `LBR-*` codes.
Removed-command exceptions in `scripts/libra-check-allow.txt` are accepted only
on lines explicitly marking them removed. Do not reintroduce retired surfaces as
advice merely because a historical command-doc file still exists.

Keep local development previews explicitly scoped and separate from upstream
release claims. In particular, Windows capture validation does not prove Unix
build compatibility, all-provider support or native reasoning provenance.

## Distribution and version control

The canonical layout is consumed directly by:

```bash
npx skills add libra-tools/skills
```

`install.sh` is the working-copy Bash installer. It installs standard directories
only. No npm package, agent-specific plugin manifest or native Code skill bridge
is needed. Preserve the obsolete `--no-libra` no-op for existing shell callers.

The project is maintained with Libra and mirrored to GitHub. For an actual
Libra checkout, stage exact files and use the signed/DCO workflow:

```bash
libra add <files>
libra commit -s -m "<type>(<scope>): <summary>"
libra push origin <branch>
```

Inspect the staged diff and checks before an authorized commit. A Git clone is
a separate supported checkout layout; follow its actual VCS and do not create a
second repository without an explicit task need.
