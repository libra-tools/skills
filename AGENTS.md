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
| `.github/workflows/ci.yml` | push to `main`, PRs, manual | The two hook checks, plus: every script keeps its exec bit, every script parses, and `install.sh` survives a `--copy` install/uninstall round trip on a clean runner |
| `.github/workflows/release.yml` | a `v*` tag, or manual | Re-runs the checks, inspects the npm tarball, then publishes |

The local pre-commit hook can be skipped with `--no-verify`; CI cannot. Keep both.

## Publishing

Skills are distributed as an npm package so a user can install them without a
clone — and without Libra:

```bash
npx @libra-tools/skills install
```

`release.yml` owns publishing; never run `npm publish` from a laptop. To cut a
release:

1. Bump `version` in `package.json` and commit it.
2. `libra tag v<version> && libra push origin v<version>`.
3. The workflow verifies the tag matches `package.json`, revalidates every skill,
   asserts the tarball carries `skills/` and none of the generated mirrors, and
   publishes with `--provenance`.

Prerequisites: the repository secret `NPM_TOKEN` (an npm automation token), and a
`package.json` whose `files` field ships only `skills/`, `bin/`, `README.md` and
`LICENSE`. Until that `package.json` exists the release workflow fails fast on
purpose.

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
