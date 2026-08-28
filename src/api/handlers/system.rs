use crate::api::AppState;
use crate::models::DeviceInfo;
use crate::tailscale::TailscaleManager;
use axum::extract::State;
use axum::Json;
use std::sync::Arc;
use sysinfo::{Disks, System};

pub async fn health_handler() -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "status": "ok",
        "version": env!("CARGO_PKG_VERSION"),
        "service": "agentdeckd"
    }))
}

pub async fn status_handler(State(state): State<Arc<AppState>>) -> Json<serde_json::Value> {
    let ts = TailscaleManager::detect().await;
    let pending_approvals = state.approvals.list_pending().unwrap_or_default().len();
    let projects = state.event_bus.db().list_projects().unwrap_or_default().len();
    let sessions = state.event_bus.db().list_sessions().unwrap_or_default();
    let active_sessions = sessions.iter().filter(|s| s.status == crate::models::AgentStatus::Running).count();

    Json(serde_json::json!({
        "status": "healthy",
        "tailscale": {
            "installed": ts.installed,
            "ip": ts.ip,
            "status": ts.status
        },
        "metrics": {
            "projects_count": projects,
            "active_sessions": active_sessions,
            "pending_approvals": pending_approvals,
        }
    }))
}

pub async fn device_info_handler() -> Json<DeviceInfo> {
    let mut sys = System::new_all();
    sys.refresh_all();

    let disks = Disks::new_with_refreshed_list();
    let mut disk_total = 0;
    let mut disk_free = 0;
    for disk in disks.list() {
        disk_total += disk.total_space();
        disk_free += disk.available_space();
    }

    let ts = TailscaleManager::detect().await;

    let info = DeviceInfo {
        os: format!("macOS (Darwin {})", System::os_version().unwrap_or_default()),
        hostname: System::host_name().unwrap_or_else(|| "MacBook".to_string()),
        cpu_usage: sys.global_cpu_usage(),
        memory_used_mb: sys.used_memory() / 1024 / 1024,
        memory_total_mb: sys.total_memory() / 1024 / 1024,
        disk_free_gb: (disk_free as f64) / 1024.0 / 1024.0 / 1024.0,
        disk_total_gb: (disk_total as f64) / 1024.0 / 1024.0 / 1024.0,
        tailscale_ip: ts.ip,
        tailscale_status: ts.status,
        uptime_secs: System::uptime(),
    };

    Json(info)
}

pub async fn diagnostics_handler(State(state): State<Arc<AppState>>) -> Json<serde_json::Value> {
    let ts = TailscaleManager::detect().await;
    let agents = state.agent_manager.list_agents().await;

    let git_available = which::which("git").is_ok();
    let gh_available = which::which("gh").is_ok();

    Json(serde_json::json!({
        "daemon": {
            "status": "healthy",
            "version": env!("CARGO_PKG_VERSION")
        },
        "tailscale": {
            "installed": ts.installed,
            "ip": ts.ip,
            "status": ts.status
        },
        "agents": agents,
        "tools": {
            "git": git_available,
            "github_cli": gh_available
        },
        "database": {
            "status": "healthy"
        }
    }))
}

#[derive(serde::Deserialize)]
pub struct BrowseQuery {
    pub path: Option<String>,
}

pub async fn browse_directories_handler(
    axum::extract::Query(query): axum::extract::Query<BrowseQuery>,
) -> Json<serde_json::Value> {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/Users/arronkianparejas".to_string());
    let target_path = query.path.unwrap_or_else(|| home.clone());
    let path = std::path::PathBuf::from(&target_path);

    let mut entries = Vec::new();
    let parent = path.parent().map(|p| p.to_string_lossy().to_string());

    if path.is_dir() {
        if let Ok(read_dir) = std::fs::read_dir(&path) {
            for entry in read_dir.flatten() {
                let p = entry.path();
                if p.is_dir() {
                    let name = entry.file_name().to_string_lossy().to_string();
                    if !name.starts_with('.') || name == ".gemini" || name == ".agents" {
                        let is_git = p.join(".git").exists();
                        entries.push(serde_json::json!({
                            "name": name,
                            "path": p.to_string_lossy().to_string(),
                            "is_git_repo": is_git,
                        }));
                    }
                }
            }
        }
    }

    entries.sort_by(|a, b| {
        let name_a = a["name"].as_str().unwrap_or_default().to_lowercase();
        let name_b = b["name"].as_str().unwrap_or_default().to_lowercase();
        name_a.cmp(&name_b)
    });

    let shortcuts = vec![
        serde_json::json!({ "label": "Home", "path": home }),
        serde_json::json!({ "label": "Desktop", "path": format!("{}/Desktop", home) }),
        serde_json::json!({ "label": "Documents", "path": format!("{}/Documents", home) }),
        serde_json::json!({ "label": "Downloads", "path": format!("{}/Downloads", home) }),
        serde_json::json!({ "label": "AgentDeck", "path": format!("{}/agentdeck", home) }),
    ];

    Json(serde_json::json!({
        "current_path": target_path,
        "parent_path": parent,
        "entries": entries,
        "shortcuts": shortcuts,
    }))
}

