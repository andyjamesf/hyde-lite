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
  already persists to `paired-v2.json`, or with a `decision` line here — see below) and
  certificate-verified is auto-accepted, reusing the exact trust check the interactive mode uses
  (`storage.paired.contains(fingerprint)`). With `--quick-save`, every request is auto-accepted.
  Otherwise, a request from anyone else is held open (`incoming` with `decision: "pending"`) instead
  of declined on the spot: upstream's interactive mode asks a human on the terminal (Y/N/P); this
  mode asks whoever is reading its stdout, by waiting for a `decision` line on stdin —
  `{"session_id": "...", "decision": "accept" | "accept_and_pair" | "decline"}`. A pending request
  nobody answers within 60s is declined on its own (`timeout`); one whose sender disconnects first
  is reported as `aborted`.
- Every discovery event re-emits the full list of currently confirmed devices (`devices`), including
  ones that only ever contacted *us* (`ServerEventV2::Register` is wired to the same
  `discovery::device_confirmed` the interactive mode uses — easy to miss, since `headless::run`'s own
  send-only mode needs it for a different reason and this mode's first draft didn't call it at all).
  So a caller gets "available devices" for free, without running its own discovery.
- One JSON object per line on stdout (`ready`, `incoming`, `aborted`, `timeout`, `file_done`,
  `session_done`, `devices`, `server_stopped`) instead of the human-readable log lines the rest of
  the CLI prints, so a GUI can parse it instead of scraping text.

See `cli/src/app/receive_headless.rs` for the exact event and decision shapes.

## Building

```sh
cd third-party/localsend-cli
cargo build --release -p localsend-cli
```

No Flutter, `fvm`, `cmake` or `ninja` needed — this is a plain Cargo workspace of two crates. The
resulting binary is `target/release/localsend-cli`.

The repository's `install.sh` (so `hyde-lite update` too) runs `tools/build_localsend.sh`, which installs it as
`~/.local/bin/localsend-cli`. It builds only when this source changed or the binary is missing, installs `rust`
with `pacman` only when there is no `cargo`, and removes the build directory afterwards. To build it again by
hand, delete `~/.local/state/hyde-lite/localsend-cli.source` and run the script.

## Usage

```sh
# Send (unchanged from upstream, already scriptable):
localsend-cli send --to <alias-or-ip> <file>...

# New: receive in the background, no terminal needed.
localsend-cli receive                 # auto-accept paired devices; others wait for a decision
localsend-cli receive --quick-save    # auto-accept everyone, no pending/decisions at all
```

Pairing a device so it is auto-accepted by `receive` can happen two ways: once, interactively
(`localsend-cli` with no arguments, then `P` on its first request), or by answering a pending
request from `receive` with `{"session_id": "...", "decision": "accept_and_pair"}` on its stdin.
A request from an unpaired device otherwise waits (`incoming` with `decision: "pending"`) for a
`decision` line — `accept`, `accept_and_pair` or `decline` — or 60 seconds, whichever comes first.

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
- Measured 2026-11-26, the pending-decision protocol over loopback (a fifo opened read-write on an
  extra fd so the receiver's stdin never saw EOF, decisions written to it from a separate shell
  while the receiver kept running): an unpaired sender's request came through as `incoming` with
  `decision: "pending"` and was *not* auto-declined; writing `{"session_id": "...", "decision":
  "accept"}` to the fifo made it go through exactly like an auto-accept (`file_done` → `session_done`,
  file landed byte-identical); a second request answered with `"decision": "decline"` was declined
  (sender logged `Declined`, nothing new in the destination directory). The `devices` event was also
  observed live: it listed the real sender by alias, host and fingerprint, confirming the
  `Register` → `device_confirmed` wiring above actually fires.
- Also observed live, worth knowing rather than hiding: `send --to <IP>` always probes the fixed
  default port (53317) directly, in addition to whatever discovery finds — so `--to 127.0.0.1`
  on a machine already running a receiver on the default port reaches *that* one, not a test
  instance on another port. Target a non-default-port test instance by alias, not IP, or it can
  silently hit the wrong receiver (it did here, once, harmlessly: the real deployed receiver just
  declined the unpaired test sender, exactly as it should).
- **NOT TESTED**: the already-paired auto-accept branch specifically (pairing itself needs the
  interactive TUI's `P` keypress, which was not scripted here) — it feeds into the same accept code
  path `quick_save` and a stdin `"accept"` decision both already exercised, so this is a narrow gap
  (the `paired` boolean itself), not the receive pipeline. Also not tested: the 60s timeout firing
  for real (it reuses the same decline call already tested, just time-triggered, so this was reasoned
  through rather than run), `accept_and_pair` actually writing `paired-v2.json`, a real second device
  (phone/another machine) over the actual LAN rather than loopback, and the Quickshell widget's own
  handling of `pending`/`devices` (see `Configs/.config/quickshell/shared/services/LocalSend.qml`
  for what's wired up so far).
