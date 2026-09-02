---
name: libra-workflow-and-versioning
description: Structures Libra (AI-agent-native VCS) workflow practices. Use when making any change in a `libra` repository. Use when committing, branching, working across worktrees, backing up to the cloud, or organizing work for AI agents. Adapts git-workflow-and-versioning to Libra's SQLite-backed refs, per-worktree HEAD over shared object storage, and structured CLI surface.
metadata:
  libra_version: "0.22.10"
---

# Libra Workflow and Versioning

## Overview

Libra is an **AI-agent-native version control system**: a partial Git client with full on-disk object/pack compatibility, but with `config`, `HEAD`, `refs`, and `reflog` stored in a transactional SQLite database (`.libra/libra.db`) instead of flat files. It is built for monorepo / trunk-based development with tiered cloud storage (S3/R2), a Cloudflare D1/R2 backup path, and a read-only `libra publish` host.

Treat commits as save points, branches as sandboxes, and history as documentation. With AI agents generating code at high speed, disciplined version control is the mechanism that keeps changes manageable, reviewable, and reversible. Libra adds machine-readable structure on top of Git's model — `--json` / `--machine` output and stable `LBR-*` error codes — precisely so that agents (and humans) can drive it reliably.

**Libra is not Git.** Most commands mirror Git (`add`, `commit`, `branch`, `merge`, `rebase`, `log`, `diff`, `bisect`), but the storage model and a few behaviors diverge deliberately. When unsure whether a flag is honored, consult `COMPATIBILITY.md` at the root of the Libra source tree — every top-level command is classed `supported` / `partial` / `unsupported` / `intentionally-different` — and `docs/commands/<name>.md` for the per-flag contract. The biggest divergences for everyday workflow are **worktrees**, **commit signing**, and **commit conventions**.

> Verified against **Libra 0.22.10**. Libra moves fast: when anything here contradicts `libra <cmd> --help` or `docs/commands/<name>.md`, the binary wins — `CHANGELOG.md` carries the breaking-change trail.

**Deeper references** (read on demand, not up front):

