use crate::api::AppState;
use crate::models::TerminalSessionInfo;
use axum::extract::{Path as AxumPath, State};
use axum::http::StatusCode;
use axum::Json;
use serde::Deserialize;
use std::sync::Arc;

#[derive(Deserialize)]
pub struct SpawnTerminalRequest {
    pub project_id: Option<String>,
    pub cwd: Option<String>,
    pub cols: Option<u16>,
    pub rows: Option<u16>,
}

#[derive(Deserialize)]
pub struct TerminalInputPayload {
    pub input: String,
}

#[derive(Deserialize)]
pub struct TerminalResizePayload {
    pub cols: u16,
    pub rows: u16,
}

pub async fn list_terminals(State(state): State<Arc<AppState>>) -> Json<Vec<TerminalSessionInfo>> {
    let list = state.terminal_manager.list_sessions();
    Json(list)
}

pub async fn spawn_terminal(
    State(state): State<Arc<AppState>>,
    Json(req): Json<SpawnTerminalRequest>,
) -> Result<Json<TerminalSessionInfo>, (StatusCode, String)> {
    let mut cwd = req.cwd;
    if let Some(pid) = &req.project_id {
        if let Ok(Some(proj)) = state.event_bus.db().get_project(pid) {
            cwd = Some(proj.path);
        }
    }

    let session = state
        .terminal_manager
        .spawn_session(req.project_id, cwd, req.cols.unwrap_or(80), req.rows.unwrap_or(24))
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(session.info.clone()))
}

pub async fn write_terminal_input(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
    Json(req): Json<TerminalInputPayload>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    state
        .terminal_manager
        .write_input(&id, req.input.as_bytes())
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(serde_json::json!({ "success": true })))
}

pub async fn resize_terminal(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
    Json(req): Json<TerminalResizePayload>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    state
        .terminal_manager
        .resize(&id, req.cols, req.rows)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(serde_json::json!({ "success": true })))
}

pub async fn close_terminal(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let closed = state.terminal_manager.close_session(&id);
    if closed {
        Ok(Json(serde_json::json!({ "closed": true })))
    } else {
        Err((StatusCode::NOT_FOUND, "Terminal session not found".to_string()))
    }
}
