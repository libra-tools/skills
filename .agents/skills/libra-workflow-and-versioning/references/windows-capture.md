# Native Windows Session Capture: local implementation

This reference describes the Windows implementation being developed on top of
`libra-tools/libra` commit `f306cc9` (package version 0.30.49), checked on
2026-10-15. The implementation is proposed in
[Libra PR #632](https://github.com/libra-tools/libra/pull/632) and remains unmerged
and unreleased. Neither the version number nor an upstream release alone
establishes Windows capture support. Use a
binary built from the changed source and inspect its own command help. The
parent skill's 0.30.49 version anchor covers the upstream command contracts;
it does not establish that these Windows changes have been released.

Use this reference for this Windows implementation and its verification. Do not
apply the old Code UI or native-skill bridge instructions in the other reference
to this build: the `code`, `code-control`, `graph`, `usage`, `publish` and `db`
top-level commands were removed in the 0.23.0 breaking release. External-agent
capture uses `libra agent`; repository backup uses `libra cloud`. The nested
`libra --json agent graph <session>` remains a different command.

## Build on Windows

Use the native `x86_64-pc-windows-gnu` Rust host, PowerShell and Windows tools;
WSL is not involved. The local handoff provides an external `toolchain/build.ps1`
and its build log; this script is not an upstream Libra build asset. Set its
source and toolchain paths for the machine before running it.

The working toolchain consists of Rust/Cargo, MSYS2 Perl/make/sh, w64devkit GCC
16.2/make/cmake/ninja, NASM, Windows libclang, and matching Clang builtin plus
MinGW system headers for bindgen. In the build process:

- Put MSYS2's `usr/bin` first on PATH, then w64devkit's `bin`, NASM and Cargo.
  Remove Strawberry Perl from that process's PATH: vendored OpenSSL's Configure
  requires the MSYS-style Perl for this setup.
- Set `CC=gcc`, `CXX=g++`, `AR=ar`, `LIBCLANG_PATH` to the directory containing
  the Windows `libclang.dll`, and bindgen's target/include paths to the matching
  Windows GNU headers. A missing `stddef.h` is a header configuration failure.
- Keep libvault's default OpenSSL dependency enabled. Disabling it does not
  complete this build. Preserve successful native dependency artifacts between
  retries; OpenSSL can take many minutes to compile.
- The handoff observed transient `os error 4551`; rerun the same build for that
  specific failure. Repeated policy failures need diagnosis rather than broad
  security-policy changes.

Run the configured local script in PowerShell and inspect both its exit code and
log. Use the resulting `target/debug/libra.exe` (or the selected profile's binary)
by absolute path, so an older installed Libra shim cannot satisfy the check.
Do not infer Unix build compatibility from a successful Windows build; check
Unix separately when a native Unix runner is available.

## OpenCode 2.x and trusted executable setup

Use the official Windows CLI archive:
<https://opencode.ai/update/api/latest/cli/opencode/opencode-windows-x64.zip>.
The CLI used for this work is **v2.0.29**. Verify the extracted executable's
version; the GitHub 1.19.0 CLI is OpenCode 1 and its plugin API is incompatible.
Place the user's configured provider/model settings at
`%USERPROFILE%\.config\opencode\opencode.json`, preserving existing credentials
and settings. Keep credential values out of logs and the repository.

Trust is explicit and distinct from hook installation. The executable directory
must not grant write access to unrelated users. A normally extracted directory
can inherit a `Users` or `Authenticated Users` Modify ACE and therefore fail the
trust check even though it is under the current user's profile. Inspect the ACL;
use a new dedicated directory protected for the current user and SYSTEM, then
copy the verified executable into it. Do not weaken the trust check or change
permissions recursively on a shared directory to make the command pass.

The OpenCode binary used for the run must be the same one registered with
`rpc trust`. Put that protected directory first on the verification process's
PATH and retain the explicit executable path for the run. Exporter trust resolves
`opencode.exe` from registered trusted directories, not from arbitrary PATH
entries. Replacing or updating that executable requires explicit trust renewal.

## Verify a real captured transcript

Use a new local NTFS demo directory. Choose an available provider/model from the
user's OpenCode configuration. In PowerShell, set the paths and model explicitly:

```powershell
$LibraExe = 'C:\path\to\libra-win\target\debug\libra.exe'
$OpenCodeDir = 'C:\path\to\protected-opencode2'
$OpenCodeExe = Join-Path $OpenCodeDir 'opencode.exe'
$Model = 'provider/model'
$env:PATH = "$OpenCodeDir;$(Split-Path $LibraExe);$env:PATH"

& $OpenCodeExe --version
& $LibraExe init
& $LibraExe agent add opencode
& $LibraExe agent rpc trust --dir $OpenCodeDir
& $LibraExe agent rpc trust opencode
& $OpenCodeExe run --standalone --model $Model 'Reply with a short greeting.'
& $LibraExe agent session list
& $LibraExe agent checkpoint list
```

Stop on a nonzero exit code at each step. Select the checkpoint produced by this
run and export it with the same binary:

```powershell
$CheckpointId = 'id-from-checkpoint-list'
& $LibraExe agent checkpoint export $CheckpointId
```

Acceptance requires actual user and assistant transcript content in the export,
not just an installed plugin, a session row, a checkpoint identifier, an exit
code, or a nonzero-sized metadata envelope. Keep the exported JSONL as evidence
and record the Libra source state, OpenCode version and commands used. The
default export is redacted. Raw export has a separate explicit authorization
and audit path; it is unnecessary for this acceptance check.

If no transcript appears, first check the run's exit status, the installed
OpenCode 2 plugin, exporter trust/capabilities and the exact executable paths.
Do not substitute a WSL transcript or manually fabricate a checkpoint as proof.

## Windows security boundary and limits

This local implementation opens capture storage using no-follow Windows handles
and rejects reparse points/junctions, alternate streams, device aliases and UNC
capture storage. Private keys use protected current-user/SYSTEM ACLs, locking and
atomic no-replace publication through native directory-handle APIs. Unprotected
inherited ACLs are rejected; do not repair authentication failures by deleting a
key.

The Windows OpenCode exporter runs **without an OS filesystem or network
sandbox**. It runs only an explicitly trusted executable after checking its bytes
and file identity and holding it against replacement. A kill-on-close Windows
Job Object contains the process tree; the exporter has a 30-second deadline and
a 16 MiB accepted output limit. Output uses a protected temporary file. These
controls do not restrict a trusted process's filesystem/network access.
Windows has no Unix `RLIMIT_FSIZE` write-time limit here, so temporary output may
briefly exceed the accepted limit between size checks. Ambient credential
variables are cleared for the exporter; the interactive OpenCode run still uses
the user's configured model credentials.

Linux bubblewrap and macOS Seatbelt behavior must remain unchanged. Do not relax
the shared Required sandbox policy to make the Windows exporter work. This local
Windows verification does not establish support for every provider, filesystem,
historical import mode, or native reasoning archive.

Checkpoint listing and ordinary transcript export are available. Owner-only raw
reasoning-artifact file export and the object/findings scans in `libra agent
doctor` remain unavailable on Windows. Doctor reports those scans as unavailable,
does not claim a complete scan, and applies no repairs to them.

## Local validation recorded on 2026-10-15

An earlier unmerged native Windows build completed a real OpenCode **2.0.29** run.
Session `opencode__ses_ec23388e1ffe976p6aDB5ovuiV` produced checkpoint
`9bca2f55-054f-52dd-9ef8-5b32541c46d0`. Its redacted JSONL export was **1,867
bytes** and contained the user's prompt plus assistant text
`Native Windows capture works.` The operator retained it as
`windows-capture-demo-20261015/opencode-session-export.jsonl` outside the source
checkout. This remains evidence for that local development build. A fresh real
OpenCode run of the final hardened implementation is still pending.

Subsequent focused validation passed nine Windows primitive tests, including
rejection of unprotected inherited ACLs, and the UTF-16 scope wire test. A
separate Unix build also passed: Ubuntu-24.04 under WSL, Rust 1.98.1,
`cargo build -j 2`, completing in 16 minutes 30 seconds. On that Unix runner,
`cargo clippy --all-targets --all-features -- -D warnings` also passed. WSL was
used only for these independent Unix compatibility checks; the Windows
executable was compiled natively. The full test suite, final hardened Windows
build and fresh real OpenCode acceptance run are still pending.

These local checks do not imply an upstream release, support for additional
providers, or native reasoning archival capability.
