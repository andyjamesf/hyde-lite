//! The `receive` mode: a long-running listener with no terminal UI, meant to
//! be spawned by another program (e.g. a desktop shell widget) and parsed
//! from its stdout instead of watched on screen.
//!
//! A request from a device already paired (accepted with P in the
//! interactive mode) and certificate-verified is accepted automatically,
//! exactly like the interactive mode's own auto-accept path
//! (`receive::handle_server_event`). Every other request is declined, unless
//! `quick_save` is set, in which case every request is accepted. There is no
//! keyboard, no raw terminal mode and no pairing offer: an unpaired sender
//! is never paired from this mode.
//!
//! One JSON object per line is printed to stdout for every event; nothing
//! else is written there. Fatal errors go to stderr, like the rest of the
//! CLI.

use super::{Network, start_network, stop_network};
use crate::storage::Repository;
use crate::util;
use localsend::http::server::common::save::FileUploadTarget;
use localsend::http::server::v2::{PrepareUploadDecisionV2, ServerEventV2, SessionEndReasonV2};
use localsend::model::transfer::FileDto;
use serde::Serialize;
use std::collections::HashMap;
use tokio::sync::{mpsc, oneshot};

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

/// One line of structured output. `event` is the JSON tag (`#[serde(tag)]`
/// below), so every variant becomes `{"event": "...", ...other fields}`.
#[derive(Serialize)]
#[serde(tag = "event", rename_all = "snake_case")]
enum Event<'a> {
    /// Printed once, right after the server and discovery started.
    Ready { alias: &'a str, port: u16 },

    /// A `PrepareUpload` request was answered.
    Incoming {
        session_id: &'a str,
        alias: &'a str,
        verified: bool,
        paired: bool,
        file_count: usize,
        total_bytes: u64,
        accepted: bool,
    },

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

pub(super) async fn run(storage: Repository, quick_save: bool) -> anyhow::Result<()> {
    let identity = storage.identity.clone();
    let Network {
        server,
        server_stop_tx,
        server_tx: _,
        mut server_rx,
        discovery,
        discovery_rx: _discovery_rx,
        discovery_stop_tx,
    } = start_network(&identity).await?;

    emit(&Event::Ready {
        alias: &identity.alias,
        port: identity.port,
    });

    let mut sessions: HashMap<String, Session> = HashMap::new();
    let (file_done_tx, mut file_done_rx) = mpsc::channel::<FileDone>(64);

    loop {
        tokio::select! {
            Some(event) = server_rx.recv() => {
                if handle_server_event(
                    &storage,
                    quick_save,
                    &mut sessions,
                    &file_done_tx,
                    event,
                ) {
                    break;
                }
            }
            Some(done) = file_done_rx.recv() => handle_file_done(&mut sessions, done),
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
    quick_save: bool,
    sessions: &mut HashMap<String, Session>,
    file_done_tx: &mpsc::Sender<FileDone>,
    event: ServerEventV2,
) -> bool {
    match event {
        ServerEventV2::Register { .. } => {}
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
            let accept = quick_save || paired;
            let total_bytes: u64 = files.values().map(|file| file.size).sum();

            emit(&Event::Incoming {
                session_id: &session_id,
                alias: &info.alias,
                verified,
                paired,
                file_count: files.len(),
                total_bytes,
                accepted: accept,
            });

            if !accept {
                let _ = decision_tx.send(PrepareUploadDecisionV2::Decline);
                return false;
            }
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
        ServerEventV2::PrepareUploadAborted { .. } => {}
        ServerEventV2::CancelReceived { .. } => {}
        ServerEventV2::ListenerFailed { error } => {
            emit(&Event::ServerStopped { error: &error });
            return true;
        }
    }
    false
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
    use super::Event;

    #[test]
    fn incoming_event_is_tagged_json() {
        let event = Event::Incoming {
            session_id: "s1",
            alias: "Phone",
            verified: true,
            paired: true,
            file_count: 2,
            total_bytes: 42,
            accepted: true,
        };
        let json = serde_json::to_string(&event).unwrap();
        assert!(json.starts_with(r#"{"event":"incoming""#), "{json}");
        assert!(json.contains(r#""accepted":true"#), "{json}");
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
}
