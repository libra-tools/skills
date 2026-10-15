---
name: libra-workflow-and-versioning
description: Work in Libra repositories using its SQLite-backed version-control contracts. Use for staging and signed commits, branches and isolated worktrees, operation recovery, external-agent capture, structured CLI automation, or cloud backup. Check the actual repository layout before choosing Libra or Git.
metadata:
  libra_version: "0.30.49"
  libra_commit: "f306cc9"
---

# Libra Workflow and Versioning

Updated against **Libra 0.30.49**, source commit `f306cc9`. Use the running
binary's help, `COMPATIBILITY.md`, `docs/commands/<name>.md`, and
`docs/error-codes.md` to resolve version differences. The Windows capture
reference separately describes local, unmerged work; it is not part of this
upstream version claim.

## Read only the reference needed

| File | When to read it |
|---|---|
| [Worktrees](references/worktrees.md) | Parallel checkouts, per-worktree state, layout migration or workspace diagnosis |
| [Commits, signing and hooks](references/commit-signing-hooks.md) | Commit options, vault signing, message sources and lifecycle hooks |
| [Structured output](references/structured-output.md) | JSON envelopes, exit codes, warnings, pagination and error handling |
| [External agents and extensions](references/ai-commands.md) | Capture, review, investigation, automation and working-tree extensions |
| [Remotes and cloud](references/remotes-cloud.md) | Push, D1/R2 backup, object formats and Git interchange |
| [Operation history](references/operation-history.md) | Inspecting or recovering a command's captured state without assuming a full backup |
| [Windows capture preview](references/windows-capture.md) | Native Windows build and OpenCode 2.x verification of the unmerged implementation |

## Establish the repository and binary

Read local contribution instructions and inspect the actual checkout before
running version-control commands. A Libra checkout uses `.libra/` storage;
a Git clone from GitHub can instead contain `.git/`. This skill does not turn
a Git checkout into a Libra repository or authorize a conversion. Use the
repository's actual supported workflow and preserve existing user work.

In a Libra checkout, begin with:

```bash
libra --version
libra --json status
libra branch --show-current
libra remote -v
```

For a new Libra checkout use `libra clone <url> [path]`; for a new repository
use `libra init [directory]`. Repository refs, configuration and reflog live
in SQLite, not loose Git ref files. Use commands rather than editing the
database or `.libra/` metadata by hand.

Once per session, `libra --json upgrade --check` reports a signed release
update without installing it. Surface `data.status=available` with the
installed/latest versions. A dev build may report `not_official_install`;
do not replace a task-specific build to make the check pass. The check can
persist verified anti-rollback floors, so it is not a zero-write probe.
Install with `libra upgrade --yes` only within the user's authorized scope.

## Stage and commit a reviewable change

Inspect the worktree and diff, run the relevant checks, and stage exact files.
Commit and push when requested or already authorized by the task; this skill
does not independently authorize either action.

```bash
libra diff
libra add src/command/example.rs docs/commands/example.md
libra diff --staged
libra commit -s -m "fix(example): explain the concrete behavior change"
```

Keep one logical change per commit. Use the repository's typed-summary
convention, such as `feat(scope): ...`, `fix(scope): ...`, or `docs(scope): ...`.
Use one `-m` with actual newlines for a body, or `-F <file>`; repeated `-m`
flags are rejected. `-s` adds the DCO signoff and is distinct from signing.

`commit -a` stages tracked modifications and deletions, including other
sessions' work; it does not add untracked files. Prefer explicit staging in
a shared checkout. Review the staged diff for unintended changes and secrets.

Commit signing is vault-backed by default when a vault unseal key is available.
`commit.gpgSign` overrides `vault.signing`; `--no-gpg-sign` opts out for one
commit. Positive `-S`/`--gpg-sign` flags are not exposed. Imported signing
keys are supported through the vault; see the signing reference.

## Branches and parallel work

