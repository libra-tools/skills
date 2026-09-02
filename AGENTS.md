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
(`libra-tools/skills`):

| Workflow | Trigger | What it does |
|---|---|---|
| `ci.yml` → `skills` | push to `main`, PRs, manual, weekly | The two hook checks, plus: every script keeps its exec bit, every script parses, `install.sh` survives a `--copy` install/uninstall round trip on a clean runner, and the Libra-native emitter produces frontmatter Libra's parser accepts |
| `ci.yml` → `drift` | same, and **weekly on a cron** | Sparse-checks out Libra's `docs/` and runs `scripts/check-against-libra.sh` against it |

The local pre-commit hook can be skipped with `--no-verify`; CI cannot. Keep both.

## Distribution

The supported install path is the ecosystem CLI, which reads this repository's
layout straight from GitHub and needs nothing published on our side:

```bash
npx skills add libra-tools/skills
```

Keep `skills/<name>/SKILL.md` as the canonical layout — it is the first
well-known location that CLI looks in, and it is what makes the command above
work. Moving it would silently break every installer.

### One channel, deliberately

There is no npm package and no Claude Code plugin manifest, and neither is an
oversight:

- **No npm package.** An earlier iteration built one (never published) before we
  found the `skills` CLI. It duplicated a subset of that CLI while costing a
  release pipeline, an npm token and a version to keep in step. The one thing it
  did that the CLI cannot — emitting the Libra-native single-file skill for
  `libra code` — lives in `scripts/emit-libra-skill.sh` instead, and
  `install.sh` calls it.
- **No `.claude-plugin/plugin.json`.** A plugin manifest would serve Claude Code
  only, which `npx skills add` already covers, so it buys reach we have and adds
  a second channel to keep in step. Reconsider only if listing on the official
  marketplace is wanted for discovery — that is a distribution decision, not a
  capability one.

The rule both cases came from: **do not re-implement what the ecosystem already
does.** Add a channel only for something no existing tool can do, the way the
`libra code` bridge earns its place.

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

Libra ships breaking changes several times a week, so a skill documenting it rots
quietly. Three defences, in order of how much they actually catch:

**1. `scripts/check-against-libra.sh`** — the mechanical cross-check. Given
`LIBRA_SRC=/path/to/libra` it verifies, over every code span and fenced block in
`SKILL.md` and `references/`:

- every `libra <cmd>` is a real command (a `docs/commands/<name>.md` exists);
- every flag written after a command is *documented* for that command — as an
  option heading, an option-table row, or a `libra ...` line in a fenced block.
  A bare substring search is not enough: `commit.md` contains the text `-S`
  twice while saying it is **not** exposed;
- every `LBR-<NS>-<NNN>` and every `LBR-<NS>-*` namespace exists in
  `docs/error-codes.md`;
- the frontmatter `metadata.libra_version` is present, agrees with the version
  stated in the body, and matches the Libra tree being checked.

Without `LIBRA_SRC` it skips, so contributors without the Libra source are never
blocked. The `drift` CI job supplies it weekly.

`scripts/libra-check-allow.txt` lists tokens that look like commands but are not
— currently just `db`, because the skill warns that `libra db upgrade` was
removed. An allowlisted token is still only accepted on a line whose prose marks
it as gone, so it cannot come back as advice.

**2. `metadata.libra_version` in the frontmatter**, mirrored by a sentence near
the top of the body. Both must say the same version; the cross-check enforces it.

**3. Judgement, for the claims no script can check.** Prefer
`docs/commands/<name>.md` and `COMPATIBILITY.md` in the Libra source over memory,
say that the binary wins when they disagree, and never describe a behaviour
without checking it (`libra <cmd> --help`). Whether `post-commit` runs, or
whether `libra code` still has a TUI, is exactly this category — the cross-check
will not save you there.

## Versioning

This repo is tracked with **Libra**, not Git, and mirrored to GitHub
(`libra-tools/skills`) for CI and distribution.

```bash
libra add <files>
libra commit -s -m "<type>(<scope>): <summary>"
libra push origin main
```

Stage files explicitly (avoid `libra commit -a`), sign off with a single `-s`, and use a
single `-m`. The bundled `libra-workflow-and-versioning` skill documents the full
workflow — this repository follows its own advice.
