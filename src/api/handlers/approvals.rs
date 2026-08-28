use crate::api::AppState;
use crate::models::ApprovalRequest;
use axum::extract::{Path as AxumPath, State};
use axum::http::StatusCode;
use axum::Json;
use std::sync::Arc;

pub async fn list_approvals(State(state): State<Arc<AppState>>) -> Json<Vec<ApprovalRequest>> {
    let list = state.approvals.list_pending().unwrap_or_default();
    Json(list)
}

pub async fn approve_request(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let resolved = state
        .approvals
        .resolve(&id, true)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    if resolved {
        Ok(Json(serde_json::json!({ "approved": true })))
    } else {
        Err((StatusCode::NOT_FOUND, "Approval not found or already resolved".to_string()))
    }
}

pub async fn deny_request(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let resolved = state
        .approvals
        .resolve(&id, false)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    if resolved {
        Ok(Json(serde_json::json!({ "approved": false, "denied": true })))
    } else {
        Err((StatusCode::NOT_FOUND, "Approval not found or already resolved".to_string()))
    }
}
