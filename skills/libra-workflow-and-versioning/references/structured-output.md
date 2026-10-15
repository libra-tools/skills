# Structured output and stable error codes

Use a command's documented envelope and stable error code for automation.
Some plumbing commands intentionally emit raw bytes or status-only results;
check their contracts before assuming every successful stdout is an envelope.

## Output modes

```bash
libra --json status        # pretty JSON envelope on stdout
libra --json=ndjson log    # one JSON event per line
libra --machine status     # compact JSON; suppresses progress and decoration
libra --quiet --exit-code-on-warning ...   # silent; exit 9 if warnings occurred
libra --color=never log    # force-disable color (also via NO_COLOR=1)
```

Success envelope:

```json
{ "ok": true, "command": "status", "data": { } }
```

Failures carry a stable error code and — on non-TTY stderr, or with
`LIBRA_ERROR_JSON=1` — a final JSON report.

Stdout-producing commands treat a downstream closed pipe as normal pipeline
termination: they exit quietly, with no panic, backtrace, or `Broken pipe`
diagnostic.

## Exit codes

| Exit | Meaning | What to do |
|------|---------|------------|
| `0`   | Success | Continue |
| `9`   | Warnings emitted (`--exit-code-on-warning`) | Review warnings |
| `128` | Fatal runtime error | Check `error_code` for the category |
| `129` | Usage / invalid target | Fix the invocation |

Command-specific statuses also exist: `status --exit-code` uses 1 for dirty,
branch-delete refusals use 1, and `cat-file -e` is a silent 0/1 probe.
Read-only review runs can exit 0 after timeout/cancellation/partial outcomes;
inspect their terminal state. JSON-RPC bridge errors are frames and do not
necessarily terminate the serving process. `LIBRA_FINE_EXIT_CODES=1` opts into
legacy 2-8 mappings; do not assume it is unset in a wrapper's environment.

Arbitration when several apply: fatal ≻ 9 (warning) ≻ 1 (dirty, for
`status --exit-code`) ≻ 0.

## Error-code namespaces

`libra help error-codes` prints the authoritative table. The namespaces:

| Namespace | Covers |
|---|---|
| `LBR-CLI-*` | Unknown command, invalid arguments, invalid object/revision/pathspec |
| `LBR-REPO-*` | Not in a repo; corrupt or incompatible metadata; repo state blocks the operation |
| `LBR-WORKTREE-*` | Malformed pagination cursor; unreadable worktree/workspace scope |
| `LBR-CONFIG-*` / `LBR-UPGRADE-*` | Global config DB newer than this binary; corrupt upgrade settings |
| `LBR-CONFLICT-*` | Unresolved conflict; operation blocked to avoid overwriting state |
| `LBR-POLICY-*` | Branch policy (protected / archived) blocked a ref update |
| `LBR-CASE-*` | Case-only path collision on a case-insensitive filesystem |
| `LBR-LAYER-*` | Layer overlay collision, or a layer path was staged |
| `LBR-MEMORY-*` | Derived development-history projection is stale |
| `LBR-NET-*` / `LBR-AUTH-*` | Transport and authentication |
| `LBR-IO-*` | Filesystem read/write |
| `LBR-ADD-*` · `LBR-BISECT-*` · `LBR-AGENT-*` · `LBR-OBLITERATE-*` | Command-specific |
| `LBR-UNSUPPORTED-*` · `LBR-WARN-*` · `LBR-INTERNAL-*` | Not implemented, warnings, internal |

Codes worth recognizing on sight:

- `LBR-CLI-002` — invalid or missing arguments (two `-m` flags, bad `--conventional`
  message, bad `--author`).
- `LBR-REPO-003` — repository state blocks the operation (no commits yet, a
  `legacy-symlink` worktree, missing configured remote).
- `LBR-CONFIG-001` — a required GlobalConfig/SystemConfig schema or migration
  receipt is unsupported. Compatibility is role-scoped: known repository-only
  receipts do not make configuration future. Some optional configuration reads
  can warn and skip a future store; required storage settings fail closed.
- `LBR-CONFLICT-002` — blocked to avoid overwriting (non-fast-forward, destination
  exists, dirty worktree).

`update-ref` is the documented exception: its fatals exit `128` even for codes the
table lists at `129`.

## Warnings and pages

In JSON status, structured warnings use `data.warnings[]` with
`{code, message, source}`; text modes print them on stderr. A valid envelope
with partial results and warnings is not proof of a complete scan. A command
can finish its mutation and then return warning exit 9; inspect state before
retrying an apparently failed mutation.

Agent session/checkpoint/workspace and review/investigate listings use bounded
keyset pages. Round-trip `next_cursor` verbatim with the same command/filter
context and check `has_more` where provided. Operation history uses its own
page/index contract instead; do not generalize one cursor format to all lists.
