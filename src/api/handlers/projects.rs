use crate::api::AppState;
use crate::git::GitManager;
use crate::github::GitHubManager;
use crate::models::Project;
use axum::extract::{Path as AxumPath, Query, State};
use axum::http::StatusCode;
use axum::Json;
use chrono::Utc;
use serde::Deserialize;
use std::fs;
use std::path::PathBuf;
use std::sync::Arc;
use uuid::Uuid;

#[derive(Deserialize)]
pub struct CreateProjectRequest {
    pub name: String,
    pub path: String,
    pub default_agent: Option<String>,
}

#[derive(Deserialize)]
pub struct FilesQuery {
    pub path: Option<String>,
}

#[derive(Deserialize)]
pub struct GitCommitRequest {
    pub message: String,
}

pub async fn list_projects(State(state): State<Arc<AppState>>) -> Json<Vec<Project>> {
    let list = state.event_bus.db().list_projects().unwrap_or_default();
    Json(list)
}

pub async fn create_project(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CreateProjectRequest>,
) -> Result<Json<Project>, (StatusCode, String)> {
    let canonical = state
        .security
        .validate_path(&req.path)
        .map_err(|e| (StatusCode::FORBIDDEN, e.to_string()))?;

    let now = Utc::now();
    let project = Project {
        id: Uuid::new_v4().to_string(),
        name: req.name,
        path: canonical.to_string_lossy().to_string(),
        default_agent: req.default_agent.unwrap_or_else(|| "antigravity".to_string()),
        created_at: now,
        updated_at: now,
    };

    state
        .event_bus
        .db()
        .insert_project(&project)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    if let Ok(mut watcher) = state.watcher.lock() {
        let _ = watcher.watch_directory(&project.id, &project.path);
    }

    Ok(Json(project))
}

pub async fn delete_project(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let deleted = state
        .event_bus
        .db()
        .delete_project(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    if deleted {
        if let Ok(mut watcher) = state.watcher.lock() {
            let _ = watcher.unwatch_directory(&id);
        }
        Ok(Json(serde_json::json!({ "deleted": true })))
    } else {
        Err((StatusCode::NOT_FOUND, "Project not found".to_string()))
    }
}

pub async fn list_project_files(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
    Query(query): Query<FilesQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let project = state
        .event_bus
        .db()
        .get_project(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "Project not found".to_string()))?;

    let base_path = PathBuf::from(&project.path);
    let target = if let Some(sub) = query.path {
        base_path.join(sub)
    } else {
        base_path
    };

    let canonical = state
        .security
        .validate_path(&target)
        .map_err(|e| (StatusCode::FORBIDDEN, e.to_string()))?;

    let mut entries = Vec::new();
    if let Ok(read_dir) = fs::read_dir(&canonical) {
        for entry in read_dir.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.starts_with('.') || name == "target" || name == "node_modules" {
                continue;
            }
            let is_dir = entry.file_type().map(|t| t.is_dir()).unwrap_or(false);
            let size = entry.metadata().map(|m| m.len()).unwrap_or(0);

            entries.push(serde_json::json!({
                "name": name,
                "path": entry.path().to_string_lossy().to_string(),
                "is_dir": is_dir,
                "size": size,
            }));
        }
    }

    Ok(Json(serde_json::json!({
        "current_path": canonical.to_string_lossy().to_string(),
        "entries": entries
    })))
}

pub async fn read_file_content(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
    Query(query): Query<FilesQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let project = state
        .event_bus
        .db()
        .get_project(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "Project not found".to_string()))?;

    let file_subpath = query.path.ok_or((StatusCode::BAD_REQUEST, "Missing path query".to_string()))?;
    let target = PathBuf::from(&project.path).join(file_subpath);

    let canonical = state
        .security
        .validate_path(&target)
        .map_err(|e| (StatusCode::FORBIDDEN, e.to_string()))?;

    let content = fs::read_to_string(&canonical).map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(serde_json::json!({
        "path": canonical.to_string_lossy().to_string(),
        "content": content
    })))
}

pub async fn get_project_git_status(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let project = state
        .event_bus
        .db()
        .get_project(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "Project not found".to_string()))?;

    let status = GitManager::get_status(&project.path)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(serde_json::to_value(status).unwrap()))
}

pub async fn get_project_git_diff(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let project = state
        .event_bus
        .db()
        .get_project(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "Project not found".to_string()))?;

    let diff = GitManager::get_diff(&project.path)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(serde_json::json!({ "diff": diff })))
}

pub async fn get_project_git_log(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let project = state
        .event_bus
        .db()
        .get_project(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "Project not found".to_string()))?;

    let log = GitManager::get_log(&project.path, 20)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(serde_json::json!({ "log": log })))
}

pub async fn commit_project_git(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
    Json(req): Json<GitCommitRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let project = state
        .event_bus
        .db()
        .get_project(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "Project not found".to_string()))?;

    let res = GitManager::commit(&project.path, &req.message)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(serde_json::json!({ "result": res })))
}

pub async fn push_project_git(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let project = state
        .event_bus
        .db()
        .get_project(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "Project not found".to_string()))?;

    let res = GitManager::push(&project.path)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(serde_json::json!({ "result": res })))
}

pub async fn pull_project_git(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let project = state
        .event_bus
        .db()
        .get_project(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "Project not found".to_string()))?;

    let res = GitManager::pull(&project.path)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(serde_json::json!({ "result": res })))
}

pub async fn get_project_github(
    State(state): State<Arc<AppState>>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let project = state
        .event_bus
        .db()
        .get_project(&id)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "Project not found".to_string()))?;

    let github = GitHubManager::get_repo_overview(&project.path)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(github))
}
