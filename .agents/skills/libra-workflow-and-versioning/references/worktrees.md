# Worktrees in Libra

Read this before using `libra worktree` — the model changed, and the pre-isolation
behavior (shared `HEAD`/index) is now a *legacy* layout that refuses mutations.

## The model

Each linked worktree owns a **real `.libra` directory** holding its private `HEAD`,
index, and HEAD reflog, plus a `commondir` pointer into the shared storage.
Worktrees share one SQLite database, object store, branch/tag/remote refs, and
config, but **each keeps its own checked-out branch and staging state** —
committing in one worktree does not move another worktree's HEAD.
Worktree-local info/exclude and info/attributes, layers, sparse-view and dirty
state follow their worktree scope. A linked worktree is not an independent
database backup or migration test.

## Commands

```bash
# alias: wt
libra worktree add ../probe                  # detached at the source commit (Libra's default)
libra worktree add ../fix-1 hotfix           # check an existing branch out, attached
libra worktree add -b topic ../topic main    # create `topic` from main and check it out
libra worktree add --detach ../probe v1.2.0  # detached at any commit-ish
libra wt list --porcelain                    # each worktree's own HEAD + branch/detached + layout
libra wt lock ../probe --reason "long-running experiment"
libra wt unlock ../probe
libra wt move ../probe ../probe2
libra wt remove ../probe                     # DETACHES: keeps files and scoped state
libra wt remove --delete-dir ../probe        # Git-style delete (refused if dirty)
libra wt prune
libra wt doctor                              # read-only workspace/scope diagnostics
```

## Rules that differ from Git

- **No basename-branch DWIM.** With no target the worktree is created **detached at
  the source commit**; Git would create a branch named after the path. A nonexistent
  branch name fails closed — no remote-branch guessing, no `worktree.guessRemote`,
  no `--track`.
- **One checkout per branch.** Attaching a branch that any worktree (including the
  invoking one) already has out is refused *before* any side effect. Use `--detach`
  when you only need the content.
- **`-b` only creates.** `-B` / `--force` are deferred; a failure after branch
  creation rolls the branch back, so there is no branch-only residue.
- **`remove` keeps the directory by default, and detaches it.** The registry entry
  moves to `detached_from_registry`, scoped state (HEAD, index metadata, reflog,
  layer/sparse/dirty rows) is preserved, and every command run inside that directory
  fails closed until you re-attach with `worktree add <path>` or finish with
  `--delete-dir`. `--delete-dir` is refused on a dirty worktree; locked worktrees,
  the main worktree, and worktrees with an in-progress rebase/cherry-pick/bisect
  can't be removed.
- **A new worktree is populated from a commit** (HEAD or the given commit-ish),
  never from the staging index.
- `--lock`, `--orphan`, and `--no-checkout` are deferred; lock separately with
  `worktree lock`.

## Legacy layout

Worktrees created before the isolation work use the old shared-`.libra` symlink
layout, where HEAD and the index really were shared. `libra worktree list` reports
them as `layout: legacy-symlink`; read-only commands still work, but
**state-mutating commands refuse with `LBR-REPO-003`**. Migrate from the main
worktree:

```bash
libra worktree repair --migrate-layout --dry-run ../old    # preview, read-only
libra worktree repair --migrate-layout --confirm ../old
```

Target-oriented lifecycle commands (`worktree remove <path>`, `worktree repair
<path>`) also refuse a legacy-symlink target until the migration completes — the
shared symlink would route their writes into MAIN storage.

## Ambiguous registry

A registry written by an older binary can end up with two entries claiming one
path-derived identity (`add A` → `move A B` → `add A`). Every worktree *mutation*
is refused while that holds, including the `remove` that would fix it.
`libra worktree doctor` names the colliding entries; `libra worktree repair <path>
--resolve-identity --yes` is the one action that runs against an ambiguous registry.
That repair detaches the selected entry while keeping files and scoped state;
inspect the diagnosed identities before confirming it. Ordinary repair mutations
require `--confirm`; migration `--dry-run` needs no confirmation.

## Workspace and registration fences

The registry's stable worktree identity and its registration generation are
different. Removing and re-adding the same path can preserve its id but advances
the generation; do not reuse a stale generation in service dirty-mark requests.
`libra agent workspace list` reports runtime workspace associations and lease
state. A human worktree need not have a runtime workspace row.

Read-only doctor reports do not adopt sessions, reclaim leases or repair state.
Legacy capture-scope attribution, info-file adoption and approval adoption are
separate explicitly confirmed commands; do not infer scope from a path or copy
common state into every linked worktree.

## Parallel agents

Worktrees *are* a usable parallel-agent primitive now: give each stream its own
worktree on its own branch, then push each branch. Reach for separate `libra clone`s
only when the streams need independent object stores and databases — not merely
independent HEADs — or must not see each other's refs at all.
