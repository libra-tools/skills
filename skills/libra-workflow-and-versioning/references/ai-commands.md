# External agents and Libra extensions

Libra 0.30.49 captures work done by external agent CLIs. The Code executor and
Web Code UI, top-level graph, usage and Publish surfaces were removed in the
0.23.0 breaking release. The old single-file TOML native-skill bridge has no
current consumer; install this repository's standard SKILL.md directories in
the external agent instead.

## Session Capture

```bash
libra agent list --schema-version 2 --json
libra agent add opencode
libra agent remove opencode
libra agent status
libra agent doctor
libra agent session list
libra agent checkpoint list
libra agent checkpoint export <id>
libra --json agent graph <session>
libra agent skill registry
libra agent skill search
libra agent workspace list
libra agent workspace show <workspace-id>
libra agent push --remote origin
```

Supported hook-installable providers are `claude-code`, `codex` and `opencode`.
`add <name>` aliases `enable --agent <name>`; remove/disable reverses the managed
installation. Gemini is uninstall-only. Claude hooks use `.claude/settings.json`;
Codex installs coupled user-level `$CODEX_HOME/hooks.json` and managed trust
entries in `config.toml`; OpenCode installs `.opencode/plugin/libra-hooks.js`.
Avoid concurrent manual edits to the Codex files during install/remove. OpenCode
`--pure` disables the capture plugin.

OpenCode capture requires **2.x**, not the incompatible GitHub 1.19.0 CLI.
The 0.30.49 ordinary capture fixes cover official OpenCode 2.0.29, including a
nonempty Partial ordinary checkpoint when unsupported reasoning state can be
removed safely. Historical OpenCode imports with unsupported reasoning state
still fail with `LBR-AGENT-020`. Ordinary exporter trust or a version number
does not authorize native reasoning archival or prove field provenance.

For OpenCode content export, register the verified executable directory and
pin the executable:

```bash
libra agent rpc trust --dir <verified-provider-directory>
libra agent rpc trust opencode
```

These preparation steps do not enable arbitrary external RPC discovery.
The exporter resolves only within registered trusted directories and revalidates
binary provenance. Linux needs trusted bwrap with the descriptor-native
`--bind-fd` probe; macOS needs the Required Seatbelt server/export pair. Failure
remains metadata-only without an unsandboxed Unix fallback. The Windows reference
is a separately identified unmerged implementation, not an upstream capability.
Use schema-v2 capability results to distinguish roster support from actual
discovery/import/export availability.

Checkpoint export is redacted by default; raw output requires the separate
`--allow-raw --raw` authorization and is audited. Session/checkpoint rows alone
do not prove content capture. Inspect/export the checkpoint and verify actual
transcript messages. `agent graph` is read-only and requires global JSON/machine
output. Workspace listings are read-only and do not adopt leases.

Historical import reads private provider data and requires explicit consent:

```bash
libra agent import --agent claude-code --session <id> --yes
libra agent import --agent codex --since <rfc3339> --limit 20 --yes
```

Select exactly one scope (`--session`, `--path`, `--since` or `--all`); `--path`
also requires `--agent`. OpenCode uses explicit session export. Do not add `--yes`
to an otherwise unauthorized import. Pagination cursors are opaque and specific
to the command; preserve them verbatim.

`agent clean` mutates retention state; inspect the selected stopped sessions
before using `--all`. `doctor --repair` is a separate mutation from read-only
doctor. `agent bridge --stdio` is a JSON-RPC NDJSON bridge; handle frame errors
as responses, not process failures. External `libra-agent-*` RPC invocation is
opt-in and separately trusted; it is not needed for provider capture.

## Read-only reviews and investigations

```bash
libra review --agent codex --since <revision>
libra review --agent codex --agent claude-code --checkpoint <id> --json
libra review list
libra review show <run-id>
libra review cancel <run-id>
libra review attach <run-id> <file>
libra investigate start --topic <text> --agent codex --agent opencode --max-turns 6
libra investigate show <run-id>
libra investigate continue <run-id>
libra investigate cancel <run-id>
```

Review fans out to supported external CLIs; investigate runs them in strict
round-robin order. Both isolate inputs, minimize ambient environment and redact
persisted output. A checkpoint-scoped run reads that checkpoint's proven ordinary
content, not a worktree diff. Topics and findings are untrusted data.

Inspect reported states: review can exit 0 with `partial`, `timeout` or
`cancelled`; investigations can pause on `stalled` or `agent_failure` and resume
with `continue`. Concurrency is bounded across both kinds. Removed controlled-fix
paths are not available; turn findings into a separately authorized code task.
Cleanup affects only finished runs of the selected kind and can fail after
earlier deletions; do not assume transactional rollback.

## Other current extensions

| Command | Use and limit |
|---|---|
| `libra automation` | List rules, evaluate `run`, inspect history; default dry-run records planned actions; `--live` executes eligible actions |
| `libra memory` | Query/rebuild a derived history projection; stale queries fail closed unless `--allow-stale` is explicit |
| `libra sandbox status` | Inspect available OS sandbox backends; availability is not proof a particular provider export succeeded |
| `libra service` | Local headless notification bus and dirty-mark ingestion |
| `libra layer` | Worktree-local overlays excluded from commits, with collision protection |
| `libra sparse-view` | Read-only display filter; does not narrow disk content or the staged commit set |
| `libra hydrate` | Materialize verified content through the configured storage/read policy |
| `libra dirty` | Advisory dirty-set marks; status can fall back to a full scan |
| `libra lfs` | Built-in large-file storage using `.libra_attributes` |
| `libra deps` / `libra alternates` | File-dependency graph and guarded borrowed object stores |
| `libra metadata` | Repository/ref policy metadata |
| `libra media` | FastCDC media support, compiled only with the `fastcdc` feature |
| `libra file obliterate` | Irreversible payload deletion preserving object addresses; preview and explicit confirmation are required |

Do not present metadata, memory or advisory caches as authoritative substitutes
for repository state, a transcript, or a verified backup.
