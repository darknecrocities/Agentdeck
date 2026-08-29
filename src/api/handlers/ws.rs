use crate::api::AppState;
use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Path as AxumPath, Query, State};
use axum::response::IntoResponse;
use futures_util::{SinkExt, StreamExt};
use serde::Deserialize;
use std::sync::Arc;


#[derive(Deserialize)]
pub struct WsEventsQuery {
    pub after_event_id: Option<i64>,
}

pub async fn ws_events_handler(
    ws: WebSocketUpgrade,
    State(state): State<Arc<AppState>>,
    Query(query): Query<WsEventsQuery>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_events_socket(socket, state, query.after_event_id))
}

async fn handle_events_socket(mut socket: WebSocket, state: Arc<AppState>, after_event_id: Option<i64>) {
    let mut rx = state.event_bus.subscribe();

    // 1. Replay missed events if requested
    let mut last_id = after_event_id.unwrap_or(0);
    if last_id > 0 {
        if let Ok(missed) = state.event_bus.get_replay_events(last_id, 500) {
            for record in missed {
                if let Ok(msg) = serde_json::to_string(&record) {
                    if socket.send(Message::Text(msg)).await.is_err() {
                        return;
                    }
                    last_id = record.event_id;
                }
            }
        }
    }

    // 2. Stream live events
    loop {
        tokio::select! {
            record_res = rx.recv() => {
                match record_res {
                    Ok(record) => {
                        if record.event_id > last_id {
                            if let Ok(msg) = serde_json::to_string(&record) {
                                if socket.send(Message::Text(msg)).await.is_err() {
                                    break;
                                }
                                last_id = record.event_id;
                            }
                        }
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => {
                        continue;
                    }
                    Err(_) => break,
                }
            }
            msg = socket.recv() => {
                match msg {
                    Some(Ok(Message::Ping(p))) => {
                        let _ = socket.send(Message::Pong(p)).await;
                    }
                    Some(Ok(Message::Close(_))) | None => break,
                    _ => {}
                }
            }
        }
    }
}

pub async fn ws_session_handler(
    ws: WebSocketUpgrade,
    State(state): State<Arc<AppState>>,
    AxumPath(session_id): AxumPath<String>,
    Query(query): Query<WsEventsQuery>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_session_socket(socket, state, session_id, query.after_event_id))
}

async fn handle_session_socket(
    mut socket: WebSocket,
    state: Arc<AppState>,
    session_id: String,
    after_event_id: Option<i64>,
) {
    let mut rx = state.event_bus.subscribe();
    let mut last_id = after_event_id.unwrap_or(0);

    // Replay session events
    if let Ok(missed) = state.event_bus.get_session_replay_events(&session_id, last_id) {
        for record in missed {
            if let Ok(msg) = serde_json::to_string(&record) {
                if socket.send(Message::Text(msg)).await.is_err() {
                    return;
                }
                last_id = record.event_id;
            }
        }
    }

    // Live session stream
    loop {
        tokio::select! {
            record_res = rx.recv() => {
                match record_res {
                    Ok(record) => {
                        if record.session_id.as_deref() == Some(&session_id) && record.event_id > last_id {
                            if let Ok(msg) = serde_json::to_string(&record) {
                                if socket.send(Message::Text(msg)).await.is_err() {
                                    break;
                                }
                                last_id = record.event_id;
                            }
                        }
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                    Err(_) => break,
                }
            }
            msg = socket.recv() => {
                match msg {
                    Some(Ok(Message::Ping(p))) => {
                        let _ = socket.send(Message::Pong(p)).await;
                    }
                    Some(Ok(Message::Close(_))) | None => break,
                    _ => {}
                }
            }
        }
    }
}

pub async fn ws_terminal_handler(
    ws: WebSocketUpgrade,
    State(state): State<Arc<AppState>>,
    AxumPath(terminal_id): AxumPath<String>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_terminal_socket(socket, state, terminal_id))
}

async fn handle_terminal_socket(socket: WebSocket, state: Arc<AppState>, terminal_id: String) {
    let session = match state.terminal_manager.get_session(&terminal_id) {
        Some(s) => s,
        None => return,
    };

    let (mut ws_sender, mut ws_receiver) = socket.split();
    let mut pty_rx = session.output_tx.subscribe();
    let writer = session.writer.clone();

    let mut send_task = tokio::spawn(async move {
        while let Ok(bytes) = pty_rx.recv().await {
            if ws_sender.send(Message::Binary(bytes)).await.is_err() {
                break;
            }
        }
    });

    let mut recv_task = tokio::spawn(async move {
        while let Some(Ok(msg)) = ws_receiver.next().await {
            match msg {
                Message::Text(t) => {
                    use std::io::Write;
                    let mut w = writer.lock().unwrap();
                    let _ = w.write_all(t.as_bytes());
                    let _ = w.flush();
                }
                Message::Binary(b) => {
                    use std::io::Write;
                    let mut w = writer.lock().unwrap();
                    let _ = w.write_all(&b);
                    let _ = w.flush();
                }
                Message::Close(_) => break,
                _ => {}
            }
        }
    });

    tokio::select! {
        _ = (&mut send_task) => recv_task.abort(),
        _ = (&mut recv_task) => send_task.abort(),
    }
}

pub async fn ws_screen_stream_handler(
    ws: WebSocketUpgrade,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_screen_stream_socket(socket))
}

async fn handle_screen_stream_socket(mut socket: WebSocket) {
    use std::sync::atomic::Ordering;
    use crate::api::handlers::system::{ensure_screen_stream_running, get_screen_stream};

    ensure_screen_stream_running().await;
    let stream = get_screen_stream();
    let mut rx = stream.frame_tx.subscribe();

    // Send latest cached frame immediately on connect if fresh
    if let Some((ref raw, ref inst)) = *stream.raw_latest_frame.read().await {
        if inst.elapsed() < std::time::Duration::from_millis(3000) {
            let _ = socket.send(Message::Binary(raw.to_vec())).await;
        }
    }

    loop {
        tokio::select! {
            frame_res = rx.recv() => {
                match frame_res {
                    Ok(frame_bytes) => {
                        stream.last_requested_at.store(chrono::Utc::now().timestamp(), Ordering::Relaxed);
                        if socket.send(Message::Binary(frame_bytes.to_vec())).await.is_err() {
                            break;
                        }
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => {
                        // Drop lagged frames to keep stream real-time
                        continue;
                    }
                    Err(_) => break,
                }
            }
            msg = socket.recv() => {
                match msg {
                    Some(Ok(Message::Close(_))) | None => break,
                    Some(Ok(Message::Ping(p))) => {
                        let _ = socket.send(Message::Pong(p)).await;
                    }
                    _ => {}
                }
            }
        }
    }
}
