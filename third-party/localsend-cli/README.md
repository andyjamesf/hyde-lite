# localsend-cli (fork)

A fork of the official [LocalSend](https://github.com/localsend/localsend) CLI, kept here so the
Quickshell shells can shell out to a `receive` mode that upstream does not have.

## What this is

- Forked from `localsend/localsend` at tag `v1.19.0`, commit `44f48f18a5503c43873570ff489d27ff1983e198`.
- Only the Rust pieces are vendored: `cli/` (the `localsend-cli` crate) and `core/` (upstream's
  `packages/core`, renamed from the path it had there). The Flutter app, the `server` crate and the
  `packages/localsend_isolates` FFI bridge are not needed for a terminal client and were left out.
- License: Apache-2.0 (`LICENSE`, carried over unchanged). This repository is GPL-3.0; the two are
  compatible for a vendored, separately-built binary like this one.

## What was added on top of upstream

Upstream's CLI (`cli/src/main.rs`, `cli/src/app/headless.rs`) has a headless mode for `send --to`
only: while it runs, any incoming transfer request is declined, because receiving needs the
interactive Y/N/P prompt (`cli/src/app/receive.rs`). There is no flag to receive without a
terminal.

A new `receive` subcommand (`cli/src/app/receive_headless.rs`) fills that gap:

- No raw terminal mode, no keyboard thread — unlike the interactive mode, this one can be spawned
  with its stdout as a plain pipe (which is what a Quickshell `Process` gives it).
- A request from a device already paired (accepted with `P` in the interactive mode, which upstream
  already persists to `paired-v2.json`) and certificate-verified is auto-accepted, reusing the exact
  trust check the interactive mode uses (`storage.paired.contains(fingerprint)`). Every other
  request is declined, unless `--quick-save` is passed, which accepts everyone.
- One JSON object per line on stdout (`ready`, `incoming`, `file_done`, `session_done`,
  `server_stopped`) instead of the human-readable log lines the rest of the CLI prints, so a GUI can
  parse it instead of scraping text.

See `cli/src/app/receive_headless.rs` for the exact event shapes.

## Building

```sh
cd third-party/localsend-cli
cargo build --release -p localsend-cli
```

No Flutter, `fvm`, `cmake` or `ninja` needed — this is a plain Cargo workspace of two crates. The
resulting binary is `target/release/localsend-cli`; it is not currently installed anywhere by this
repository's own install script, only built on demand.

## Usage

```sh
# Send (unchanged from upstream, already scriptable):
localsend-cli send --to <alias-or-ip> <file>...

# New: receive in the background, no terminal needed.
localsend-cli receive                 # auto-accept only already-paired devices
localsend-cli receive --quick-save    # auto-accept everyone
```

Pairing a device still has to happen once, interactively (`localsend-cli` with no arguments, then
`P` on its first request) before `receive` will auto-accept it.

## Measured / NOT TESTED

- Measured 2026-11-26: `cargo build --release -p localsend-cli` succeeds standalone (no Flutter
  toolchain); `cargo test -p localsend-cli` passes all 64 tests (62 upstream + 2 new); `cargo fmt
  --check -p localsend-cli` is clean; `cargo clippy --release -p localsend-cli --all-targets
  --no-deps -- -D warnings` reports 0 findings in `receive_headless.rs` (6 pre-existing findings
  elsewhere in the vendored `receive.rs`/`send_task.rs` are a clippy-version mismatch with upstream,
  not introduced here, and were left alone). `localsend-cli receive` was run standalone on a
  throwaway port/config dir and printed a single `{"event":"ready",...}` line, then ran until
  killed — confirmed it starts without a TTY and without crashing.
- Measured 2026-11-26, end to end over loopback (one `send` instance and one `receive` instance on
  this machine, separate `XDG_CONFIG_HOME`/ports, real TLS handshake, no mocking): sending a text
  file and a 2 MiB random binary to `receive --quick-save` landed both at the destination directory,
  byte-identical (`sha256sum` match on the binary, `diff` clean on the text file); the receiver's
  JSON stream was `ready` → `incoming` (`accepted: true`) → `file_done` ×2 → `session_done`
  (`files_ok: 2, files_failed: 0, bytes: 2097232, cancelled: false`), matching what was actually
  sent. Restarting the receiver *without* `--quick-save` and repeating the send from the same
  (still unpaired) sender correctly declined: sender exited 1 and logged `Declined`, receiver logged
  `incoming` with `accepted: false`, and the destination directory stayed empty.
- **NOT TESTED**: the already-paired auto-accept branch specifically (pairing itself needs the
  interactive TUI's `P` keypress, which was not scripted here) — the two tests above exercise the
  same downstream accept/decline code paths `quick_save` and `paired` both feed into, so this is a
  narrow gap (the `paired` boolean itself), not the receive pipeline. Also not tested: a real second
  device (phone/another machine) over the actual LAN rather than loopback, and the Quickshell widget
  side, which does not exist yet.
