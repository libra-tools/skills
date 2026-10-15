# Remotes, cloud backup and Git interchange

## Push

```bash
libra push origin topic
libra push --dry-run origin topic:main
libra push --tags origin
libra push --delete origin <branch>
```

Local-path and `file://` push targets are supported in 0.30.49, including local
Libra and Git repositories. Ref updates retain non-fast-forward and checked-out
non-bare target protections. A configured local upstream with
`branch.<name>.remote=.` remains unsupported for implicit push; choose an explicit
supported remote/target. Do not use a blanket force or mirror to bypass refusal.
`--mirror` can delete remote-only branches/tags; preview and authorize that scope.

`remote update` uses nonempty `remotes.default`, otherwise all remotes. Remote
rename migrates remote configuration, refspecs, upstreams, tracking refs and
associated metadata. SSH host identity follows the documented policy; `ask`
lets OpenSSH configuration govern, while headless contexts use BatchMode and
fail instead of prompting. Do not disable host checks to fix authentication.

## D1/R2 cloud backup and restore

```bash
libra cloud status
libra cloud sync
libra cloud sync --force
libra cloud restore --repo-id <id>
libra cloud restore --name <name> --metadata-only
```

D1 holds the index and metadata; R2 holds objects. Sync reconciles local loose
and packed objects with the index, repairs missing D1 registrations and uses
`--force` to re-upload after R2-side loss. It is a backup surface, not the removed
public Worker hosting/publishing product. Restore into a deliberate destination;
it restores refs and normally populates the working tree.

Required D1 keys are `LIBRA_D1_ACCOUNT_ID`, `LIBRA_D1_API_TOKEN` and
`LIBRA_D1_DATABASE_ID`. Full restore/sync also needs `LIBRA_STORAGE_ENDPOINT`,
`LIBRA_STORAGE_BUCKET`, `LIBRA_STORAGE_ACCESS_KEY`, `LIBRA_STORAGE_SECRET_KEY`
and normally region `auto` via `LIBRA_STORAGE_REGION`. Values resolve from
repo-local vault entries, global vault entries, then process environment.
Never print values while diagnosing missing configuration.

Configuration compatibility is role-scoped. A required GlobalConfig/SystemConfig
store with a future configuration schema or unsupported migration receipt fails
with `LBR-CONFIG-001`; known repository-only receipts do not make it future.
The current global DB defaults to the XDG configuration directory
(`~/.config/libra/config.db`), with a legacy `~/.libra/config.db` fallback and
`LIBRA_CONFIG_GLOBAL_DB` override. Do not delete or rewrite receipts as repair.
Use offline/local read policy only when local-only object access is intended;
it does not perform a remote backup.

## Object-format boundaries

SHA-1 is the default; `init --object-format sha256` and `init --object-format
blake3` select alternatives. BLAKE3 is a Libra extension, not a Git object
format. Match source, destination and transport capabilities instead of inferring
the algorithm from a 64-hex object id: SHA-256 and BLAKE3 have the same width.

Cloud backup persists `core.objectformat` as authoritative metadata. An older
backup without that metadata and with 64-hex ids fails closed; resync from a
compatible source binary instead of guessing. Keep a consistent SQLite backup
before schema upgrades; replacing the binary is not a database rollback.

## Git interchange

```bash
libra bundle create repo.bundle --all
libra bundle verify repo.bundle
libra bundle list-heads repo.bundle
libra bundle unbundle repo.bundle
libra fast-export --all
```

Use matching object formats. System Git cannot consume BLAKE3 bundles. Bundle
unbundle validates and installs objects but deliberately does not update refs.
For standard compatible formats, push/bundle/fast-export provide interchange;
raw Git cannot read SQLite-backed `.libra` refs. A separate `.git` checkout
is a different layout and should use its actual repository workflow.
