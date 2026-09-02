# Remotes, cloud backup, and publishing

Libra's tiered storage and cloud paths replace ad-hoc remotes for backup and sharing.

## Push

```bash
libra push origin feature/task-creation      # branch/tag update
libra push origin <branch>:main              # fast-forward another ref
libra push origin --tags | --mirror
libra push origin --delete <branch>
```

- Pushing to a **local `file://` remote is intentionally rejected**.
- `remote update` uses a non-empty `remotes.default` when invoked with no names, then
  falls back to all remotes.
- `remote rename` transactionally migrates remote config, refspec destinations, branch
  upstreams, SSH keys, tracking refs, remote HEAD, and matching reflogs.
- SSH host-key handling matches Git: the default `ask` mode passes no
  `StrictHostKeyChecking` option, so `~/.ssh/config` governs and OpenSSH can prompt on
  first connection. Headless contexts get `BatchMode=yes` and fail fast.
  `ssh.strictHostKeyChecking` / `LIBRA_SSH_STRICT_HOST_KEY_CHECKING` accept
  `ask` / `yes` / `accept-new` / `no`.

## Cloud backup and restore (Cloudflare D1 + R2)

```bash
libra cloud sync [--force] [--batch-size <n>]   # incremental; --force re-syncs all
libra cloud status [--verbose]
libra cloud restore (--repo-id <id> | --name <name>) [--metadata-only]
```

D1 holds the object index and metadata; R2 holds the objects. Sync tracks uploads with
an `is_synced` flag in `object_index` and reconciles `.libra/objects` first, so older
loose or packed objects are not skipped. `--force` is the recovery path for R2-side
data loss. Each repository is identified by `libra.repoid`, optionally with a readable
`cloud.name`.

Cloud backup needs `LIBRA_D1_*`; tiered S3/R2 object storage needs `LIBRA_STORAGE_*`.
If the global config DB (`~/.libra/config.db`) has a newer schema than the binary,
cloud commands fail closed with `LBR-CONFIG-001` instead of silently falling back to
local objects — use `libra --offline cloud ...` only when local-only access is
intended.

## Publishing (read-only Cloudflare Worker)

```bash
libra publish init                 # materialize the Worker template under worker/
libra publish status               # missing | current | modified | outdated | conflicted
libra publish sync [--dry-run]     # code snapshot + redacted AI artifacts to R2/D1
libra publish deploy
libra publish unpublish
```

The manifest lives in the repository's COMMON storage, so `init` / `status` / `deploy` /
`unpublish` read the same manifest from every worktree, while `worker/` itself is
tracked per-worktree content.

## Interchange with Git

```bash
libra bundle create repo.bundle --all        # Git v2 bundle; `git clone repo.bundle` works
libra bundle verify | list-heads | unbundle
libra fast-export --all                      # pipe into `git fast-import`
```

`.libra/objects` is a standard Git object store, but `config`, `HEAD`, `refs`, and
`reflog` are SQLite rows — so plain `git` commands do not work against a `.libra`
directory. Use `push`, `bundle`, or `fast-export` to move history to Git.
