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
