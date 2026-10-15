# libra-tools/skills

Portable [Agent Skills](https://agentskills.io/) for Claude Code, OpenAI Codex,
Google Gemini CLI and OpenCode. Canonical skills use the standard directory plus
`SKILL.md` format; the same files work across agents.

## Included skill

| Skill | Purpose |
|---|---|
| [libra-workflow-and-versioning](skills/libra-workflow-and-versioning/SKILL.md) | Libra repository workflow, signed commits, worktree isolation, operation recovery, external-agent capture, structured automation and cloud backup |

The skill is updated against [Libra](https://github.com/libra-tools/libra)
**0.30.49**, source commit `f306cc9`. It removes the retired Code UI, controlled-fix
and Publish recommendations and covers current local push, vault key import,
operation-v2 recovery and OpenCode 2.x capture contracts.

A separate [Windows capture preview](skills/libra-workflow-and-versioning/references/windows-capture.md)
records the local, unmerged implementation based on that source, its native
Windows build and verification. Its development validation does not establish
Windows support in an upstream release.

## Install

The supported general installer is the ecosystem CLI:

```bash
npx skills add libra-tools/skills
npx skills add libra-tools/skills -g
npx skills add libra-tools/skills --list
```

It supports per-agent selection, copy installs and updates. No Libra binary or
separate npm package from this repository is required. Project-local skills are
also available automatically when opening this checkout in a supported agent.

| Agent | Project discovery paths | Global paths used by install.sh |
|---|---|---|
| Claude Code | `.claude/skills/` | `~/.claude/skills/` |
| Codex | `.agents/skills/`, `.codex/skills/` | `~/.agents/skills/`, `~/.codex/skills/` |
| Gemini CLI | `.agents/skills/` or `.gemini/skills/` | `~/.agents/skills/`, `~/.gemini/skills/` |
| OpenCode | `.opencode/skills/`, `.claude/skills/`, `.agents/skills/` | `~/.config/opencode/skills/`, `~/.claude/skills/`, `~/.agents/skills/` |

Contributors can install directly from their working copy with Bash:

```bash
./install.sh              # symlink the canonical skill directories
./install.sh --copy       # use copies where symlinks are unsuitable
./install.sh --dry-run
./install.sh --uninstall
```

Use `LIBRA_SKILLS_HOME=/path/to/profile` to target an alternate profile root
(also useful for an isolated installer check). The default is the current
user's home. Re-run a copy install after updating the working copy.

Native single-file TOML emission was retired with Libra's Code runtime.
`scripts/emit-libra-skill.sh` is no longer shipped; `--no-libra` remains an accepted
obsolete no-op for old installer callers. Existing legacy exports under
`~/.config/libra/skills/` can be removed after verifying they are unused; the
installer now manages only standard external-agent skill directories.

Claude/Gemini/OpenCode can discover the skill by its description. In Codex,
mention `$libra-workflow-and-versioning` or select it from the skills UI.

## Edit and validate

```text
skills/<name>/                 canonical SKILL.md and bundled references
.agents/skills/<name>/         generated mirror
.claude/skills/<name>/         generated mirror
.codex/skills/<name>/          generated mirror
scripts/                      validation, synchronization and hook installation
hooks/pre-commit.sh            canonical Libra hook
```

Edit only canonical files under `skills/`; regenerate the mirrors as real copies
so Windows and ZIP downloads do not depend on symlink support:

```bash
bash scripts/validate-skills.sh
bash scripts/sync-skills.sh
bash scripts/sync-skills.sh --check
LIBRA_SRC=/path/to/libra bash scripts/check-against-libra.sh
```

The skill frontmatter records its Libra version and source commit. Check facts
against current command docs and parser/help before updating the anchor. CI
validates skills, mirrors, shell syntax, installer round trips and drift against
Libra source; it does not add Windows jobs or live model calls.

For Libra contributors, clone with `libra clone`, then run
`bash scripts/install-hooks.sh` in the resulting `.libra` checkout. A GitHub Git
clone instead has `.git`; inspect the actual layout and follow that workflow
without converting it implicitly. See [AGENTS.md](AGENTS.md) for repository rules.

## License

[MIT](LICENSE).
