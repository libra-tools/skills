# AI-native and Libra-only commands

These have no Git equivalent; they are why Libra exists. `COMPATIBILITY.md` classes
them `intentionally-different`.

## The AI surface

### `libra code`

The primary collaborative-development surface. It launches the **Web Code UI**
(embedded HTTP server + AgentRuntime), prints the URL and control details, and stays
in the foreground until `Ctrl-C`.

```bash
libra code [-p 3000] [--host 127.0.0.1] [--provider <p>] [--model <m>] [--goal "..."]
libra code --resume <THREAD_ID>
libra code --control stdio            # JSON-RPC NDJSON automation client
```

- The legacy TUI, the `--web` / `--web-only` aliases, the `LIBRA_CODE_LEGACY_TUI` env,
  and the `code-control` shim were **removed in v0.20.0**; they now fail with a usage
  error plus a migration hint.
- `--control stdio` is the canonical automation path. It discovers the endpoint from
  `.libra/code/control.json`; `--control-url` / `--control-token-file` override.
- `--stdio` is a deprecated MCP-only tools/resources entry, not live turn control.
- Eight provider backends (Gemini, OpenAI, Anthropic, DeepSeek, Kimi, Zhipu, Ollama,
  Codex) and three contexts (dev, review, research). Review and research are read-only
  and get no network.
- Mutating tools require approval + sandbox + tool ACL; plan execution passes an
  explicit network-policy gate.

### `libra agent`

External-agent capture and its read-only inspection surface.

```bash
libra agent enable --agent <claude-code|codex|opencode>   # alias: agent add
libra agent disable --agent <name>                        # alias: agent remove
libra agent status | list | doctor [--repair] | clean [--all]
libra agent session <sub> | checkpoint <sub> | skill <sub> | workspace <sub>
libra --json agent graph <session>
libra agent import (--session <id> | --path <p> | --since <ts> | --all) --yes
libra agent push [--remote <name>]        # publish refs/libra/traces
libra agent bridge --stdio                # JSON-RPC 2.0 NDJSON ingress
```

Checkpoints are agent-run save points layered on top of commits. Captured sessions
and checkpoints live in `agent_session` / `agent_checkpoint` plus `refs/libra/traces`.

### `libra graph --json <thread-id>`

A Code thread's version graph: intent revisions → execution plans → tasks → runs →
patchsets. The graph TUI was removed in v0.20.0, so bare `libra graph <id>` is a usage
error; use `--json` / `--machine`, and `--repo <path>` for another repository.

### `libra review` / `libra investigate`

Read-only runs driven by external agent CLIs.

```bash
libra review --agent <slug>... [--since <rev>] [--checkpoint <id>] [--json]
libra review --fix
libra review list | show <run_id> | cancel <run_id> | clean | attach <run_id> <file>

libra investigate start --topic "<text>" --agent <slug>... [--max-turns <n>] [--quorum <n>]
libra investigate list | show <run_id> | continue <run_id> | cancel <run_id> | fix <run_id>
```

### The rest

| Command | What it does |
|---|---|
| `libra automation` | `list` / `run [--rule <id>] [--live]` / `history` for cron-style repository automation rules |
| `libra usage` | `report` / `prune [--retention-days <n>]` for AI provider and model usage and cost aggregates |
| `libra sandbox status` | Sandbox backend diagnostics (OS backend availability, downgrade warnings) |
| `libra service` | Headless local-only notification bus and dirty-mark ingestion: `run` / `status` / `events` |

## Working-tree extensions (Lore)

| Command | What it does |
|---|---|
| `libra layer` | A named, purely local overlay of files materialized on command that **never enters a commit** |
| `libra sparse-view` | A read-only sparse VIEW filter — deliberately *not* `sparse-checkout`: it never touches the working tree |
| `libra hydrate <path>...` | Materialize content on demand (whole-object; resolves local → alternate → remote, OID-verified, atomic rename) |
| `libra dirty` | Advisory dirty-set marks; `status --scan` / `--cached` / `--check-dirty` consume them |
| `libra lfs` | Built-in large-file storage via `.libra_attributes` — not Git LFS filters or hooks |
| `libra file obliterate` | Remove an object payload permanently |

## Libra's own skill system (different from this repo's format)

`libra code`'s agent runtime loads its own skills: **single `<name>.md` files with TOML
frontmatter** (`name`, `description`, `version`, `allowed-tools`), from `.libra/skills/`
(repository), then an overlay, then `~/.config/libra/skills/` (user), then a tier
embedded in the binary. `/skill <name>` dispatches one. That format is *not* the
directory-plus-`SKILL.md` Agent Skills standard this skill is written in, so a skill
installed for Claude Code / Codex / Gemini / opencode is **not** visible to
`libra code`, and vice versa.
