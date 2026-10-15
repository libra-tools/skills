# Operation history and recovery

Operation v2 records command-level state independently from commit history.
Inspect it before choosing a recovery action:

```bash
libra op log -n 20
libra op show '@{0}' --view
libra op restore '@{1}' --dry-run
libra op reconcile --dry-run
libra op doctor
```

Indices use the complete newest-first operation history; filters and pagination
do not renumber them. A concrete operation id avoids ambiguity if new operations
arrive between inspection and execution. Quote reflog-style references in shells
where their punctuation has meaning.

Restore targets the captured supported HEAD/ref view. It can prune local branches
absent from that view, so inspect the preview rather than assuming only HEAD
moves. Remote-tracking refs are not pruned. Libra-owned capture/history refs
retain their current values; an operation restore is not a way to rewind traces.

The current CLI also supports append-only `op undo`, `op redo` and `op revert`
(the last requires an explicit parent). Consult the installed subcommand help
and inspect receipts before executing. Repository-wide/multi-worktree targets
need the command's explicit confirmation; concurrent ambiguous heads must be
reconciled safely rather than selecting one arbitrarily.

Capture completeness, command outcome and restorability are separate. A `Full`
capture is not a promise to restore all worktree contents. Tracked gitlinks and
their descendants are opaque; unreadable index/ignore information, unsupported
identity or unsafe aliases can make capture `Partial`. Neither `--force` nor
a successful command fills in missing content or backs up nested repositories.

Use `libra reflog` for lost commit/ref history and retain a consistent external
backup when data recovery is the goal. Do not recommend a hard reset or manual
SQLite edits as a generic response to tests, capture or migration failures.
