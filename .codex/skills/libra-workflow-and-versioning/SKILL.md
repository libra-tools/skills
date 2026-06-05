---
name: libra-workflow-and-versioning
description: Structures Libra (AI-agent-native VCS) workflow practices. Use when making any change in a `libra` repository. Use when committing, branching, working across worktrees, backing up to the cloud, or organizing work for AI agents. Adapts git-workflow-and-versioning to Libra's SQLite-backed refs, shared-storage worktrees, and structured CLI surface.
---

# Libra Workflow and Versioning

## Overview

Libra is an **AI-agent-native version control system**: a partial Git client with full on-disk object/pack compatibility, but with `config`, `HEAD`, `refs`, and `reflog` stored in a transactional SQLite database (`.libra/libra.db`) instead of flat files. It is built for monorepo / trunk-based development with tiered cloud storage (S3/R2), a Cloudflare D1/R2 backup path, and a read-only `libra publish` host.

Treat commits as save points, branches as sandboxes, and history as documentation. With AI agents generating code at high speed, disciplined version control is the mechanism that keeps changes manageable, reviewable, and reversible. Libra adds machine-readable structure on top of Git's model — `--json` / `--machine` output and stable `LBR-*` error codes — precisely so that agents (and humans) can drive it reliably.

**Libra is not Git.** Most commands mirror Git (`add`, `commit`, `branch`, `merge`, `rebase`, `log`, `diff`, `bisect`), but the storage model and a few behaviors diverge deliberately. When unsure whether a flag is honored, consult [`COMPATIBILITY.md`](COMPATIBILITY.md) — every top-level command is classed `supported` / `partial` / `unsupported` / `intentionally-different`. The biggest divergences for everyday workflow are **worktrees** (they share one repo database — see below) and **commit conventions**.

## When to Use

Always, for every change in a `libra` repository. Every code change flows through Libra.

## Core Principles

### Trunk-Based Development (the design default)

Libra is explicitly designed for monorepo / trunk-based development. Keep `main` always deployable. Work in short-lived feature branches that merge back within 1-3 days. Long-lived development branches are hidden costs — they diverge, create merge conflicts, and delay integration.

```
main ──●──●──●──●──●──●──●──●──●──  (always deployable)
        ╲      ╱  ╲    ╱
         ●──●─╱    ●──╱    ← short-lived feature branches (1-3 days)
```