| File | When to read it |
|---|---|
| [`references/worktrees.md`](references/worktrees.md) | Before any `libra worktree` use, or when setting up parallel agents |
| [`references/commit-signing-hooks.md`](references/commit-signing-hooks.md) | Signing, the hook chain, message sources, `-a` semantics |
| [`references/structured-output.md`](references/structured-output.md) | Scripting Libra: envelopes, exit codes, the error-code table |
| [`references/ai-commands.md`](references/ai-commands.md) | `code` / `agent` / `review` / `investigate` / `automation`, and the Lore working-tree extensions |
| [`references/cloud-publish.md`](references/cloud-publish.md) | Remotes, cloud backup, publishing, Git interchange |

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
- **`main` is protected.** Libra locks `main` (and the AI-capture refs `intent` / `traces`) against destructive ops — see [Branching Strategy](#branching-strategy). Lean into that: don't fight the lock with workarounds, merge through it.

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
a1b2c3d feat(tasks): add task creation endpoint with validation
d4e5f6g feat(tasks): add task creation form component
h7i8j9k feat(tasks): connect form to API and add loading state
m1n2o3p test(tasks): add task creation tests (unit + integration)

# Bad: everything mixed together
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

### Stage explicitly; avoid `commit -a`

`libra commit -a` stages **every** working-tree change, including out-of-band deletions — it has silently rolled back already-landed files. For a narrow patch, stage the exact files and omit `-a`:

```bash
# Preferred — narrow, predictable
libra add src/command/commit.rs docs/commands/commit.md
libra commit -s -m "feat(commit): support --conventional"

# Risky — bundles unrelated working-tree changes and deletions
libra commit -a -s -m "..."
```

Before committing shared files in a repo where another agent/session may be active, diff first — bundling an old WIP copy of a file can revert another stream's just-landed fixes:

```bash
libra diff src/cli.rs        # confirm you're not clobbering someone else's work
```

### Sign off with `-s`; one `-m`

Current practice is a single `-s` (just a `Signed-off-by` trailer) and a single `-m`. Passing **multiple** `-m` flags is rejected (`LBR-CLI-002`); use one `-m` with a multi-line message, or `-F <file>`:

```bash
libra commit -s -m "fix(push): record tracking reflog"
```

### Signing and hooks differ from Git — know these two

- **Signing is on by default and there is no `-S`.** `libra init` sets `vault.signing=true`, so commits are PGP-signed with the repository vault key (libvault), not GnuPG. `-S` / `--gpg-sign` are not exposed; `--no-gpg-sign` opts out per commit.
- **The hook chain is Libra-native and complete.** `.libra/hooks/*.sh|.ps1` runs `pre-commit` → `prepare-commit-msg` → `commit-msg` → commit → `post-commit` (→ `post-rewrite` for `--amend`). `--no-verify` skips all of it; `--disable-pre` skips only `pre-commit`.

Full detail — message sources, capture hooks, `-a` preflight limits — in [`references/commit-signing-hooks.md`](references/commit-signing-hooks.md).

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

**Naming:** `feature/<desc>` · `fix/<desc>` · `chore/<desc>` · `refactor/<desc>`.

### Refs live in SQLite, not files

Branches, tags, `HEAD`, and reflog are rows in `.libra/libra.db`, not files under `.git/refs`. Practical consequences:

- `libra symbolic-ref` operates on **local `HEAD` only**; other symbolic refs are rejected.
- Don't hand-edit ref files — there are none. Use `libra branch`, `libra tag`, `libra switch`, `libra symbolic-ref`.
- `libra branch` list filters (`--contains` / `--no-contains` / `--merged` / `--no-merged` / `--points-at`), copy (`-c`/`-C`), rename, and upstream set/unset (`-u` / `--unset-upstream`) are supported; `--sort` / `--format` are accepted-but-ignored (use `--json`).

### Locked branches are protected

`main`, `intent` (`refs/libra/intent`), and `traces` (`refs/libra/traces`, legacy alias `agent-traces`) are locked: destructive operations (force-create, force-rename, delete) are refused by design. The latter two are Libra's AI-capture refs — `libra agent push` publishes `refs/libra/traces` to a remote. This is intentional, not a bug: merge into a locked branch rather than rewriting it.

## Working with Worktrees

Each linked worktree owns a **real `.libra` directory** with its private `HEAD`, index, and HEAD reflog. Worktrees share one database, object store, and refs, but **each keeps its own checked-out branch and staging state** — so they *are* a usable parallel-agent primitive: one worktree, one branch, per stream.

```bash
libra worktree add ../probe                  # detached at the source commit (Libra's default)
libra worktree add ../fix-1 hotfix           # check an existing branch out, attached
libra worktree add -b topic ../topic main    # create `topic` and check it out
libra wt remove ../probe                     # DETACHES: keeps files (use --delete-dir to remove)
```

Four traps before you use it: no basename-branch default, one checkout per branch, `-b` only creates, and `remove` detaches rather than deletes. Worktrees made by older Libra versions report `layout: legacy-symlink` and **refuse every mutation with `LBR-REPO-003`** until `libra worktree repair --migrate-layout --confirm`. Read [`references/worktrees.md`](references/worktrees.md) before your first `worktree` command.

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

Wire repeatable checks into a Libra-native hook at `.libra/hooks/pre-commit.sh` (templates live in the Libra source tree at `template/pre-commit.sh` / `template/pre-commit.ps1`).

## Handling Generated & Ignored Files

- **Ignore rules:** Libra honors `.libraignore` first, then `.gitignore`. Either works; prefer `.libraignore` for Libra-only excludes.
- **Never commit** the storage dir `.libra/` (database, objects, vault, worktree registry), build output (`target/`, `dist/`, `.next/`, `web/out/` except when intentionally embedded), env files (`.env`, `.env.test`), or IDE config.
- **Do commit** generated files the project expects (e.g. lockfiles, SQL migrations under `sql/migrations/`).
- Schema migrations apply **automatically** when a command opens the database; there is no `libra db upgrade` (it was removed). `LBR-REPO-002` now means repository metadata is genuinely corrupt or incompatible, and `LBR-CONFIG-001` means the *global* config DB is newer than this binary. Neither is related to `libra upgrade`, which replaces the installed **binary** from the signed release channel and never touches repository state.

## Using Libra for Debugging

```bash
# Find which commit introduced a bug (start / bad / good / run / skip / reset / log / view)
libra bisect start
libra bisect bad HEAD
libra bisect good <known-good-commit>
libra bisect run <test-command>          # auto-narrow; or test each midpoint manually
libra bisect start <bad> <good1> <good2> # or bound it in one shot

# View what changed recently
libra log --oneline -20
libra diff HEAD~5..HEAD -- src/

# Find who last changed a specific line, or search
libra blame src/command/commit.rs
libra log --grep="validation" --oneline
libra grep "fn execute" -- src/
```

## AI-Native Workflows

These have no Git equivalent; they're why Libra exists. Treat them as first-class workflow tools:

- **`libra code`** — the collaborative-development surface. Launches the **Web Code UI**; the legacy TUI was removed in v0.20.0. Automate with `libra code --control stdio`.
- **`libra agent`** — external-agent capture: `enable`/`disable` hooks, `session`, `checkpoint`, `doctor`, `push`, `bridge`.
- **`libra graph --json <thread-id>`** — a Code thread's version graph. The graph TUI was removed in v0.20.0.
- **`libra review`** / **`libra investigate`** — read-only multi-agent review and investigation runs.
- **`libra automation`** · **`libra usage`** · **`libra sandbox status`** · **`libra service`**.

Libra also ships working-tree extensions with no Git equivalent: `layer`, `sparse-view`, `hydrate`, `dirty`, `lfs`, `file obliterate`.

Full command surfaces, flags, and Libra's *own* (incompatible) skill format are in [`references/ai-commands.md`](references/ai-commands.md).

## Cloud Backup & Publishing

```bash
libra push origin feature/task-creation   # pushing to a local file:// remote is rejected
libra cloud sync | status | restore       # Cloudflare D1 (index/metadata) + R2 (objects)
libra publish init | status | sync | deploy
```

Cloud backup needs `LIBRA_D1_*`; tiered S3/R2 storage needs `LIBRA_STORAGE_*`. Large blobs use Libra's built-in LFS (`.libra_attributes`, not Git LFS). Details, plus Git interchange via `bundle` / `fast-export`, in [`references/cloud-publish.md`](references/cloud-publish.md).

## Structured Output & Error Codes

Every output-bearing command supports a consistent envelope — use it for scripting instead of scraping human text:

```bash
libra --json status        # pretty JSON envelope on stdout
libra --json=ndjson log    # one JSON event per line
libra --machine status     # compact JSON; suppresses progress/decoration
```

```json
{ "ok": true, "command": "status", "data": { } }
```

Failures carry a **stable error code** and (on non-TTY stderr, or with `LIBRA_ERROR_JSON=1`) a final JSON report. Branch on the code, not the prose:

| Exit | Meaning |
|------|---------|
| `0`   | Success |
| `9`   | Warnings emitted (`--exit-code-on-warning`) |
| `128` | Fatal runtime error — check `error_code` |
| `129` | Usage / invalid target — fix the invocation |

`libra help error-codes` prints the authoritative code table; the namespaces and the codes worth recognizing on sight are in [`references/structured-output.md`](references/structured-output.md).

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll commit when the feature is done" | One giant commit is impossible to review, debug, or revert. Commit each slice. |
| "`commit -a` is faster" | It stages out-of-band deletions and unrelated edits, and has silently reverted landed work. `libra add <files>` then `commit -s -m`. |
| "Worktrees behave exactly like Git's" | Close, but not identical: a bare `add` is detached (no basename branch), a nonexistent branch fails closed, one checkout per branch, and `remove` detaches instead of deleting. |
| "I'll pass two `-m` flags" | Rejected with `LBR-CLI-002`. Use one `-m` with newlines, or `-F`. |
| "`-S` will use my gpg key" | `-S` / `--gpg-sign` are not exposed at all. Signing is vault-backed (libvault PGP) and on by default; skip it per commit with `--no-gpg-sign`. |
| "I'll force-rewrite `main`" | `main` / `intent` / `traces` are locked. Merge into them instead. |
| "I'll edit the ref file" | There are none — refs are SQLite rows. Use `branch`/`tag`/`switch`/`symbolic-ref`. |
| "The message doesn't matter" | Messages are documentation. Future agents will need the why. |

## Red Flags

- Large uncommitted changes accumulating
- Commit messages like "fix", "update", "misc"
- `libra commit -a` on a repo with other active sessions/agents (bundles their work)
- Worktrees still on the pre-isolation `legacy-symlink` layout (every mutation fails `LBR-REPO-003`)
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
