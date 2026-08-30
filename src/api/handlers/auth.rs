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

#[derive(Deserialize)]
pub struct SwitchAntigravityAccountRequest {
    pub email: String,
}

pub async fn get_antigravity_account_handler() -> Json<serde_json::Value> {
    let home = std::env::var("USERPROFILE")
        .or_else(|_| std::env::var("HOME"))
        .unwrap_or_else(|_| "/tmp".to_string());
    
    let path = std::path::Path::new(&home).join(".gemini").join("google_accounts.json");
    
    if let Ok(content) = std::fs::read_to_string(&path) {
        if let Ok(json) = serde_json::from_str::<serde_json::Value>(&content) {
            let active = json.get("active").and_then(|v| v.as_str()).unwrap_or_default();
            let mut accounts = Vec::new();
            if !active.is_empty() {
                accounts.push(active.to_string());
            }
            if let Some(old) = json.get("old").and_then(|v| v.as_array()) {
                for item in old {
                    if let Some(s) = item.as_str() {
                        if !accounts.contains(&s.to_string()) {
                            accounts.push(s.to_string());
                        }
                    }
                }
            }
            return Json(serde_json::json!({
                "active_account": active,
                "accounts": accounts,
                "auth_type": "Google OAuth (Personal)",
                "status": "authenticated"
            }));
        }
    }

    let env_account = std::env::var("GOOGLE_ACCOUNT_EMAIL")
        .or_else(|_| std::env::var("AGENTDECK_GOOGLE_ACCOUNT"))
        .unwrap_or_else(|_| "developer@example.com".to_string());

    Json(serde_json::json!({
        "active_account": env_account,
        "accounts": [env_account],
        "auth_type": "Google OAuth",
        "status": "authenticated"
    }))
}

pub async fn switch_antigravity_account_handler(
    Json(req): Json<SwitchAntigravityAccountRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let home = std::env::var("USERPROFILE")
        .or_else(|_| std::env::var("HOME"))
        .unwrap_or_else(|_| "/tmp".to_string());
    
    let path = std::path::Path::new(&home).join(".gemini").join("google_accounts.json");
    let target_email = req.email.trim().to_string();

    let current_data = if let Ok(content) = std::fs::read_to_string(&path) {
        serde_json::from_str::<serde_json::Value>(&content).unwrap_or_default()
    } else {
        serde_json::json!({ "active": "", "old": [] })
    };

    let old_active = current_data.get("active").and_then(|v| v.as_str()).unwrap_or("").to_string();
    let mut old_list: Vec<String> = current_data
        .get("old")
        .and_then(|v| v.as_array())
        .map(|arr| arr.iter().filter_map(|x| x.as_str().map(|s| s.to_string())).collect())
        .unwrap_or_default();

    if !old_active.is_empty() && old_active != target_email && !old_list.contains(&old_active) {
        old_list.push(old_active);
    }
    old_list.retain(|e| e != &target_email);

    let mut all_accounts = vec![target_email.clone()];
    for item in &old_list {
        if !all_accounts.contains(item) {
            all_accounts.push(item.clone());
        }
    }

    let new_data = serde_json::json!({
        "active": target_email,
        "old": old_list
    });

    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }

    if let Ok(serialized) = serde_json::to_string_pretty(&new_data) {
        let _ = std::fs::write(&path, serialized);
    }

    // Also update antigravity_quota.json
    let quota_path = std::path::Path::new(&home).join(".gemini").join("antigravity_quota.json");
    if quota_path.exists() {
        if let Ok(content) = std::fs::read_to_string(&quota_path) {
            if let Ok(mut val) = serde_json::from_str::<serde_json::Value>(&content) {
                if let Some(obj) = val.as_object_mut() {
                    obj.insert("account_email".to_string(), serde_json::Value::String(target_email.clone()));
                }
                if let Ok(ser) = serde_json::to_string_pretty(&val) {
                    let _ = std::fs::write(&quota_path, ser);
                }
            }
        }
    }

    Ok(Json(serde_json::json!({
        "success": true,
        "active_account": target_email,
        "accounts": all_accounts
    })))
}

#[derive(Deserialize)]
pub struct RemoveAntigravityAccountRequest {
    pub email: String,
}

pub async fn remove_antigravity_account_handler(
    Json(req): Json<RemoveAntigravityAccountRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let home = std::env::var("USERPROFILE")
        .or_else(|_| std::env::var("HOME"))
        .unwrap_or_else(|_| "/Users/arronkianparejas".to_string());
    
    let path = std::path::Path::new(&home).join(".gemini").join("google_accounts.json");
    let target_email = req.email.trim().to_string();

    let current_data = if let Ok(content) = std::fs::read_to_string(&path) {
        serde_json::from_str::<serde_json::Value>(&content).unwrap_or_default()
    } else {
        serde_json::json!({ "active": "", "old": [] })
    };

    let mut active = current_data.get("active").and_then(|v| v.as_str()).unwrap_or("").to_string();
    let mut old_list: Vec<String> = current_data
        .get("old")
        .and_then(|v| v.as_array())
        .map(|arr| arr.iter().filter_map(|x| x.as_str().map(|s| s.to_string())).collect())
        .unwrap_or_default();

    old_list.retain(|e| e != &target_email);
    if active == target_email {
        active = old_list.first().cloned().unwrap_or_default();
        if !active.is_empty() {
            old_list.remove(0);
        }
    }

    let mut all_accounts = Vec::new();
    if !active.is_empty() {
        all_accounts.push(active.clone());
    }
    for item in &old_list {
        if !all_accounts.contains(item) {
            all_accounts.push(item.clone());
        }
    }

    let new_data = serde_json::json!({
        "active": active,
        "old": old_list
    });

    if let Ok(serialized) = serde_json::to_string_pretty(&new_data) {
        let _ = std::fs::write(&path, serialized);
    }

    Ok(Json(serde_json::json!({
        "success": true,
        "active_account": active,
        "accounts": all_accounts
    })))
}

