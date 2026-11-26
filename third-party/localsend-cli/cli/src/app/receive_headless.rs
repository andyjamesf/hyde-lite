//! The `receive` mode: a long-running listener with no terminal UI, meant to
//! be spawned by another program (e.g. a desktop shell widget) and parsed
//! from its stdout instead of watched on screen.
//!
//! A request from a device already paired (accepted with P in the
//! interactive mode, or with a `decision` line here) and
//! certificate-verified is accepted automatically, exactly like the
//! interactive mode's own auto-accept path (`receive::handle_server_event`).
//! With `quick_save` set, every request is accepted automatically. Anyone
//! else is held as a pending request (emitted as `incoming` with
//! `decision: "pending"`) until a decision arrives on stdin, one JSON object
//! per line: `{"session_id": "...", "decision": "accept" | "accept_and_pair"
//! | "decline"}`. A pending request nobody answers within
//! [`DECISION_TIMEOUT`] is declined on its own (`timeout`).
//!
//! Also unlike the interactive mode, discovery is not just for `send`: every
//! discovery event re-emits the full list of currently confirmed devices
//! (`devices`), so a caller can show "available devices" without running
//! its own discovery.
//!
//! One JSON object per line is printed to stdout for every event; nothing
//! else is written there. Fatal errors go to stderr, like the rest of the
//! CLI.

use super::{Network, discovery as discovery_app, start_network, stop_network};
use crate::storage::{PairedChannel, Repository};
use crate::util;
use localsend::discovery::DiscoveryHandle;
use localsend::http::server::common::save::FileUploadTarget;
use localsend::http::server::v2::{PrepareUploadDecisionV2, ServerEventV2, SessionEndReasonV2};
use localsend::model::transfer::FileDto;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::sync::{mpsc, oneshot};

/// How long an unanswered pending request waits before it is declined on its
/// own. Our own `send` has no client-side timeout of its own (passes `None`
/// to reqwest), so this is our own choice, not a measured protocol limit;
/// the official app's sender was not checked.
const DECISION_TIMEOUT: Duration = Duration::from_secs(60);

/// A session whose `PrepareUpload` was accepted: tracked only for the
/// `session_done` summary, not for live progress.
struct Session {
    alias: String,
    files: HashMap<String, FileDto>,
    finished: usize,
    failed: usize,
    finalized_bytes: u64,
    in_progress: usize,

    /// Set once the server reports the session's own end. The summary is
    /// deferred until every in-flight `file_done` has also arrived, so this
    /// can be `Some` for a while before the session is actually reported.
    ended: Option<SessionEndReasonV2>,
}

/// A `PrepareUpload` request that was neither auto-accepted (quick-save) nor
/// auto-paired, waiting for a `decision` line.
struct PendingRequest {
    alias: String,
    /// Only a verified sender may be paired (same rule as the interactive
    /// mode's own `Answer::AcceptAndPair`).
    verified: bool,
    fingerprint: String,
    files: HashMap<String, FileDto>,
    decision_tx: oneshot::Sender<PrepareUploadDecisionV2>,
    since: Instant,
}

/// One entry of a `devices` snapshot.
#[derive(Serialize)]
struct DeviceJson {
    alias: String,
    host: String,
    port: u16,
    fingerprint: String,
    paired: bool,
}

/// A decision line read from stdin.
#[derive(Deserialize)]
struct Decision {
    session_id: String,
    /// "accept" | "accept_and_pair" | "decline"
    decision: String,
}