#[derive(serde::Deserialize)]
pub struct FileUploadRequest {
    pub destination_path: String,
    pub filename: String,
    pub content_base64: String,
}

pub async fn upload_file_handler(
    Json(payload): Json<FileUploadRequest>,
) -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    use base64::Engine;
    use std::path::PathBuf;

    let dest_dir = PathBuf::from(&payload.destination_path);
    if !dest_dir.exists() {
        if let Err(e) = std::fs::create_dir_all(&dest_dir) {
            return Err((
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({ "error": format!("Failed to create destination directory: {}", e) })),
            ));
        }
    }

    let target_file = dest_dir.join(&payload.filename);
    let bytes = match base64::engine::general_purpose::STANDARD.decode(payload.content_base64.trim()) {
        Ok(b) => b,
        Err(e) => {
            return Err((
                axum::http::StatusCode::BAD_REQUEST,
                Json(serde_json::json!({ "error": format!("Invalid base64 payload: {}", e) })),
            ));
        }
    };

    if let Err(e) = std::fs::write(&target_file, &bytes) {
        return Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({ "error": format!("Failed to write file to disk: {}", e) })),
        ));
    }

    Ok(Json(serde_json::json!({
        "success": true,
        "path": target_file.to_string_lossy(),
        "filename": payload.filename,
        "bytes_written": bytes.len(),
    })))
}

#[derive(serde::Deserialize)]
pub struct CreateDirRequest {
    pub path: String,
}

pub async fn create_directory_handler(
    Json(payload): Json<CreateDirRequest>,
) -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    let p = std::path::PathBuf::from(&payload.path);
    if let Err(e) = std::fs::create_dir_all(&p) {
        return Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({ "error": format!("Failed to create directory: {}", e) })),
        ));
    }

    Ok(Json(serde_json::json!({
        "success": true,
        "path": payload.path,
    })))
}

#[derive(serde::Deserialize)]
pub struct PingWorkstationQuery {
    pub endpoint: String,
}

pub async fn ping_workstation_handler(
    axum::extract::Query(query): axum::extract::Query<PingWorkstationQuery>,
) -> Json<serde_json::Value> {
    let endpoint = query.endpoint.trim().trim_end_matches('/');
    let host = endpoint
        .strip_prefix("http://")
        .or_else(|| endpoint.strip_prefix("https://"))
        .unwrap_or(endpoint)
        .split(':')
        .next()
        .unwrap_or(endpoint);

    // 1. Try HTTP /health check with short timeout
    let http_client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_millis(1500))
        .build()
        .unwrap_or_default();

    let mut http_online = false;
    if let Ok(res) = http_client.get(format!("{}/health", endpoint)).send().await {
        if res.status().is_success() {
            http_online = true;
        }
    }

    // 2. Also test network / Tailscale ICMP reachability
    let is_network_online = if host != "localhost" && host != "127.0.0.1" {
        let output = tokio::process::Command::new("ping")
            .args(["-c", "1", "-W", "1000", host])
            .output()
            .await;
        match output {
            Ok(out) => out.status.success(),
            Err(_) => false,
        }
    } else {
        true
    };

    let is_online = http_online || is_network_online;

    Json(serde_json::json!({
        "endpoint": endpoint,
        "host": host,
        "online": is_online,
        "http_daemon_running": http_online,
        "tailscale_network_reachable": is_network_online,
    }))
}


