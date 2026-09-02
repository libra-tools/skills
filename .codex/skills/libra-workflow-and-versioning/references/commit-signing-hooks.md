# Commit surface: signing, hooks, and message sources

## Signing is vault-backed, on by default, and has no `-S`

Signing is **enabled by default**: `libra init` sets `vault.signing=true`, so commits
are PGP-signed with the repository vault key (libvault, `.libra/vault.db`) whenever an
unseal key is available — *not* by an external `gpg` process. No GnuPG agent, keyring,
or `~/.gnupg` is involved, and `merge` / `cherry-pick` reuse the same chain.

- **`-S` / `--gpg-sign` are not exposed.** Passing them is a usage error, not a signed
  commit.
- `commit.gpgSign=true|false` is the Git-compatible override and beats `vault.signing`.
- `--no-gpg-sign` leaves one commit unsigned.
- Structured output reports `signed: true` when vault signing was enabled and the
  commit was signed.

Unlike Git — where signing needs `user.signingkey` + `gpg.program` + `commit.gpgSign`
and most developers skip it — a Libra repo signs from `init` onward with no setup.

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
installs them into the host's own config (`.claude/settings.json`,
`$CODEX_HOME/hooks.json`), and they call the hidden `libra hooks <provider> <event>`
entry point — never invoke that yourself. Gemini is uninstall-only. Inspect what was
captured with `libra agent session|checkpoint list` and `libra agent doctor`.

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
- With no message source and no TTY, the commit aborts rather than opening an editor.

## `-a` is riskier than in Git

`-a` auto-stages every tracked modification *and deletion*, including out-of-band ones.
In a repo with other active agent sessions this bundles their work. Prefer explicit
`libra add <paths>`. `commit --dry-run -a` previews the auto-staged set under a bounded
preflight (32 MiB per object, 64 MiB charged aggregate, 4,096 unique objects) without
staging anything.
