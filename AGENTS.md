# AGENTS.md — repository conventions

This repository packages **Agent Skills** (`SKILL.md`) for multiple AI coding agents
(Claude Code, OpenAI Codex CLI, Google Gemini CLI, opencode). These conventions apply
to anyone — human or agent — editing the repo.

## Source of truth

- Canonical skills live in **`skills/<name>/`**. Edit them **only** there.
- Every directory starting with a dot is a **generated mirror**. Never edit one — your
  change will be overwritten on the next sync:

  | Mirror | Read by |
  |---|---|
  | `.agents/skills/` | Gemini CLI, opencode |
  | `.claude/skills/` | Claude Code, opencode |
  | `.codex/skills/` | Codex CLI |

  Copies, not symlinks: a symlink checkout fails closed on Windows and does not
  survive a zip download. (Libra itself *does* track symlinks — it stages them as
  mode `120000` blobs and restores them on Unix — so this is a portability choice,
  not a Libra limitation.)
- After adding, renaming, removing, or editing a skill, run **`scripts/sync-skills.sh`**
  to regenerate the mirrors.

## Checks

```bash
scripts/validate-skills.sh      # frontmatter, naming, links, line budget
scripts/sync-skills.sh --check  # fail if any mirror drifted
scripts/install-hooks.sh        # run once: wires both into .libra/hooks/pre-commit.sh
```

`.libra/` is never tracked, so the canonical hook lives at `hooks/pre-commit.sh` and
`scripts/install-hooks.sh` copies it into place. Once installed, a commit that would
land an invalid skill or a stale mirror is refused.

## CI

Two GitHub Actions workflows run on the mirror
(`libra-tools/libra-workflow-and-versioning`):

| Workflow | Trigger | What it does |
|---|---|---|
| `.github/workflows/ci.yml` | push to `main`, PRs, manual | The two hook checks, plus: every script keeps its exec bit, every script parses, `install.sh` survives a `--copy` install/uninstall round trip on a clean runner, and the Libra-native emitter produces frontmatter Libra's parser accepts |

The local pre-commit hook can be skipped with `--no-verify`; CI cannot. Keep both.

## Distribution

The supported install path is the ecosystem CLI, which reads this repository's
layout straight from GitHub and needs nothing published on our side:

```bash
npx skills add libra-tools/libra-workflow-and-versioning
```

Keep `skills/<name>/SKILL.md` as the canonical layout — it is the first
well-known location that CLI looks in, and it is what makes the command above
work. Moving it would silently break every installer.

There is deliberately **no npm package**. An earlier iteration built one (it was
never published) before we found the `skills` CLI: it duplicated a subset of that
CLI while costing a release pipeline, an npm token and a version to keep in step. The one thing it did that the CLI cannot —
emitting the Libra-native single-file skill for `libra code` — lives in
`scripts/emit-libra-skill.sh` instead, and `install.sh` calls it.

## SKILL.md rules (keep skills portable)

- Frontmatter must use only widely-supported fields: `name` and `description`.
  Optional: `license`, `metadata`. Avoid agent-specific fields (e.g. Claude's
  `allowed-tools` / `disable-model-invocation`) — other agents ignore unknown fields,
  but portability is the whole point of this repo.
- `name`: lowercase letters, digits, and single hyphens; ≤64 chars; **must equal the
  directory name**.
- `description`: ≤1024 chars, written so an agent can decide *when* to use the skill.
- **Keep `SKILL.md` decision-level** (budget: 400 lines, enforced). Deep material goes
  in `skills/<name>/references/*.md`, linked from a table near the top of `SKILL.md`
  so an agent loads it only when it needs it.
- Bundle every helper script or reference file inside the skill's own directory so it
  travels with the skill. A relative link that does not resolve inside the skill
  directory fails validation.

## Keeping content true to Libra

Libra ships breaking changes often. A skill that documents Libra must:

- state the Libra version it was verified against, near the top of `SKILL.md`;
- prefer `docs/commands/<name>.md` and `COMPATIBILITY.md` in the Libra source tree over
  memory — and say that the binary wins when they disagree;
- never describe a flag without checking it is still exposed (`libra <cmd> --help`).

## Versioning

This repo is tracked with **Libra**, not Git, and mirrored to GitHub
(`libra-tools/libra-workflow-and-versioning`) for CI and distribution.

```bash
libra add <files>
libra commit -s -m "<type>(<scope>): <summary>"
libra push origin main
```

Stage files explicitly (avoid `libra commit -a`), sign off with a single `-s`, and use a
single `-m`. The bundled `libra-workflow-and-versioning` skill documents the full
workflow — this repository follows its own advice.
