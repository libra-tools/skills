# Commit surface: signing, hooks, and message sources

## Signing is vault-backed, on by default, and has no `-S`

Signing is **enabled by default**: `libra init` sets `vault.signing=true`, so commits
are PGP-signed through the repository vault whenever an unseal key is available.
Signing does not require an external `gpg` process or agent, and `merge` /
`cherry-pick` reuse the signing chain.

- **`-S` / `--gpg-sign` are not exposed.** Passing them is a usage error, not a signed
  commit.
- `commit.gpgSign=true|false` is the Git-compatible override and beats `vault.signing`.
- `--no-gpg-sign` leaves one commit unsigned.
- Structured output reports `signed: true` when vault signing was enabled and the
  commit was signed.

The vault normally generates its own PGP key. Imported keys are also supported:
`libra config import-gpg-key` sets `vault.gpg.source=imported`; removal with
`libra config remove-gpg-key --force` returns to the generated key. These commands
handle sensitive key material; use the documented import workflow and do not log
the key or passphrase. Git's `user.signingkey` is not an external-keyring selector.

## Hooks are Libra-native

Repository hooks live in `.libra/hooks/*.sh|.ps1`, not `.git/hooks`. A commit runs the
full chain:

```
pre-commit → prepare-commit-msg → commit-msg → commit/ref update → post-commit
                                                      └─ post-rewrite (for --amend)
```

- `pre-commit` and the two message hooks are **blocking** — a non-zero exit refuses the
  commit.
- The post hooks are **advisory** — a failure is reported, not fatal.
- `--no-verify` skips every hook *and* message validation.
- `--disable-pre` skips only `pre-commit`; message and advisory hooks still run.
- Templates ship in the Libra source tree at `template/pre-commit.sh` /
  `template/pre-commit.ps1`.
- `am` runs the `applypatch-msg` / `pre-applypatch` / `post-applypatch` family through
  the same sandboxed runner.

**External-agent capture hooks are a separate surface.**
`libra agent enable --agent <claude-code|codex|opencode>` (alias `libra agent add`)
installs host-specific hooks/plugins. Codex updates both `$CODEX_HOME/hooks.json`
and managed trust entries in `config.toml`; OpenCode uses the managed project
plugin. Do not manually invoke hidden hook ingress as a substitute for a real
provider run. Gemini is uninstall-only. Inspect sessions/checkpoints and use
`libra agent doctor` for diagnosis.

## Message sources

Exactly one message source wins, in this order: `-m`, `-F <file>`, `-C`/`-c <commit>`,
`--fixup`/`--squash`, then `commit.template` / `-t <file>` seeding the editor.

- **Multiple `-m` flags are rejected** (`LBR-CLI-002`) — use one `-m` with newlines, or
  `-F <file>`.
- `-s` adds a single `Signed-off-by` trailer.
- `--conventional` validates the `<type>(<scope>): <summary>` form; a violation is
  `LBR-CLI-002` at exit 129.
- `--amend --no-edit` reuses the parent's message; it still rewrites the commit even
  when tree and message are unchanged.
- An explicitly configured editor can run without a TTY. When a message needs an
  editor and none is configured, the fallback `vi` requires an interactive terminal;
  otherwise the commit aborts. Supply `-m` or `-F` for unattended commits.

## `-a` is riskier than in Git

`-a` auto-stages every tracked modification *and deletion*, including out-of-band ones.
In a repo with other active agent sessions this bundles their work. Prefer explicit
`libra add <paths>`. `commit --dry-run -a` previews the auto-staged set under a bounded
preflight (32 MiB per object, 64 MiB charged aggregate, 4,096 unique objects) without
staging anything.
