# AGENTS.md — repository conventions

This repository packages **Agent Skills** (`SKILL.md`) for multiple AI coding agents
(Claude Code, OpenAI Codex CLI, Google Gemini CLI, opencode). These conventions apply
to anyone — human or agent — editing the repo.

## Source of truth

- Canonical skills live in **`.agents/skills/<name>/SKILL.md`**. Edit them **only** there.
- `.claude/skills/<name>/` and `.codex/skills/<name>/` are **generated mirror copies** of
  the canonical files. Never edit them directly — your change will be overwritten.
  (Copies, not symlinks: Libra does not track symlinks, and copies survive Windows
  clones / zip downloads.)
- After adding, renaming, removing, or editing a skill, run **`scripts/sync-skills.sh`**
  to regenerate the mirrors. `scripts/sync-skills.sh --check` (suitable for CI or a
  pre-commit hook) fails if any mirror is out of date.

## SKILL.md rules (keep skills portable)

- Frontmatter must use only widely-supported fields: `name` and `description`.
  Optional: `license`, `metadata`. Avoid agent-specific fields (e.g. Claude's
  `allowed-tools` / `disable-model-invocation`) — other agents ignore unknown fields,
  but portability is the whole point of this repo.
- `name`: lowercase letters, digits, and single hyphens; ≤64 chars; **must equal the
  directory name**.
- `description`: ≤1024 chars, written so an agent can decide *when* to use the skill.
- Bundle any helper scripts or reference files inside the skill's own directory so they
  travel with it.

## Versioning

This repo is tracked with **Libra**, not Git. Use:

```bash
libra add <files>
libra commit -s -m "<type>(<scope>): <summary>"
```

Stage files explicitly (avoid `libra commit -a`), sign off with a single `-s`, and use a
single `-m`. The bundled `libra-workflow-and-versioning` skill documents the full
workflow — this repository follows its own advice.
