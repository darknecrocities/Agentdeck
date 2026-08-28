use crate::api::AppState;
use crate::models::{AuthProfile, CreateAuthProfileRequest};
use axum::extract::{Path as AxumPath, Query, State};
use axum::http::StatusCode;
use axum::Json;
use chrono::Utc;
use serde::Deserialize;
use std::sync::Arc;
use uuid::Uuid;

#[derive(Deserialize)]
pub struct ProfilesQuery {
    pub agent: Option<String>,
}

pub async fn list_profiles(
    State(state): State<Arc<AppState>>,
    Query(query): Query<ProfilesQuery>,
) -> Result<Json<Vec<AuthProfile>>, (StatusCode, String)> {
    let profiles = state
        .event_bus
        .db()
        .list_auth_profiles(query.agent.as_deref())
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    Ok(Json(profiles))
}

pub async fn create_profile(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CreateAuthProfileRequest>,
) -> Result<Json<AuthProfile>, (StatusCode, String)> {
    let now = Utc::now();
    let token_val = req.token_value.trim().to_string();
    let masked = if token_val.len() > 8 {
        format!("{}...{}", &token_val[..4], &token_val[token_val.len() - 4..])
    } else {
        "********".to_string()
    };

    let profile = AuthProfile {
        id: Uuid::new_v4().to_string(),
        agent_id: req.agent_id.to_lowercase(),
        account_name: req.account_name,
        token_masked: masked,
        token_value: token_val,
        is_active: req.set_active.unwrap_or(true),
        created_at: now,
        updated_at: now,
    };

    state
        .event_bus
        .db()
        .insert_auth_profile(&profile)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(profile))
}

pub async fn activate_profile(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let ok = state
        .event_bus
        .db()
        .set_active_auth_profile(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    if ok {
        Ok(Json(serde_json::json!({ "success": true })))
    } else {
        Err((StatusCode::NOT_FOUND, "Profile not found".to_string()))
    }
}

pub async fn delete_profile(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let ok = state
        .event_bus
        .db()
        .delete_auth_profile(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    if ok {
        Ok(Json(serde_json::json!({ "deleted": true })))
    } else {
        Err((StatusCode::NOT_FOUND, "Profile not found".to_string()))
    }
}
