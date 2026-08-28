use crate::api::AppState;
use crate::models::{AgentInfo, AgentSession, AgentStartRequest, EventRecord};
use axum::extract::{Path as AxumPath, Query, State};
use axum::http::StatusCode;
use axum::Json;
use serde::Deserialize;
use std::sync::Arc;

#[derive(Deserialize)]
pub struct StartSessionPayload {
    pub project_id: String,
    pub agent: String,
    pub prompt: String,
    pub conversation_id: Option<String>,
    pub model: Option<String>,
    pub effort: Option<String>,
}

#[derive(Deserialize)]
pub struct SendPromptPayload {
    pub prompt: String,
}

#[derive(Deserialize)]
pub struct EventsQuery {
    pub after_event_id: Option<i64>,
}

pub async fn list_agents(State(state): State<Arc<AppState>>) -> Json<Vec<AgentInfo>> {
    let list = state.agent_manager.list_agents().await;
    Json(list)
}

pub async fn get_agent(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<AgentInfo>, (StatusCode, String)> {
    state
        .agent_manager
        .get_agent(&id)
        .await
        .map(Json)
        .map_err(|e| (StatusCode::NOT_FOUND, e.to_string()))
}

pub async fn list_sessions(State(state): State<Arc<AppState>>) -> Json<Vec<AgentSession>> {
    let list = state.event_bus.db().list_sessions().unwrap_or_default();
    Json(list)
}

pub async fn start_session(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<StartSessionPayload>,
) -> Result<Json<AgentSession>, (StatusCode, String)> {
    let project = state
        .event_bus
        .db()
        .get_project(&payload.project_id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "Project not found".to_string()))?;

    let req = AgentStartRequest {
        project_id: project.id.clone(),
        workspace_path: project.path.clone(),
        prompt: payload.prompt,
        conversation_id: payload.conversation_id,
        model: payload.model,
        effort: payload.effort,
    };

    state
        .agent_manager
        .start_session(&payload.agent, req)
        .await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))
}

pub async fn get_session(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<AgentSession>, (StatusCode, String)> {
    state
        .event_bus
        .db()
        .get_session(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .map(Json)
        .ok_or((StatusCode::NOT_FOUND, "Session not found".to_string()))
}

pub async fn send_prompt_to_session(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
    Json(payload): Json<SendPromptPayload>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let session = state
        .event_bus
        .db()
        .get_session(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "Session not found".to_string()))?;

    state
        .agent_manager
        .send_prompt(&session.agent, &id, &payload.prompt)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let _ = state.event_bus.publish(
        Some(&id),
        Some(&session.project_id),
        "prompt_sent",
        crate::models::AgentEventPayload::PromptSent {
            prompt: payload.prompt,
        },
    );

    Ok(Json(serde_json::json!({ "sent": true })))
}

pub async fn continue_session_handler(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let session = state
        .event_bus
        .db()
        .get_session(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "Session not found".to_string()))?;

    state
        .agent_manager
        .continue_session(&session.agent, &id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(serde_json::json!({ "resumed": true })))
}

pub async fn stop_session_handler(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let session = state
        .event_bus
        .db()
        .get_session(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "Session not found".to_string()))?;

    state
        .agent_manager
        .stop_session(&session.agent, &id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(serde_json::json!({ "stopped": true })))
}

pub async fn kill_session_handler(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let session = state
        .event_bus
        .db()
        .get_session(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "Session not found".to_string()))?;

    state
        .agent_manager
        .kill_session(&session.agent, &id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(serde_json::json!({ "killed": true })))
}

pub async fn get_session_events(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
    Query(query): Query<EventsQuery>,
) -> Result<Json<Vec<EventRecord>>, (StatusCode, String)> {
    let after_id = query.after_event_id.unwrap_or(0);
    let events = state
        .event_bus
        .get_session_replay_events(&id, after_id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(events))
}