Follow the project's branch naming and integration policy. Libra locks the
names `main`, `intent`, `traces` and legacy `agent-traces` against destructive
branch-management operations. Main remains a normal working branch; do not
attempt ordinary edits on Libra-managed AI history branches.

Branch list filters, copy/rename and upstream management are available.
`--sort` and `--format` are implemented in this version; they are not ignored.
Only local `HEAD` is supported by `libra symbolic-ref`.

Give independent streams separate worktrees and branches. A linked worktree
has its own HEAD, index, HEAD reflog and worktree scope while sharing the
database, objects, ordinary refs and repository configuration:

```bash
libra worktree add -b topic ../topic main
libra --json worktree list
```

Without a target, `worktree add` starts detached at the source commit.
A branch can be checked out in only one worktree. `worktree remove` detaches
by default and keeps files; `--delete-dir` deletes a clean worktree. Read the
worktree reference before removal, repair or legacy-layout migration.

## Integrate and recover deliberately

```bash
libra fetch origin
libra pull --ff-only
libra merge --dry-run origin/main
```

Use `pull --rebase` when rewriting local-only commits is intended. After
conflicts, inspect status, resolve and stage the intended paths, then use the
appropriate `merge --continue` or `rebase --continue`; abort when abandoning
that operation. Do not discard unrelated work to fix a failing check.

Inspect `libra reflog` and `libra op log` before recovery. Operation v2
capture completeness, command success and restorability are separate facts.
Preview a restore and inspect its receipt; neither `Full` capture nor
`--force` promises recovery of arbitrary worktree or nested repository data.

For debugging, `libra bisect`, `libra blame`, `libra log --grep`, and
`libra grep` remain available. Preserve a reproducible test for a bisect run.

## Current agent and storage surfaces

- `libra agent` installs provider capture hooks and inspects sessions,
  checkpoints, skill events and workspace records. The nested capture graph
  is `libra --json agent graph <session>`.
- `libra review` and `libra investigate` run external CLIs with read-only
  intent and isolated inputs; inspect terminal states as well as exit codes.
- `libra automation` lists and evaluates rules; `run` defaults to a dry-run
  executor, while `--live` executes eligible actions.
- `libra memory` reads/rebuilds a derived development-history projection.
  A stale query refuses with `LBR-MEMORY-001` unless `--allow-stale` is explicit.
- `libra cloud` performs D1/R2 backup and restore. `libra push` supports
  remote and local Libra/Git targets, subject to target/ref safety checks.

Removed top-level commands include `libra code`, `libra code-control`,
`libra graph`, `libra usage`, `libra publish`, and `libra db` (all removed).
Do not recommend the retired native skill bridge or a web build. Use external
agents for development, `agent` for capture and `cloud` for backup.

## Validation and delivery

Use repository-defined checks. For Libra source changes:

```bash
cargo +nightly fmt --all --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all
```

Plan task cards follow the repository's layered test policy: run focused
tests on each card; run the full suite on cross-cutting triggers and at plan
completion. Work outside a plan runs the full suite before being called done.
Feature-gated network/cloud/live-agent tests require their documented opt-ins;
the retired live-AI feature is not a substitute. There is no web build or
`LIBRA_SKIP_WEB_BUILD` knob.

When public flags, help, errors or compatibility change, update the relevant
command docs, compatibility table, error-code docs and tests together. Keep
`tests/INDEX.md` in sync when adding or renaming integration targets.

Libra honors `.libraignore` before `.gitignore`. Keep storage, credentials,
temporary transcripts and build outputs out of commits; retain generated
files the repository explicitly tracks. Migrations run when opening the DB:
do not delete receipts or assume reinstalling an older binary downgrades it.
For a live upgrade, keep a consistent SQLite backup including WAL state.

Report what changed, why, checks actually run and material limitations.
Use JSON envelopes and stable error codes for automation rather than scraping
human text. A successful process alone does not prove a nonempty captured
transcript, a completed review, or a restorable operation snapshot.