/// One line of structured output. `event` is the JSON tag (`#[serde(tag)]`
/// below), so every variant becomes `{"event": "...", ...other fields}`.
#[derive(Serialize)]
#[serde(tag = "event", rename_all = "snake_case")]
enum Event<'a> {
    /// Printed once, right after the server and discovery started.
    Ready { alias: &'a str, port: u16 },

    /// A `PrepareUpload` request was answered, or is waiting to be
    /// (`decision: "pending"` — see the module doc for the stdin protocol).
    Incoming {
        session_id: &'a str,
        alias: &'a str,
        verified: bool,
        paired: bool,
        file_count: usize,
        total_bytes: u64,
        decision: &'a str,
    },

    /// A pending request's sender disconnected before a decision arrived.
    Aborted { session_id: &'a str },

    /// A pending request nobody answered within [`DECISION_TIMEOUT`]; it was
    /// declined on its own.
    Timeout { session_id: &'a str },

    /// One file of an accepted session reached a final state.
    FileDone {
        session_id: &'a str,
        file_name: &'a str,
        ok: bool,
        error: Option<&'a str>,
    },

    /// An accepted session ended (every file reached a final state and the
    /// server reported the session's own end).
    SessionDone {
        session_id: &'a str,
        alias: &'a str,
        files_ok: usize,
        files_failed: usize,
        bytes: u64,
        cancelled: bool,
    },

    /// Every currently confirmed device, replacing any previous snapshot
    /// (not a diff): simpler to reason about from a caller that just wants
    /// to show "available devices".
    Devices { devices: &'a [DeviceJson] },

    /// The HTTP server stopped itself and will not receive anything further
    /// until the process is restarted.
    ServerStopped { error: &'a str },
}

fn emit(event: &Event) {
    match serde_json::to_string(event) {
        Ok(line) => println!("{line}"),
        // A Rust-internal type failing to serialize is a bug here, not a
        // runtime condition to recover from.
        Err(err) => eprintln!("receive: could not encode an event: {err}"),
    }
}

/// A file upload finishing is reported back on this channel, mirroring how
/// the interactive mode's own `AppEvent::ReceiveFileResult` works, but kept
/// local: this mode has no other event kind that needs a shared enum.
struct FileDone {
    session_id: String,
    file_id: String,
    result: Result<(), String>,
}

pub(super) async fn run(mut storage: Repository, quick_save: bool) -> anyhow::Result<()> {
    let identity = storage.identity.clone();
    let Network {
        server,
        server_stop_tx,
        server_tx: _,
        mut server_rx,
        discovery,
        mut discovery_rx,
        discovery_stop_tx,
    } = start_network(&identity).await?;

    emit(&Event::Ready {
        alias: &identity.alias,
        port: identity.port,
    });

    let mut sessions: HashMap<String, Session> = HashMap::new();
    let mut pending: HashMap<String, PendingRequest> = HashMap::new();
    let (file_done_tx, mut file_done_rx) = mpsc::channel::<FileDone>(64);
    let (line_tx, mut line_rx) = mpsc::channel::<String>(16);

    // Stdin is read on its own task: `tokio::io::stdin()` is a blocking
    // handle under the hood, and the main loop must not block on it.
    tokio::spawn(async move {
        let mut lines = BufReader::new(tokio::io::stdin()).lines();
        while let Ok(Some(line)) = lines.next_line().await {
            if line_tx.send(line).await.is_err() {
                break;
            }
        }
    });

    let mut tick = tokio::time::interval(Duration::from_millis(500));
    tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    loop {
        tokio::select! {
            Some(event) = server_rx.recv() => {
                if handle_server_event(
                    &storage,
                    &discovery,
                    quick_save,
                    &mut sessions,
                    &mut pending,
                    &file_done_tx,
                    event,
                ) {
                    break;
                }
            }
            Some(_) = discovery_rx.recv() => emit_devices(&discovery, &storage),
            Some(done) = file_done_rx.recv() => handle_file_done(&mut sessions, done),
            Some(line) = line_rx.recv() => {
                handle_decision(&mut storage, &discovery, &mut pending, &mut sessions, &line);
            }
            _ = tick.tick() => expire_pending(&mut pending),
        }
    }

    stop_network(&server, Some(server_stop_tx), &discovery, discovery_stop_tx).await;
    Ok(())
}

/// Handles one server event; returns `true` when the server stopped itself
/// and the loop should end (the process then exits, matching `headless::run`
/// ending the process on the condition it was started for).
fn handle_server_event(
    storage: &Repository,
    discovery: &Arc<DiscoveryHandle>,
    quick_save: bool,
    sessions: &mut HashMap<String, Session>,
    pending: &mut HashMap<String, PendingRequest>,
    file_done_tx: &mpsc::Sender<FileDone>,
    event: ServerEventV2,
) -> bool {
    match event {
        // So a device that only ever contacts us (never dialed by us) still
        // enters the store `emit_devices` reads from.
        ServerEventV2::Register { ip, info } => {
            discovery_app::device_confirmed(
                discovery,
                &storage.identity.fingerprint,
                ip.to_string(),
                info,
            );
        }
        ServerEventV2::PrepareUpload {
            session_id,
            info,
            sender_fingerprint,
            files,
            decision_tx,
            ..
        } => {
            if decision_tx.is_closed() {
                return false;
            }
            let verified = sender_fingerprint.is_some();
            let fingerprint = sender_fingerprint.unwrap_or_else(|| info.fingerprint.clone());
            let paired = verified && storage.paired.contains(&fingerprint);
            let total_bytes: u64 = files.values().map(|file| file.size).sum();

            if quick_save || paired {
                emit(&Event::Incoming {
                    session_id: &session_id,
                    alias: &info.alias,
                    verified,
                    paired,
                    file_count: files.len(),
                    total_bytes,
                    decision: "accepted",
                });
                let ids = files.keys().cloned().collect();
                if decision_tx
                    .send(PrepareUploadDecisionV2::Accept(ids))
                    .is_ok()
                {
                    sessions.insert(
                        session_id,
                        Session {
                            alias: info.alias,
                            files,
                            finished: 0,
                            failed: 0,
                            finalized_bytes: 0,
                            in_progress: 0,
                            ended: None,
                        },
                    );
                }
            } else {
                emit(&Event::Incoming {
                    session_id: &session_id,
                    alias: &info.alias,
                    verified,
                    paired,
                    file_count: files.len(),
                    total_bytes,
                    decision: "pending",
                });
                pending.insert(
                    session_id,
                    PendingRequest {
                        alias: info.alias,
                        verified,
                        fingerprint,
                        files,
                        decision_tx,
                        since: Instant::now(),
                    },
                );
            }
        }
        ServerEventV2::FileUpload {
            session_id,
            file_id,
            file,
            target_tx,
        } => {
            let Some(session) = sessions.get_mut(&session_id) else {
                // Unknown session: dropping the responder fails the request.
                return false;
            };
            session.in_progress += 1;
            let path = util::unique_path(&storage.destination, &file.file_name);
            let (result_tx, result_rx) = oneshot::channel::<Result<(), String>>();
            tokio::spawn({
                let file_done_tx = file_done_tx.clone();
                async move {
                    let result = match result_rx.await {
                        Ok(result) => result,
                        Err(_) => Err("Upload aborted".to_string()),
                    };
                    let _ = file_done_tx
                        .send(FileDone {
                            session_id,
                            file_id,
                            result,
                        })
                        .await;
                }
            });
            let _ = target_tx.send(FileUploadTarget::Path {
                path,
                result_tx,
                // No live progress in this mode: only `file_done` /
                // `session_done` are reported.
                progress_tx: None,
            });
        }
        ServerEventV2::SessionEnd { session_id, reason } => {
            if let Some(session) = sessions.get_mut(&session_id) {
                session.ended = Some(reason);
            }
            finish_if_done(sessions, &session_id);
        }
        ServerEventV2::PrepareUploadAborted { session_id } => {
            if pending.remove(&session_id).is_some() {
                emit(&Event::Aborted {
                    session_id: &session_id,
                });
            }
        }
        ServerEventV2::CancelReceived { .. } => {}
        ServerEventV2::ListenerFailed { error } => {
            emit(&Event::ServerStopped { error: &error });
            return true;
        }
    }
    false
}

/// Answers a pending request from a `decision` line, pairing the sender
/// first when asked to and the sender is verified (an unverified one is
/// never paired, same rule the interactive mode enforces by not even
/// offering P for one).
fn handle_decision(
    storage: &mut Repository,
    discovery: &DiscoveryHandle,
    pending: &mut HashMap<String, PendingRequest>,
    sessions: &mut HashMap<String, Session>,
    line: &str,
) {
    let decision: Decision = match serde_json::from_str(line) {
        Ok(decision) => decision,
        Err(err) => {
            eprintln!("receive: not a decision line: {line} ({err})");
            return;
        }
    };
    let Some(request) = pending.remove(&decision.session_id) else {
        // Already timed out or aborted: nothing to answer.
        return;
    };
    match decision.decision.as_str() {
        "decline" => {
            let _ = request.decision_tx.send(PrepareUploadDecisionV2::Decline);
        }
        "accept" | "accept_and_pair" => {
            if decision.decision == "accept_and_pair" && request.verified {
                let channels = discovery
                    .device_by_fingerprint(&request.fingerprint)
                    .map(|stored| PairedChannel::channels_of(&stored))
                    .unwrap_or_default();
                let _ = storage.paired.insert(
                    request.fingerprint.clone(),
                    request.alias.clone(),
                    channels,
                );
            }
            let ids = request.files.keys().cloned().collect();
            if request
                .decision_tx
                .send(PrepareUploadDecisionV2::Accept(ids))
                .is_ok()
            {
                sessions.insert(
                    decision.session_id,
                    Session {
                        alias: request.alias,
                        files: request.files,
                        finished: 0,
                        failed: 0,
                        finalized_bytes: 0,
                        in_progress: 0,
                        ended: None,
                    },
                );
            }
        }
        other => eprintln!("receive: unknown decision {other:?}"),
    }
}

/// Declines every pending request that has waited past [`DECISION_TIMEOUT`].
fn expire_pending(pending: &mut HashMap<String, PendingRequest>) {
    let expired: Vec<String> = pending
        .iter()
        .filter(|(_, request)| request.since.elapsed() >= DECISION_TIMEOUT)
        .map(|(session_id, _)| session_id.clone())
        .collect();
    for session_id in expired {
        if let Some(request) = pending.remove(&session_id) {
            let _ = request.decision_tx.send(PrepareUploadDecisionV2::Decline);
            emit(&Event::Timeout {
                session_id: &session_id,
            });
        }
    }
}

/// Emits the full list of currently confirmed devices. Unconfirmed ones
/// (heard announcing themselves but never answered) are left out: nothing
/// about them is verified, so they are not a usable `send --to` target.
fn emit_devices(discovery: &DiscoveryHandle, storage: &Repository) {
    let devices: Vec<DeviceJson> = discovery
        .devices()
        .into_iter()
        .filter(|device| device.confirmed)
        .filter_map(|device| {
            let http = device
                .get_ranked_channels()
                .into_iter()
                .find_map(|channel| channel.http())?;
            Some(DeviceJson {
                alias: device.device.alias.clone(),
                host: http.host.clone(),
                port: http.port,
                fingerprint: device.device.fingerprint.clone(),
                paired: storage.paired.contains(&device.device.fingerprint),
            })
        })
        .collect();
    emit(&Event::Devices { devices: &devices });
}

fn handle_file_done(sessions: &mut HashMap<String, Session>, done: FileDone) {
    let Some(session) = sessions.get_mut(&done.session_id) else {
        return;
    };
    session.in_progress = session.in_progress.saturating_sub(1);
    let file_name = session
        .files
        .get(&done.file_id)
        .map(|file| file.file_name.as_str())
        .unwrap_or(&done.file_id)
        .to_string();
    match &done.result {
        Ok(()) => {
            session.finished += 1;
            session.finalized_bytes += session
                .files
                .get(&done.file_id)
                .map(|file| file.size)
                .unwrap_or(0);
        }
        Err(_) => session.failed += 1,
    }
    emit(&Event::FileDone {
        session_id: &done.session_id,
        file_name: &file_name,
        ok: done.result.is_ok(),
        error: done.result.as_ref().err().map(String::as_str),
    });
    finish_if_done(sessions, &done.session_id);
}

/// Reports and removes a session once the server has reported its end and
/// no per-file result is outstanding (mirrors the interactive mode's own
/// `finish_receive_if_done`). A `SessionEnd` that arrives while files are
/// still in flight only sets `ended`; the `file_done` that empties
/// `in_progress` is what actually calls this through to completion.
fn finish_if_done(sessions: &mut HashMap<String, Session>, session_id: &str) {
    let done = sessions
        .get(session_id)
        .is_some_and(|session| session.ended.is_some() && session.in_progress == 0);
    if !done {
        return;
    }
    let session = sessions.remove(session_id).unwrap();
    emit(&Event::SessionDone {
        session_id,
        alias: &session.alias,
        files_ok: session.finished,
        files_failed: session.failed,
        bytes: session.finalized_bytes,
        cancelled: matches!(session.ended, Some(SessionEndReasonV2::Cancelled)),
    });
}

#[cfg(test)]
mod tests {
    use super::{Decision, Event};

    #[test]
    fn incoming_event_is_tagged_json() {
        let event = Event::Incoming {
            session_id: "s1",
            alias: "Phone",
            verified: true,
            paired: true,
            file_count: 2,
            total_bytes: 42,
            decision: "accepted",
        };
        let json = serde_json::to_string(&event).unwrap();
        assert!(json.starts_with(r#"{"event":"incoming""#), "{json}");
        assert!(json.contains(r#""decision":"accepted""#), "{json}");
    }

    #[test]
    fn ready_event_is_tagged_json() {
        let event = Event::Ready {
            alias: "Desktop",
            port: 53317,
        };
        let json = serde_json::to_string(&event).unwrap();
        assert_eq!(json, r#"{"event":"ready","alias":"Desktop","port":53317}"#);
    }

    #[test]
    fn devices_event_is_tagged_json() {
        let devices = vec![super::DeviceJson {
            alias: "Phone".to_string(),
            host: "192.168.1.10".to_string(),
            port: 53317,
            fingerprint: "abc".to_string(),
            paired: false,
        }];
        let event = Event::Devices { devices: &devices };
        let json = serde_json::to_string(&event).unwrap();
        assert!(json.starts_with(r#"{"event":"devices""#), "{json}");
        assert!(json.contains(r#""alias":"Phone""#), "{json}");
    }

    #[test]
    fn decision_line_parses() {
        let decision: Decision =
            serde_json::from_str(r#"{"session_id": "s1", "decision": "accept"}"#).unwrap();
        assert_eq!(decision.session_id, "s1");
        assert_eq!(decision.decision, "accept");
    }
}