- **Dev branches are costs.** Every day a branch lives, it accumulates merge risk.
- **Release branches are acceptable.** When you need to stabilize a release while `main` moves forward.
- **`main` is protected.** Libra locks `main` (and `intent` / `agent-traces`) against destructive ops — see [Branching Strategy](#branching-strategy). Lean into that: don't fight the lock with workarounds, merge through it.

### 1. Commit Early, Commit Often

Each successful increment gets its own commit. Don't accumulate large uncommitted changes.

```
Work pattern:
  Implement slice → Test → Verify → Commit → Next slice

Not this:
  Implement everything → Hope it works → Giant commit
```

Commits are save points. If the next change breaks something, `libra reset --hard HEAD` takes you back to the last known-good state instantly.

### 2. Atomic Commits

Each commit does one logical thing:

```
# Good: each commit is self-contained
libra log --oneline
a1b2c3d feat(tasks): add task creation endpoint with validation
d4e5f6g feat(tasks): add task creation form component
h7i8j9k feat(tasks): connect form to API and add loading state
m1n2o3p test(tasks): add task creation tests (unit + integration)

# Bad: everything mixed together
libra log --oneline
x1y2z3a add task feature, fix sidebar, update deps, refactor utils
```

### 3. Descriptive Messages

Commit messages explain the *why*, not just the *what*. Libra accepts typed Conventional-Commit summaries and can enforce them with `--conventional`:

```
# Good: explains intent
feat(auth): add email validation to registration endpoint

Prevents invalid email formats from reaching the database. Uses the
existing validation pattern in auth.rs at the route-handler level.

# Bad: describes what's obvious from the diff
update auth.rs
```

**Format:**
```
<type>(<scope>): <short description>

<optional body explaining why, not what>
```

**Types:** `feat` (new feature) · `fix` (bug fix) · `refactor` (neither fixes a bug nor adds a feature) · `test` · `docs` · `chore` (tooling/deps/config).

### 4. Keep Concerns Separate

Don't combine formatting changes with behavior changes; don't combine refactors with features. Each type of change is a separate commit — ideally a separate PR:

```
# Good
libra commit -s -m "refactor(validation): extract shared validation utility"
libra commit -s -m "feat(auth): add phone number validation to registration"

# Bad
libra commit -s -m "refactor validation and add phone number field"
```

Small cleanups (renaming one variable) can ride along in a feature commit at reviewer discretion.

### 5. Size Your Changes

Target ~100 lines per commit/PR. Changes over ~1000 lines should be split.

```
~100 lines  → Easy to review, easy to revert
~300 lines  → Acceptable for a single logical change
~1000 lines → Split into smaller changes
```

## Libra Commit Conventions

These are the Libra-specific habits that keep history clean and avoid known footguns.

### Stage explicitly; avoid `commit -a`

`libra commit -a` stages **every** working-tree change, including out-of-band deletions — it has silently rolled back already-landed files. For a narrow patch, stage the exact files and omit `-a`:

```
# Preferred — narrow, predictable
libra add src/command/commit.rs docs/commands/commit.md
libra commit -s -m "feat(commit): support --conventional"

# Risky — bundles unrelated working-tree changes and deletions
libra commit -a -s -m "..."
```

Before committing shared files in a repo where another agent/session may be active, diff first — bundling an old WIP copy of a file can revert another stream's just-landed fixes:

```
libra diff src/cli.rs        # confirm you're not clobbering someone else's work
```

### Sign off with `-s`; one `-m`

Current practice is a single `-s` (just a `Signed-off-by` trailer) and a single `-m`. Passing **multiple** `-m` flags is rejected (`LBR-CLI-002`); use one `-m` with a multi-line message, or `-F <file>`:

```
libra commit -s -m "fix(push): record tracking reflog"
```

### Cryptographic signing is vault-backed, not GnuPG

`-S` / `--gpg-sign` / `commit.gpgSign` drive **vault-backed PGP signing** (libvault, `.libra`), *not* an external `gpg` process. Don't expect a GnuPG agent, keyring, or `~/.gnupg` to be involved. Same chain is reused by `merge` and `cherry-pick`.

### Hooks are Libra-native

`prepare-commit-msg` / `commit-msg` run from `.libra/hooks/*.sh|.ps1`, not `.git/hooks`. `post-commit` is not run. External-agent capture hooks (Claude Code / Gemini) are installed by `libra agent enable`.

## Branching Strategy

```
main (always deployable, LOCKED)
  │
  ├── feature/task-creation    ← one feature per branch
  ├── feature/user-settings    ← parallel work
  └── fix/duplicate-tasks      ← bug fixes
```

- Branch from `main` (or the team's default branch).
- Keep branches short-lived (merge within 1-3 days). Delete branches after merge.
- Prefer feature flags over long-lived branches for incomplete work.

### Refs live in SQLite, not files

Branches, tags, `HEAD`, and reflog are rows in `.libra/libra.db`, not files under `.git/refs`. Practical consequences:

- `libra symbolic-ref` operates on **local `HEAD` only**; other symbolic refs are rejected.
- Don't hand-edit ref files — there are none. Use `libra branch`, `libra tag`, `libra switch`, `libra symbolic-ref`.
- `libra branch` list filters (`--contains` / `--no-contains` / `--merged` / `--no-merged` / `--points-at`), copy (`-c`/`-C`), rename, and upstream set/unset (`-u` / `--unset-upstream`) are supported; `--sort` / `--format` are accepted-but-ignored (use `--json`).

### Locked branches are protected

`main`, `intent`, and `agent-traces` are locked: destructive operations (force-create, force-rename, delete) are refused by design. This is intentional, not a bug — merge into them rather than rewriting them.

### Branch Naming

```
feature/<short-description>   → feature/task-creation
fix/<short-description>       → fix/duplicate-tasks
chore/<short-description>     → chore/update-deps
refactor/<short-description>  → refactor/auth-module
```

## Working with Worktrees ⚠️ (read this — Libra differs from Git)

**Libra worktrees do NOT give you Git-style branch isolation.** Every linked worktree's `.libra` is a *symlink* back to one shared storage directory, so all worktrees **share the same SQLite database, object store, `HEAD`, index, and refs**. There is **no branch-per-worktree** (the `add` subcommand takes no branch argument). Switching branches or committing in one worktree changes state for all of them.

```bash
# Create / list / manage worktrees (alias: wt)
libra worktree add ../experiment
libra wt list
libra wt lock ../experiment --reason "long-running experiment"
libra wt remove ../experiment            # unregisters only — KEEPS files on disk by default
libra wt remove --delete-dir ../experiment   # Git-style delete (refused if dirty)
```

What Libra worktrees **are** good for:
- A second physical checkout of the *same* state (e.g. run a long build in one dir while editing in another).
- A new worktree is populated from **HEAD** (last commit), not the staging index.

What they are **NOT**:
- They are **not** an isolation mechanism for parallel agents on different branches. Because HEAD/refs are shared, two agents committing in two worktrees land on the **same** branch and can bundle each other's work.

For true branch isolation across parallel streams, do one of:
1. **Separate clones** — `libra clone` into independent directories (separate `.libra` databases). This is the real parallel-isolation primitive.
2. **Branch + `symbolic-ref`** — within one repo, drive HEAD deliberately with `libra switch` / `libra symbolic-ref` and land each stream on its own branch, then push the branch (`libra push origin <branch>:main` to fast-forward onto the trunk).

Safety notes baked into the command: `worktree remove` keeps the directory by default (Git deletes it); `--delete-dir` is refused on a dirty worktree; locked worktrees can't be moved or removed.

## The Save Point Pattern

```
Agent starts work
    │
    ├── Makes a change
    │   ├── Test passes? → libra add <files> → libra commit -s -m → Continue
    │   └── Test fails?  → libra reset --hard HEAD → Investigate
    │
    └── Feature complete → All commits form a clean history
```

You never lose more than one increment. If an agent goes off the rails, `libra reset --hard HEAD` returns to the last successful state. (Reflog is in SQLite — `libra reflog` recovers a lost commit even after a hard reset.)

## Change Summaries

After any modification, provide a structured summary. This makes review easier, documents scope discipline, and surfaces unintended changes:

```
CHANGES MADE:
- src/command/commit.rs: Added --conventional validation to the staged-commit path
- docs/commands/commit.md: Documented the flag + example

THINGS I DIDN'T TOUCH (intentionally):
- src/command/merge.rs: Shares the signoff helper but out of scope here
- COMPATIBILITY.md: commit row already says `partial`; no tier change needed

POTENTIAL CONCERNS:
- New behavior is opt-in behind --conventional; default path is byte-identical
- No new StableErrorCode introduced, so docs/error-codes.md needs no edit
```

The "DIDN'T TOUCH" section is especially important — it shows you exercised scope discipline and didn't go on an unsolicited renovation. (This mirrors Libra's own CLAUDE.md change-summary expectation.)

## Pre-Commit Hygiene

Before every commit:

```bash
# 1. See exactly what you're about to commit
libra diff --staged

# 2. Ensure no secrets slipped in
libra diff --staged | grep -iE "password|secret|api[_-]?key|token"

# 3. Run the project's checks. For the Libra codebase itself:
cargo +nightly fmt --all --check
cargo clippy --all-targets --all-features -- -D warnings   # zero warnings required
LIBRA_SKIP_WEB_BUILD=1 cargo test --all                    # L1 layer; L2/L3 auto-skip
```

Wire repeatable checks into a Libra-native hook at `.libra/hooks/pre-commit.sh` (templates live in `template/pre-commit.sh` / `pre-commit.ps1`).

## Handling Generated & Ignored Files

- **Ignore rules:** Libra honors `.libraignore` first, then `.gitignore`. Either works; prefer `.libraignore` for Libra-only excludes.
- **Never commit** the storage dir `.libra/` (database, objects, vault, worktree registry), build output (`target/`, `dist/`, `.next/`, `web/out/` except when intentionally embedded), env files (`.env`, `.env.test`), or IDE config.
- **Do commit** generated files the project expects (e.g. lockfiles, SQL migrations under `sql/migrations/`).
- After landing a built-in schema migration, the local repo can fail `LBR-REPO-002` until you run `libra db upgrade` — which also live-validates the forward + down DDL.

## Using Libra for Debugging

```bash
# Find which commit introduced a bug (start / bad / good / run / skip / reset / log / view)
libra bisect start
libra bisect bad HEAD
libra bisect good <known-good-commit>
libra bisect run <test-command>          # auto-narrow; or test each midpoint manually

# Or bound it in one shot (multiple good commits allowed):
libra bisect start <bad> <good1> <good2>

# View what changed recently
libra log --oneline -20
libra diff HEAD~5..HEAD -- src/

# Find who last changed a specific line
libra blame src/command/commit.rs

# Search commit messages / working tree
libra log --grep="validation" --oneline
libra grep "fn execute" -- src/
```

## AI-Native Workflows (Libra extensions)

These have no Git equivalent; they're why Libra exists. Treat them as first-class workflow tools:

- **`libra code`** — interactive TUI with an AI agent, background web server, and MCP server. The primary collaborative-development surface.
- **`libra agent`** — manage external-agent capture, **checkpoints**, hooks, and RPC adapters. Checkpoints are agent-run save points layered on top of commits.
- **`libra automation`** — list, run, and inspect rule-based automation.
- **`libra graph`** — inspect a Code thread's version graph in a dedicated TUI.
- **`libra usage`** — report/prune AI provider & model usage and cost aggregates.
- **`libra sandbox`** — inspect AI sandbox diagnostics (OS backend availability, downgrade warnings).

These are classed `intentionally-different` in `COMPATIBILITY.md` — they are Libra-only and won't map to any Git command.

## Cloud Backup & Publishing

Libra's tiered storage and cloud paths replace ad-hoc remotes for backup/sharing:

```bash
# Push to a configured remote (branch/tag update, multi-refspec, delete, --tags, --mirror)
libra push origin feature/task-creation

# Back up / restore repository metadata via Cloudflare D1 + R2
libra cloud ...

# Publish a read-only snapshot to the Cloudflare Worker host
libra publish ...
```

Notes: pushing to a **local `file://` remote is intentionally rejected**. Large blobs use Libra's built-in LFS (`.libra_attributes`, not Git LFS filters/hooks). Cloud backup needs `LIBRA_D1_*`; tiered S3/R2 storage needs `LIBRA_STORAGE_*`.

## Structured Output & Error Codes (drive Libra like an agent)

Every output-bearing command supports a consistent envelope — use it for scripting and automation instead of scraping human text:

```bash
libra --json status        # pretty JSON envelope on stdout
libra --json=ndjson log    # one JSON event per line
libra --machine status     # compact JSON; suppresses progress/decoration
```

```json
{ "ok": true, "command": "status", "data": { ... } }
```

Failures carry a **stable error code** and (on non-TTY stderr, or with `LIBRA_ERROR_JSON=1`) a final JSON report. Branch on the code, not the prose:

| Exit | Meaning |
|------|---------|
| `0`   | Success |
| `9`   | Warnings emitted (`--exit-code-on-warning`) |
| `128` | Fatal runtime error — check `error_code` |
| `129` | Usage / invalid target — fix the invocation |

Namespaces: `LBR-REPO-*` (repo state) · `LBR-CLI-*` (argument validation) · `LBR-NET-*` (transport) · `LBR-FS-*` / `LBR-IO-*` (filesystem) · `LBR-IDX-*` (index) · `LBR-OBJ-*` (objects) · `LBR-VAULT-*` (vault) · `LBR-CONFLICT-*` (conflicts).

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll commit when the feature is done" | One giant commit is impossible to review, debug, or revert. Commit each slice. |
| "`commit -a` is faster" | It stages out-of-band deletions and unrelated edits, and has silently reverted landed work. `libra add <files>` then `commit -s -m`. |
| "Worktrees isolate my agents like Git" | They don't — Libra worktrees share one DB/HEAD/refs. Use separate clones or branch + `symbolic-ref` for real isolation. |
| "I'll pass two `-m` flags" | Rejected with `LBR-CLI-002`. Use one `-m` with newlines, or `-F`. |
| "`-S` will use my gpg key" | Libra signs via the vault (libvault PGP), not GnuPG. No keyring involved. |
| "I'll force-rewrite `main`" | `main`/`intent`/`agent-traces` are locked. Merge into them instead. |
| "I'll edit the ref file" | There are none — refs are SQLite rows. Use `branch`/`tag`/`switch`/`symbolic-ref`. |
| "The message doesn't matter" | Messages are documentation. Future agents will need the why. |

## Red Flags

- Large uncommitted changes accumulating
- Commit messages like "fix", "update", "misc"
- `libra commit -a` on a repo with other active sessions/agents (bundles their work)
- Treating worktrees as branch-isolated parallel sandboxes
- Formatting changes mixed with behavior changes
- Committing `.libra/`, `target/`, `.env`, or build artifacts
- No `.libraignore` / `.gitignore`
- Long-lived branches that diverge significantly from `main`
- Force-pushing to shared branches; fighting locked-branch protection with workarounds
- Changing a Git-compat command without syncing `COMPATIBILITY.md` + `docs/commands/<name>.md` + integration scenarios

## Verification

For every commit:

- [ ] Commit does one logical thing
- [ ] Message explains the why; typed `<type>(<scope>): ...` summary
- [ ] Files staged explicitly (`libra add`), not blanket `-a`
- [ ] Signed off with a single `-s`, single `-m`
- [ ] `libra diff --staged` reviewed; no secrets
- [ ] Tests / clippy / fmt pass before committing
- [ ] No formatting-only changes mixed with behavior changes
- [ ] `.libraignore` / `.gitignore` covers `.libra/`, `target/`, `.env`
- [ ] If a Git-compat surface changed: `COMPATIBILITY.md` + command doc updated
