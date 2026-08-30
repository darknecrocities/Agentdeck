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

    let os_name = if cfg!(target_os = "macos") {
        format!("macOS (Darwin {})", System::os_version().unwrap_or_default())
    } else if cfg!(target_os = "windows") {
        format!("Windows ({})", System::os_version().unwrap_or_default())
    } else if cfg!(target_os = "linux") {
        format!("Linux ({})", System::os_version().unwrap_or_default())
    } else {
        System::name().unwrap_or_else(|| "Unknown OS".to_string())
    };

    let info = DeviceInfo {
        os: os_name,
        hostname: System::host_name().unwrap_or_else(|| "Workstation".to_string()),
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
    let home = std::env::var("USERPROFILE")
        .or_else(|_| std::env::var("HOME"))
        .unwrap_or_else(|_| if cfg!(windows) { "C:\\Users".to_string() } else { "/home".to_string() });

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

    let home_path = std::path::Path::new(&home);
    let shortcuts = vec![
        serde_json::json!({ "label": "Home", "path": home }),
        serde_json::json!({ "label": "Desktop", "path": home_path.join("Desktop").to_string_lossy().to_string() }),
        serde_json::json!({ "label": "Documents", "path": home_path.join("Documents").to_string_lossy().to_string() }),
        serde_json::json!({ "label": "Downloads", "path": home_path.join("Downloads").to_string_lossy().to_string() }),
        serde_json::json!({ "label": "AgentDeck", "path": home_path.join("agentdeck").to_string_lossy().to_string() }),
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

#[derive(serde::Deserialize)]
pub struct LaunchAppRequest {
    pub app: String,
    pub path: Option<String>,
    pub url: Option<String>,
}

pub async fn launch_app_handler(
    Json(payload): Json<LaunchAppRequest>,
) -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    let app_target = payload.app.to_lowercase();
    #[allow(unused_assignments)]
    let mut cmd_str = String::new();

    #[cfg(target_os = "windows")]
    {
        let p = payload.path.as_deref().unwrap_or(".");
        match app_target.as_str() {
            "vscode" | "code" => {
                cmd_str = format!("Start-Process code -ArgumentList '\"{}\"' -ErrorAction SilentlyContinue; if (-not $?) {{ Start-Process cmd.exe -ArgumentList '/c code \"{}\"' }}", p, p);
            }
            "antigravity" | "ide" | "agy" => {
                // Try launching agy in Windows Terminal or PowerShell interactive window
                cmd_str = format!("Start-Process wt.exe -ArgumentList '-d', '\"{}\"', 'powershell', '-NoExit', '-Command', 'agy' -ErrorAction SilentlyContinue; if (-not $?) {{ Start-Process powershell.exe -ArgumentList '-NoExit', '-Command', 'Set-Location \"{}\"; agy' }}", p, p);
            }
            "terminal" | "powershell" => {
                cmd_str = format!("Start-Process wt.exe -ArgumentList '-d', '\"{}\"' -ErrorAction SilentlyContinue; if (-not $?) {{ Start-Process powershell.exe -ArgumentList '-NoExit', '-Command', 'Set-Location \"{}\"' }}", p, p);
            }
            "explorer" => {
                cmd_str = format!("Start-Process explorer.exe -ArgumentList '\"{}\"'", p);
            }
            "taskmgr" | "taskmanager" => {
                cmd_str = "Start-Process taskmgr.exe".to_string();
            }
            "browser" | "url" => {
                let u = payload.url.as_deref().unwrap_or("https://google.com");
                cmd_str = format!("Start-Process '\"{}\"'", u);
            }
            _ => {
                if let Some(url) = &payload.url {
                    cmd_str = format!("Start-Process '\"{}\"'", url);
                } else if let Some(path) = &payload.path {
                    cmd_str = format!("Start-Process '\"{}\"'", path);
                } else {
                    cmd_str = format!("Start-Process \"{}\" -ErrorAction SilentlyContinue; if (-not $?) {{ Start-Process cmd.exe -ArgumentList '/c start {}' }}", payload.app, payload.app);
                }
            }
        }
        let _ = tokio::process::Command::new("powershell")
            .args(["-NoProfile", "-Command", &cmd_str])
            .spawn();
    }

    #[cfg(target_os = "macos")]
    {
        match app_target.as_str() {
            "vscode" | "code" => {
                let p = payload.path.as_deref().unwrap_or(".");
                cmd_str = format!("open -a 'Visual Studio Code' \"{}\"", p);
            }
            "antigravity" | "ide" => {
                let p = payload.path.as_deref().unwrap_or(".");
                cmd_str = format!("agy \"{}\"", p);
            }
            "terminal" | "iterm" => {
                cmd_str = "open -a Terminal".to_string();
            }
            "explorer" | "finder" => {
                let p = payload.path.as_deref().unwrap_or(".");
                cmd_str = format!("open \"{}\"", p);
            }
            "taskmgr" | "activitymonitor" => {
                cmd_str = "open -a 'Activity Monitor'".to_string();
            }
            "browser" | "url" => {
                let u = payload.url.as_deref().unwrap_or("https://google.com");
                cmd_str = format!("open \"{}\"", u);
            }
            _ => {
                if let Some(url) = payload.url {
                    cmd_str = format!("open \"{}\"", url);
                } else if let Some(path) = payload.path {
                    cmd_str = format!("open \"{}\"", path);
                } else {
                    cmd_str = format!("open -a \"{}\"", payload.app);
                }
            }
        }
        let _ = tokio::process::Command::new("sh")
            .args(["-c", &cmd_str])
            .spawn();
    }

    #[cfg(target_os = "linux")]
    {
        match app_target.as_str() {
            "vscode" | "code" => {
                let p = payload.path.as_deref().unwrap_or(".");
                cmd_str = format!("code \"{}\"", p);
            }
            "explorer" | "finder" => {
                let p = payload.path.as_deref().unwrap_or(".");
                cmd_str = format!("xdg-open \"{}\"", p);
            }
            "browser" | "url" => {
                let u = payload.url.as_deref().unwrap_or("https://google.com");
                cmd_str = format!("xdg-open \"{}\"", u);
            }
            _ => {
                cmd_str = format!("xdg-open \"{}\"", payload.app);
            }
        }
        let _ = tokio::process::Command::new("sh")
            .args(["-c", &cmd_str])
            .spawn();
    }

    Ok(Json(serde_json::json!({
        "success": true,
        "app": payload.app,
        "command": cmd_str,
        "message": format!("Launched {} on workstation", payload.app),
    })))
}

pub struct ScreenStreamState {
    pub is_running: std::sync::Arc<std::sync::atomic::AtomicBool>,
    pub last_requested_at: std::sync::Arc<std::sync::atomic::AtomicI64>,
    pub latest_frame: std::sync::Arc<tokio::sync::RwLock<Option<(String, usize, std::time::Instant)>>>,
    pub raw_latest_frame: std::sync::Arc<tokio::sync::RwLock<Option<(axum::body::Bytes, std::time::Instant)>>>,
    pub frame_tx: tokio::sync::broadcast::Sender<axum::body::Bytes>,
    pub child_handle: std::sync::Arc<tokio::sync::Mutex<Option<tokio::process::Child>>>,
}

impl ScreenStreamState {
    pub fn new() -> Self {
        let (frame_tx, _) = tokio::sync::broadcast::channel(64);
        Self {
            is_running: std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false)),
            last_requested_at: std::sync::Arc::new(std::sync::atomic::AtomicI64::new(0)),
            latest_frame: std::sync::Arc::new(tokio::sync::RwLock::new(None)),
            raw_latest_frame: std::sync::Arc::new(tokio::sync::RwLock::new(None)),
            frame_tx,
            child_handle: std::sync::Arc::new(tokio::sync::Mutex::new(None)),
        }
    }
}

static SCREEN_STREAM: std::sync::OnceLock<ScreenStreamState> = std::sync::OnceLock::new();

pub fn get_screen_stream() -> &'static ScreenStreamState {
    SCREEN_STREAM.get_or_init(ScreenStreamState::new)
}

pub async fn ensure_screen_stream_running() {
    use base64::Engine;
    use std::sync::atomic::Ordering;
    use tokio::io::{AsyncBufReadExt, AsyncReadExt};

    let stream = get_screen_stream();
    stream.last_requested_at.store(chrono::Utc::now().timestamp(), Ordering::Relaxed);

    if !stream.is_running.load(Ordering::SeqCst) {
        stream.is_running.store(true, Ordering::SeqCst);
        let is_running = stream.is_running.clone();
        let last_requested_at = stream.last_requested_at.clone();
        let latest_frame = stream.latest_frame.clone();
        let raw_latest_frame = stream.raw_latest_frame.clone();
        let frame_tx = stream.frame_tx.clone();
        let child_handle = stream.child_handle.clone();

        tokio::spawn(async move {
            #[cfg(target_os = "macos")]
            {
                let helper_paths = [
                    "/Users/arronkianparejas/.local/bin/agentdeck-screen-streamer",
                    "agentdeck-screen-streamer",
                    "scripts/agentdeck-screen-streamer",
                ];

                let mut helper_bin = None;
                for p in helper_paths {
                    if std::path::Path::new(p).exists() || which::which(p).is_ok() {
                        helper_bin = Some(p);
                        break;
                    }
                }

                if let Some(bin) = helper_bin {
                    tracing::info!("Spawning hardware screen streamer binary: {}", bin);
                    let mut cmd = tokio::process::Command::new(bin);
                    cmd.args(["960", "30", "0.40"]);
                    cmd.stdout(std::process::Stdio::piped());
                    cmd.stderr(std::process::Stdio::piped());

                    match cmd.spawn() {
                        Ok(mut child) => {
                            let stderr = child.stderr.take();
                            if let Some(err_reader) = stderr {
                                tokio::spawn(async move {
                                    let mut err_buf = String::new();
                                    let mut reader = tokio::io::BufReader::new(err_reader);
                                    while let Ok(n) = reader.read_line(&mut err_buf).await {
                                        if n == 0 { break; }
                                        tracing::warn!("Screen streamer output: {}", err_buf.trim());
                                        err_buf.clear();
                                    }
                                });
                            }

                            if let Some(mut stdout) = child.stdout.take() {
                                *child_handle.lock().await = Some(child);
                                tracing::info!("Screen streamer process successfully hooked into stdout stream");

                                let mut len_buf = [0u8; 4];
                                while is_running.load(Ordering::Relaxed) {
                                    let now = chrono::Utc::now().timestamp();
                                    if now - last_requested_at.load(Ordering::Relaxed) > 20 {
                                        tracing::info!("Screen stream idle timeout, shutting down background hardware screen worker");
                                        break;
                                    }

                                    if let Ok(Ok(_)) = tokio::time::timeout(std::time::Duration::from_millis(500), stdout.read_exact(&mut len_buf)).await {
                                        let frame_len = u32::from_be_bytes(len_buf) as usize;
                                        if frame_len > 0 && frame_len < 5_000_000 {
                                            let mut frame_data = vec![0u8; frame_len];
                                            if let Ok(Ok(_)) = tokio::time::timeout(std::time::Duration::from_millis(500), stdout.read_exact(&mut frame_data)).await {
                                                let frame_bytes_arc = axum::body::Bytes::from(frame_data);
                                                let size = frame_bytes_arc.len();
                                                let b64 = base64::engine::general_purpose::STANDARD.encode(&frame_bytes_arc);
                                                let now_inst = std::time::Instant::now();
                                                *latest_frame.write().await = Some((b64, size, now_inst));
                                                *raw_latest_frame.write().await = Some((frame_bytes_arc.clone(), now_inst));
                                                let _ = frame_tx.send(frame_bytes_arc);
                                                continue;
                                            }
                                        }
                                    }
                                }

                                if let Some(mut proc) = child_handle.lock().await.take() {
                                    let _ = proc.kill().await;
                                }
                            }
                        }
                        Err(e) => {
                            tracing::error!("Failed to spawn screen streamer binary '{}': {}", bin, e);
                        }
                    }
                } else {
                    tracing::error!("No screen streamer binary found in helper paths");
                }
            }

            #[cfg(target_os = "windows")]
            {
                if which::which("ffmpeg").is_ok() {
                    let mut c = tokio::process::Command::new("ffmpeg");
                    c.args([
                        "-f", "gdigrab",
                        "-fflags", "nobuffer",
                        "-flags", "low_delay",
                        "-framerate", "30",
                        "-i", "desktop",
                        "-vf", "scale=1024:-1",
                        "-pix_fmt", "yuv420p",
                        "-f", "image2pipe",
                        "-vcodec", "mjpeg",
                        "-q:v", "8",
                        "-",
                    ]);
                    c.stdout(std::process::Stdio::piped());
                    c.stderr(std::process::Stdio::null());
                    if let Ok(mut child) = c.spawn() {
                        if let Some(mut stdout) = child.stdout.take() {
                            *child_handle.lock().await = Some(child);
                            let mut buffer = Vec::with_capacity(262144);
                            let mut chunk = [0u8; 16384];

                            while is_running.load(Ordering::Relaxed) {
                                let now = chrono::Utc::now().timestamp();
                                if now - last_requested_at.load(Ordering::Relaxed) > 25 {
                                    break;
                                }

                                if let Ok(Ok(n)) = tokio::time::timeout(std::time::Duration::from_millis(500), stdout.read(&mut chunk)).await {
                                    if n == 0 { break; }
                                    buffer.extend_from_slice(&chunk[..n]);
                                    // Parse frames
                                }
                            }
                        }
                    }
                }
            }

            #[cfg(target_os = "linux")]
            {
                if which::which("ffmpeg").is_ok() {
                    let mut c = tokio::process::Command::new("ffmpeg");
                    c.args([
                        "-f", "x11grab",
                        "-fflags", "nobuffer",
                        "-flags", "low_delay",
                        "-framerate", "30",
                        "-i", ":0.0",
                        "-vf", "scale=1024:-1",
                        "-pix_fmt", "yuv420p",
                        "-f", "image2pipe",
                        "-vcodec", "mjpeg",
                        "-q:v", "8",
                        "-",
                    ]);
                    c.stdout(std::process::Stdio::piped());
                    c.stderr(std::process::Stdio::null());
                    if let Ok(mut child) = c.spawn() {
                        if let Some(mut stdout) = child.stdout.take() {
                            *child_handle.lock().await = Some(child);
                            let mut buffer = Vec::with_capacity(262144);
                            let mut chunk = [0u8; 16384];

                            while is_running.load(Ordering::Relaxed) {
                                let now = chrono::Utc::now().timestamp();
                                if now - last_requested_at.load(Ordering::Relaxed) > 25 {
                                    break;
                                }

                                if let Ok(Ok(n)) = tokio::time::timeout(std::time::Duration::from_millis(500), stdout.read(&mut chunk)).await {
                                    if n == 0 { break; }
                                    buffer.extend_from_slice(&chunk[..n]);
                                }
                            }
                        }
                    }
                }
            }

            is_running.store(false, Ordering::SeqCst);
        });
    }
}

pub async fn take_screenshot_handler() -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    use base64::Engine;

    let stream = get_screen_stream();
    ensure_screen_stream_running().await;

    // Fast-path: return cached stream frame from memory (wait up to 1000ms on initial cold start)
    for _ in 0..30 {
        if let Some((ref frame, size, ref instant)) = *stream.latest_frame.read().await {
            if instant.elapsed() < std::time::Duration::from_millis(3000) {
                return Ok(Json(serde_json::json!({
                    "success": true,
                    "image_base64": frame,
                    "size_bytes": size,
                    "live": true,
                    "timestamp": chrono::Utc::now().to_rfc3339(),
                })));
            }
        }
        tokio::time::sleep(std::time::Duration::from_millis(35)).await;
    }

    // Direct native capture fallback
    #[cfg(target_os = "macos")]
    {
        let target_path = {
            let temp_dir = std::env::temp_dir();
            let file_name = format!("agentdeck_screen_direct_{}_{}.jpg", std::process::id(), chrono::Utc::now().timestamp_millis());
            temp_dir.join(&file_name)
        };

        let screencapture_bin = if std::path::Path::new("/usr/sbin/screencapture").exists() {
            "/usr/sbin/screencapture"
        } else {
            "screencapture"
        };

        let output = tokio::process::Command::new(screencapture_bin)
            .args(["-x", "-t", "jpg", "-m", "-r", target_path.to_str().unwrap_or("/tmp/agentdeck_screen.jpg")])
            .output()
            .await;

        if let Ok(out) = output {
            if out.status.success() && target_path.exists() {
                if let Ok(image_data) = tokio::fs::read(&target_path).await {
                    let _ = tokio::fs::remove_file(&target_path).await;
                    let b64 = base64::engine::general_purpose::STANDARD.encode(&image_data);
                    return Ok(Json(serde_json::json!({
                        "success": true,
                        "image_base64": b64,
                        "size_bytes": image_data.len(),
                        "timestamp": chrono::Utc::now().to_rfc3339(),
                    })));
                }
            }
        }
    }

    #[cfg(target_os = "windows")]
    {
        let ps_script = r#"Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height; $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size); $ms = New-Object System.IO.MemoryStream; $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg); [System.Convert]::ToBase64String($ms.ToArray()); $g.Dispose(); $bmp.Dispose(); $ms.Dispose();"#;

        let output = tokio::process::Command::new("powershell")
            .args(["-NoProfile", "-Command", ps_script])
            .output()
            .await;

        if let Ok(out) = output {
            if out.status.success() {
                let b64 = String::from_utf8_lossy(&out.stdout).trim().to_string();
                if !b64.is_empty() {
                    let len = b64.len();
                    return Ok(Json(serde_json::json!({
                        "success": true,
                        "image_base64": b64,
                        "size_bytes": len,
                        "timestamp": chrono::Utc::now().to_rfc3339(),
                    })));
                }
            }
        }
    }

    #[cfg(target_os = "linux")]
    {
        if which::which("ffmpeg").is_ok() {
            let res = tokio::process::Command::new("ffmpeg")
                .args([
                    "-f", "x11grab",
                    "-i", ":0.0",
                    "-vframes", "1",
                    "-f", "image2pipe",
                    "-vcodec", "mjpeg",
                    "-",
                ])
                .output()
                .await;
            if let Ok(out) = res {
                if out.status.success() && !out.stdout.is_empty() {
                    let b64 = base64::engine::general_purpose::STANDARD.encode(&out.stdout);
                    return Ok(Json(serde_json::json!({
                        "success": true,
                        "image_base64": b64,
                        "size_bytes": out.stdout.len(),
                        "timestamp": chrono::Utc::now().to_rfc3339(),
                    })));
                }
            }
        }
    }

    Err((
        axum::http::StatusCode::INTERNAL_SERVER_ERROR,
        Json(serde_json::json!({
            "success": false,
            "error": "Failed to capture workstation screen. Make sure screen recording permissions are allowed."
        })),
    ))
}

pub async fn stop_screen_handler() -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    use std::sync::atomic::Ordering;
    let stream = get_screen_stream();
    stream.is_running.store(false, Ordering::SeqCst);
    if let Some(mut proc) = stream.child_handle.lock().await.take() {
        let _ = proc.kill().await;
    }
    Ok(Json(serde_json::json!({
        "success": true,
        "message": "Screen stream stopped"
    })))
}

pub struct CameraStreamState {
    pub is_running: std::sync::Arc<std::sync::atomic::AtomicBool>,
    pub last_requested_at: std::sync::Arc<std::sync::atomic::AtomicI64>,
    pub latest_frame: std::sync::Arc<tokio::sync::RwLock<Option<(String, std::time::Instant)>>>,
    pub child_handle: std::sync::Arc<tokio::sync::Mutex<Option<tokio::process::Child>>>,
}

impl CameraStreamState {
    pub fn new() -> Self {
        Self {
            is_running: std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false)),
            last_requested_at: std::sync::Arc::new(std::sync::atomic::AtomicI64::new(0)),
            latest_frame: std::sync::Arc::new(tokio::sync::RwLock::new(None)),
            child_handle: std::sync::Arc::new(tokio::sync::Mutex::new(None)),
        }
    }
}

static CAMERA_STREAM: std::sync::OnceLock<CameraStreamState> = std::sync::OnceLock::new();

fn get_camera_stream() -> &'static CameraStreamState {
    CAMERA_STREAM.get_or_init(CameraStreamState::new)
}

pub async fn take_camera_snapshot_handler() -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    use base64::Engine;
    use std::sync::atomic::Ordering;
    use tokio::io::AsyncReadExt;

    let stream = get_camera_stream();
    stream.last_requested_at.store(chrono::Utc::now().timestamp(), Ordering::Relaxed);

    // Watchdog check: If child exited or isn't running, mark for restart
    let need_start = {
        let mut lock = stream.child_handle.lock().await;
        if let Some(ref mut child) = *lock {
            match child.try_wait() {
                Ok(Some(_)) => {
                    *lock = None;
                    stream.is_running.store(false, Ordering::SeqCst);
                    true
                }
                Ok(None) => false,
                Err(_) => true,
            }
        } else {
            true
        }
    };

    // If stream is not currently active, spawn persistent background streaming process
    if need_start || !stream.is_running.load(Ordering::SeqCst) {
        stream.is_running.store(true, Ordering::SeqCst);
        let is_running = stream.is_running.clone();
        let last_requested_at = stream.last_requested_at.clone();
        let latest_frame = stream.latest_frame.clone();
        let child_handle = stream.child_handle.clone();

        tokio::spawn(async move {
            #[cfg(target_os = "macos")]
            {
                let helper_paths = [
                    "/Users/arronkianparejas/.local/bin/agentdeck-camera-streamer",
                    "agentdeck-camera-streamer",
                    "scripts/agentdeck-camera-streamer",
                ];

                let mut helper_bin = None;
                for p in helper_paths {
                    if std::path::Path::new(p).exists() || which::which(p).is_ok() {
                        helper_bin = Some(p);
                        break;
                    }
                }

                if let Some(bin) = helper_bin {
                    let mut c = tokio::process::Command::new(bin);
                    c.args(["0.40"]);
                    c.stdout(std::process::Stdio::piped());
                    c.stderr(std::process::Stdio::null());

                    if let Ok(mut child) = c.spawn() {
                        if let Some(mut stdout) = child.stdout.take() {
                            *child_handle.lock().await = Some(child);

                            let mut len_buf = [0u8; 4];
                            while is_running.load(Ordering::Relaxed) {
                                let now = chrono::Utc::now().timestamp();
                                if now - last_requested_at.load(Ordering::Relaxed) > 15 {
                                    tracing::info!("Webcam stream idle timeout, shutting down hardware camera sensor");
                                    break;
                                }

                                if let Ok(Ok(_)) = tokio::time::timeout(std::time::Duration::from_millis(500), stdout.read_exact(&mut len_buf)).await {
                                    let frame_len = u32::from_be_bytes(len_buf) as usize;
                                    if frame_len > 0 && frame_len < 5_000_000 {
                                        let mut frame_data = vec![0u8; frame_len];
                                        if let Ok(Ok(_)) = tokio::time::timeout(std::time::Duration::from_millis(500), stdout.read_exact(&mut frame_data)).await {
                                            let b64 = base64::engine::general_purpose::STANDARD.encode(&frame_data);
                                            *latest_frame.write().await = Some((b64, std::time::Instant::now()));
                                            continue;
                                        }
                                    }
                                }
                            }

                            if let Some(mut proc) = child_handle.lock().await.take() {
                                let _ = proc.kill().await;
                            }
                        }
                    }
                }
            }

            #[cfg(target_os = "windows")]
            {
                let user_profile = std::env::var("USERPROFILE").unwrap_or_default();
                let local_app_data = std::env::var("LOCALAPPDATA").unwrap_or_default();
                let ffmpeg_candidates = [
                    "ffmpeg".to_string(),
                    format!("{}\\.agentdeck\\bin\\ffmpeg.exe", user_profile),
                    format!("{}\\Microsoft\\WinGet\\Links\\ffmpeg.exe", local_app_data),
                    "C:\\ffmpeg\\bin\\ffmpeg.exe".to_string(),
                    "C:\\ProgramData\\chocolatey\\bin\\ffmpeg.exe".to_string(),
                    "C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe".to_string(),
                ];

                let mut found_bin = None;
                for bin in &ffmpeg_candidates {
                    if which::which(bin).is_ok() || std::path::Path::new(bin).exists() {
                        found_bin = Some(bin.clone());
                        break;
                    }
                }

                if let Some(bin) = found_bin {
                    let mut detected_device = String::new();
                    if let Ok(dev_out) = tokio::process::Command::new(&bin)
                        .args(["-list_devices", "true", "-f", "dshow", "-i", "dummy"])
                        .output()
                        .await
                    {
                        let stderr_str = String::from_utf8_lossy(&dev_out.stderr);
                        for line in stderr_str.lines() {
                            if line.contains("(video)") && line.contains("\"") {
                                if let Some(start) = line.find('\"') {
                                    if let Some(end) = line[start + 1..].find('\"') {
                                        let name = &line[start + 1..start + 1 + end];
                                        if !name.is_empty() {
                                            detected_device = name.to_string();
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    let camera_input = if !detected_device.is_empty() {
                        format!("video={}", detected_device)
                    } else {
                        "video=Integrated Camera".to_string()
                    };

                    let mut c = tokio::process::Command::new(&bin);
                    c.args([
                        "-f", "dshow",
                        "-fflags", "nobuffer",
                        "-flags", "low_delay",
                        "-i", &camera_input,
                        "-framerate", "30",
                        "-f", "image2pipe",
                        "-vcodec", "mjpeg",
                        "-q:v", "4",
                        "-",
                    ]);
                    c.stdout(std::process::Stdio::piped());
                    c.stderr(std::process::Stdio::null());
                    if let Ok(mut child) = c.spawn() {
                        if let Some(mut stdout) = child.stdout.take() {
                            *child_handle.lock().await = Some(child);
                            let mut buffer = Vec::with_capacity(131072);
                            let mut chunk = [0u8; 8192];
                            while is_running.load(Ordering::Relaxed) {
                                let now = chrono::Utc::now().timestamp();
                                if now - last_requested_at.load(Ordering::Relaxed) > 15 { break; }
                                if let Ok(Ok(n)) = tokio::time::timeout(std::time::Duration::from_millis(500), stdout.read(&mut chunk)).await {
                                    if n == 0 { break; }
                                    buffer.extend_from_slice(&chunk[..n]);
                                }
                            }
                        }
                    }
                }
            }

            #[cfg(target_os = "linux")]
            {
                if which::which("ffmpeg").is_ok() {
                    let mut c = tokio::process::Command::new("ffmpeg");
                    c.args([
                        "-f", "v4l2",
                        "-fflags", "nobuffer",
                        "-flags", "low_delay",
                        "-framerate", "30",
                        "-i", "/dev/video0",
                        "-f", "image2pipe",
                        "-vcodec", "mjpeg",
                        "-q:v", "4",
                        "-",
                    ]);
                    c.stdout(std::process::Stdio::piped());
                    c.stderr(std::process::Stdio::null());
                    if let Ok(mut child) = c.spawn() {
                        if let Some(mut stdout) = child.stdout.take() {
                            *child_handle.lock().await = Some(child);
                            let mut buffer = Vec::with_capacity(131072);
                            let mut chunk = [0u8; 8192];
                            while is_running.load(Ordering::Relaxed) {
                                let now = chrono::Utc::now().timestamp();
                                if now - last_requested_at.load(Ordering::Relaxed) > 15 { break; }
                                if let Ok(Ok(n)) = tokio::time::timeout(std::time::Duration::from_millis(500), stdout.read(&mut chunk)).await {
                                    if n == 0 { break; }
                                    buffer.extend_from_slice(&chunk[..n]);
                                }
                            }
                        }
                    }
                }
            }

            is_running.store(false, Ordering::SeqCst);
        });
    }

    // Return the latest fresh frame from memory (wait up to 5000ms on initial hardware cold start)
    for _ in 0..100 {
        if let Some((ref frame, ref instant)) = *stream.latest_frame.read().await {
            if instant.elapsed() < std::time::Duration::from_millis(3000) {
                return Ok(Json(serde_json::json!({
                    "success": true,
                    "image_base64": frame,
                    "live": true,
                    "timestamp": chrono::Utc::now().to_rfc3339(),
                })));
            }
        }
        tokio::time::sleep(std::time::Duration::from_millis(50)).await;
    }

    // Windows fallback: native WinRT MediaCapture if FFmpeg is absent
    #[cfg(target_os = "windows")]
    {
        let ps_camera_script = r#"
            $ErrorActionPreference = 'SilentlyContinue'
            try {
                [Windows.Media.Capture.MediaCapture, Windows.Media.Capture, ContentType=WindowsRuntime] | Out-Null
                [Windows.Media.MediaProperties.ImageEncodingProperties, Windows.Media.MediaProperties, ContentType=WindowsRuntime] | Out-Null
                $mc = New-Object Windows.Media.Capture.MediaCapture
                $initTask = $mc.InitializeAsync().AsTask()
                $initTask.Wait(3000)
                $props = [Windows.Media.MediaProperties.ImageEncodingProperties]::CreateJpeg()
                $memStream = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
                $capTask = $mc.CapturePhotoToStreamAsync($props, $memStream).AsTask()
                $capTask.Wait(3000)
                $reader = New-Object Windows.Storage.Streams.DataReader($memStream.GetInputStreamAt(0))
                $loadTask = $reader.LoadAsync($memStream.Size).AsTask()
                $loadTask.Wait(2000)
                $bytes = New-Object byte[] $memStream.Size
                $reader.ReadBytes($bytes)
                $b64 = [Convert]::ToBase64String($bytes)
                if ($b64 -and $b64.Length -gt 100) {
                    Write-Output $b64
                    exit 0
                }
            } catch {}
        "#;

        if let Ok(ps_out) = tokio::process::Command::new("powershell")
            .args(["-NoProfile", "-NonInteractive", "-Command", ps_camera_script])
            .output()
            .await
        {
            let b64 = String::from_utf8_lossy(&ps_out.stdout).trim().to_string();
            if !b64.is_empty() && b64.len() > 100 {
                let len = b64.len();
                return Ok(Json(serde_json::json!({
                    "success": true,
                    "image_base64": b64,
                    "size_bytes": len,
                    "device": "winrt_mediacapture",
                    "timestamp": chrono::Utc::now().to_rfc3339(),
                })));
            }
        }
    }

    Err((
        axum::http::StatusCode::SERVICE_UNAVAILABLE,
        Json(serde_json::json!({
            "success": false,
            "error": "Workstation webcam capture requires camera permission or ffmpeg installed."
        })),
    ))
}

pub async fn stop_camera_handler() -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    use std::sync::atomic::Ordering;

    let stream = get_camera_stream();
    stream.is_running.store(false, Ordering::SeqCst);
    stream.last_requested_at.store(0, Ordering::Relaxed);
    if let Some(mut proc) = stream.child_handle.lock().await.take() {
        let _ = proc.kill().await;
    }
    *stream.latest_frame.write().await = None;

    Ok(Json(serde_json::json!({
        "success": true,
        "message": "Webcam background stream terminated and camera hardware released."
    })))
}

pub async fn play_sound_handler() -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    #[cfg(target_os = "macos")]
    {
        let _ = tokio::process::Command::new("afplay")
            .arg("/System/Library/Sounds/Glass.aiff")
            .spawn();
    }

    #[cfg(target_os = "windows")]
    {
        let _ = tokio::process::Command::new("powershell")
            .args(["-NoProfile", "-Command", "[System.Media.SystemSounds]::Asterisk.Play(); Start-Sleep -Milliseconds 300; [System.Media.SystemSounds]::Asterisk.Play()"])
            .spawn();
    }

    #[cfg(target_os = "linux")]
    {
        let _ = tokio::process::Command::new("paplay")
            .arg("/usr/share/sounds/freedesktop/stereo/complete.oga")
            .spawn();
    }

    Ok(Json(serde_json::json!({
        "success": true,
        "message": "Sound alert played on workstation for Find Deck locating."
    })))
}

#[derive(serde::Deserialize)]
pub struct SpeakRequest {
    pub text: String,
    pub voice: Option<String>,
    pub action: Option<String>, // "speak" (default), "prompt_active", "both"
}

pub async fn speak_handler(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<SpeakRequest>,
) -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    let clean_text = payload.text.trim().to_string();
    if clean_text.is_empty() {
        return Err((
            axum::http::StatusCode::BAD_REQUEST,
            Json(serde_json::json!({ "error": "Speech text cannot be empty" })),
        ));
    }

    // 1. If action is prompt_active or both, dispatch voice prompt to active session
    let mut dispatched_session_id = None;
    if payload.action.as_deref() == Some("prompt_active") || payload.action.as_deref() == Some("both") {
        if let Ok(sessions) = state.event_bus.db().list_sessions() {
            if let Some(active) = sessions.iter().find(|s| s.status == crate::models::AgentStatus::Running) {
                let _ = state.agent_manager.send_prompt(&active.agent, &active.id, &clean_text).await;
                dispatched_session_id = Some(active.id.clone());
            }
        }
    }

    // 2. Play / Speak text on Workstation hardware speakers
    if payload.action.as_deref() != Some("prompt_active") {
        #[cfg(target_os = "macos")]
        {
            let voice_arg = payload.voice.as_deref().unwrap_or("Daniel");
            let _ = tokio::process::Command::new("say")
                .args(["-v", voice_arg, &clean_text])
                .spawn();
        }

        #[cfg(target_os = "windows")]
        {
            let escaped_text = clean_text.replace('\'', "''");
            let ps_script = format!(
                r#"Add-Type -AssemblyName System.Speech; $s = New-Object System.Speech.Synthesis.SpeechSynthesizer; $s.Rate = 0; $s.Speak('{}');"#,
                escaped_text
            );
            let _ = tokio::process::Command::new("powershell")
                .args(["-NoProfile", "-Command", &ps_script])
                .spawn();
        }

        #[cfg(target_os = "linux")]
        {
            if which::which("spd-say").is_ok() {
                let _ = tokio::process::Command::new("spd-say")
                    .arg(&clean_text)
                    .spawn();
            } else if which::which("espeak").is_ok() {
                let _ = tokio::process::Command::new("espeak")
                    .arg(&clean_text)
                    .spawn();
            }
        }
    }

    Ok(Json(serde_json::json!({
        "success": true,
        "text": clean_text,
        "action": payload.action.unwrap_or_else(|| "speak".to_string()),
        "dispatched_to_session": dispatched_session_id,
        "message": "Voice command successfully processed on workstation"
    })))
}

#[derive(serde::Deserialize)]
pub struct SystemFileQuery {
    pub path: String,
}

pub async fn read_system_file_handler(
    axum::extract::Query(query): axum::extract::Query<SystemFileQuery>,
) -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    let p = std::path::PathBuf::from(&query.path);
    if !p.exists() || !p.is_file() {
        return Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(serde_json::json!({ "error": "File not found on workstation" })),
        ));
    }

    match std::fs::read_to_string(&p) {
        Ok(content) => {
            let ext = p.extension().and_then(|e| e.to_str()).unwrap_or("");
            Ok(Json(serde_json::json!({
                "path": query.path,
                "filename": p.file_name().map(|n| n.to_string_lossy()).unwrap_or_default(),
                "content": content,
                "extension": ext,
                "size_bytes": content.len(),
            })))
        }
        Err(e) => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({ "error": format!("Failed to read file: {}", e) })),
        )),
    }
}

#[derive(serde::Deserialize)]
pub struct AntigravityChatQuery {
    pub id: Option<String>,
    pub limit: Option<usize>,
}

pub async fn antigravity_live_chat_handler(
    axum::extract::Query(query): axum::extract::Query<AntigravityChatQuery>,
) -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    let home = std::env::var("USERPROFILE")
        .or_else(|_| std::env::var("HOME"))
        .unwrap_or_else(|_| "/Users/arronkianparejas".to_string());

    let brain_dir = std::path::PathBuf::from(&home)
        .join(".gemini")
        .join("antigravity-ide")
        .join("brain");

    if !brain_dir.exists() {
        return Ok(Json(serde_json::json!({
            "success": true,
            "conversation_id": null,
            "conversations": [],
            "messages": [],
            "note": "Antigravity IDE brain directory not found on host."
        })));
    }

    let mut conv_dirs = Vec::new();
    if let Ok(read_dir) = std::fs::read_dir(&brain_dir) {
        for entry in read_dir.flatten() {
            let p = entry.path();
            if p.is_dir() {
                let name = entry.file_name().to_string_lossy().to_string();
                if name != "tempmediaStorage" && !name.starts_with('.') {
                    let log_file = p.join(".system_generated").join("logs").join("transcript.jsonl");
                    let modified = if let Ok(meta) = log_file.metadata() {
                        meta.modified().unwrap_or(std::time::SystemTime::UNIX_EPOCH)
                    } else if let Ok(meta) = p.metadata() {
                        meta.modified().unwrap_or(std::time::SystemTime::UNIX_EPOCH)
                    } else {
                        std::time::SystemTime::UNIX_EPOCH
                    };
                    conv_dirs.push((name, log_file, modified));
                }
            }
        }
    }

    conv_dirs.sort_by(|a, b| b.2.cmp(&a.2));

    let mut active_id = query.id.clone().unwrap_or_default();
    if active_id.is_empty() || !brain_dir.join(&active_id).join(".system_generated").join("logs").join("transcript.jsonl").exists() {
        active_id = conv_dirs.first().map(|(id, _, _)| id.clone()).unwrap_or_default();
    }

    let target_log = brain_dir
        .join(&active_id)
        .join(".system_generated")
        .join("logs")
        .join("transcript.jsonl");

    let mut messages = Vec::new();
    let mut edited_files_set = std::collections::HashSet::new();
    let mut active_model = "Gemini 3.7 Flash".to_string();
    let active_effort = "High".to_string();
    let mut is_generating = false;

    if target_log.exists() {
        if let Ok(content) = std::fs::read_to_string(&target_log) {
            let lines: Vec<&str> = content.lines().collect();
            let limit = query.limit.unwrap_or(120);
            let start = if lines.len() > limit { lines.len() - limit } else { 0 };

            for (idx, line) in lines[start..].iter().enumerate() {
                if let Ok(val) = serde_json::from_str::<serde_json::Value>(line) {
                    let step_type = val["type"].as_str().unwrap_or("");
                    let source = val["source"].as_str().unwrap_or("");
                    let content_str = val["content"].as_str().unwrap_or("");
                    let thinking_str = val["thinking"].as_str().unwrap_or("");
                    let tool_calls = val["tool_calls"].clone();
                    let created_at = val["created_at"].as_str().unwrap_or("");

                    if (start + idx) == lines.len() - 1 {
                        is_generating = step_type == "PLANNER_RESPONSE" && content_str.is_empty();
                    }

                    if step_type == "USER_INPUT" || source == "USER_EXPLICIT" {
                        let mut user_msg = content_str.to_string();
                        if let Some(start_tag) = user_msg.find("<USER_REQUEST>") {
                            if let Some(end_tag) = user_msg.find("</USER_REQUEST>") {
                                user_msg = user_msg[start_tag + 14..end_tag].trim().to_string();
                            }
                        }
                        if let Some(start_tag) = content_str.find("<USER_SETTINGS_CHANGE>") {
                            if let Some(end_tag) = content_str.find("</USER_SETTINGS_CHANGE>") {
                                let change = &content_str[start_tag + 22..end_tag];
                                if let Some(pos) = change.find("to ") {
                                    let model_part = change[pos + 3..].trim();
                                    if let Some(dot) = model_part.find('.') {
                                        active_model = model_part[..dot].trim().to_string();
                                    } else {
                                        active_model = model_part.to_string();
                                    }
                                }
                            }
                        }
                        messages.push(serde_json::json!({
                            "role": "user",
                            "type": "USER_INPUT",
                            "content": user_msg,
                            "timestamp": created_at,
                            "status": val["status"].as_str().unwrap_or("DONE"),
                        }));
                    } else if step_type == "PLANNER_RESPONSE" || source == "MODEL" {
                        if !thinking_str.is_empty() {
                            messages.push(serde_json::json!({
                                "role": "thought",
                                "type": "THINKING",
                                "content": thinking_str,
                                "timestamp": created_at,
                            }));
                        }
                        if !content_str.is_empty() {
                            messages.push(serde_json::json!({
                                "role": "agent",
                                "type": "AGENT_MESSAGE",
                                "content": content_str,
                                "timestamp": created_at,
                            }));
                        }
                        if tool_calls.is_array() && !tool_calls.as_array().unwrap().is_empty() {
                            let mut structured_tools = Vec::new();
                            if let Some(arr) = tool_calls.as_array() {
                                for t in arr {
                                    let name = t["name"].as_str().unwrap_or("tool");
                                    let args = &t["args"];
                                    
                                    let mut tool_obj = serde_json::json!({
                                        "name": name,
                                        "raw_args": args,
                                    });

                                    if name == "replace_file_content" || name == "multi_replace_file_content" {
                                        let target = args["TargetFile"].as_str().unwrap_or("").to_string();
                                        let instruction = args["Instruction"].as_str().unwrap_or("").to_string();
                                        let desc = args["Description"].as_str().unwrap_or("").to_string();
                                        let replacement = args["ReplacementContent"].as_str().unwrap_or("").to_string();
                                        let file_basename = std::path::Path::new(&target)
                                            .file_name()
                                            .map(|n| n.to_string_lossy().to_string())
                                            .unwrap_or_else(|| target.clone());

                                        if !target.is_empty() {
                                            edited_files_set.insert(target.clone());
                                        }

                                        tool_obj["category"] = serde_json::json!("FILE_EDIT");
                                        tool_obj["file_path"] = serde_json::json!(target);
                                        tool_obj["file_name"] = serde_json::json!(file_basename);
                                        tool_obj["instruction"] = serde_json::json!(instruction);
                                        tool_obj["description"] = serde_json::json!(desc);
                                        tool_obj["diff_snippet"] = serde_json::json!(replacement);
                                    } else if name == "write_to_file" {
                                        let target = args["TargetFile"].as_str().unwrap_or("").to_string();
                                        let desc = args["Description"].as_str().unwrap_or("").to_string();
                                        let code = args["CodeContent"].as_str().unwrap_or("").to_string();
                                        let file_basename = std::path::Path::new(&target)
                                            .file_name()
                                            .map(|n| n.to_string_lossy().to_string())
                                            .unwrap_or_else(|| target.clone());

                                        if !target.is_empty() {
                                            edited_files_set.insert(target.clone());
                                        }

                                        tool_obj["category"] = serde_json::json!("FILE_CREATE");
                                        tool_obj["file_path"] = serde_json::json!(target);
                                        tool_obj["file_name"] = serde_json::json!(file_basename);
                                        tool_obj["description"] = serde_json::json!(desc);
                                        tool_obj["diff_snippet"] = serde_json::json!(code);
                                    } else if name == "run_command" {
                                        let cmd = args["CommandLine"].as_str().unwrap_or("").to_string();
                                        let cwd = args["Cwd"].as_str().unwrap_or("").to_string();
                                        tool_obj["category"] = serde_json::json!("COMMAND");
                                        tool_obj["command"] = serde_json::json!(cmd);
                                        tool_obj["cwd"] = serde_json::json!(cwd);
                                    } else if name == "generate_image" {
                                        let prompt = args["Prompt"].as_str().unwrap_or("").to_string();
                                        let img_name = args["ImageName"].as_str().unwrap_or("").to_string();
                                        tool_obj["category"] = serde_json::json!("IMAGE");
                                        tool_obj["prompt"] = serde_json::json!(prompt);
                                        tool_obj["image_name"] = serde_json::json!(img_name);
                                    } else if name == "view_file" || name == "list_dir" || name == "grep_search" {
                                        let p = args["AbsolutePath"]
                                            .as_str()
                                            .or_else(|| args["DirectoryPath"].as_str())
                                            .or_else(|| args["SearchPath"].as_str())
                                            .unwrap_or("")
                                            .to_string();
                                        tool_obj["category"] = serde_json::json!("INSPECTION");
                                        tool_obj["target"] = serde_json::json!(p);
                                    }

                                    structured_tools.push(tool_obj);
                                }
                            }

                            messages.push(serde_json::json!({
                                "role": "tool_call",
                                "type": "TOOL_CALLS",
                                "tools": structured_tools,
                                "timestamp": created_at,
                            }));
                        }
                    } else if step_type == "RUN_COMMAND" || step_type == "REPLACE_FILE_CONTENT" || step_type == "WRITE_TO_FILE" {
                        messages.push(serde_json::json!({
                            "role": "tool_output",
                            "type": step_type,
                            "content": content_str,
                            "exit_code": val["exit_code"],
                            "timestamp": created_at,
                        }));
                    } else if !content_str.is_empty() && step_type != "CHECKPOINT" && step_type != "KNOWLEDGE_ARTIFACTS" && step_type != "CONVERSATION_HISTORY" {
                        messages.push(serde_json::json!({
                            "role": "system",
                            "type": step_type,
                            "content": content_str,
                            "timestamp": created_at,
                        }));
                    }
                }
            }
        }
    }

    let mut edited_files: Vec<String> = edited_files_set.into_iter().collect();
    edited_files.sort();

    // 3. Compute real-time git diff numstat for uncommitted files & decisions
    let mut changed_files = Vec::new();
    let cwd = std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from("/Users/arronkianparejas/agentdeck"));
    if let Ok(output) = std::process::Command::new("git")
        .args(["diff", "--numstat"])
        .current_dir(&cwd)
        .output()
    {
        if let Ok(numstat) = String::from_utf8(output.stdout) {
            for line in numstat.lines() {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 3 {
                    let added = parts[0].parse::<u64>().unwrap_or(0);
                    let deleted = parts[1].parse::<u64>().unwrap_or(0);
                    let path = parts[2..].join(" ");
                    let name = std::path::Path::new(&path)
                        .file_name()
                        .map(|n| n.to_string_lossy().to_string())
                        .unwrap_or_else(|| path.clone());

                    changed_files.push(serde_json::json!({
                        "file_path": path,
                        "file_name": name,
                        "additions": added,
                        "deletions": deleted,
                        "status": "modified",
                    }));
                }
            }
        }
    }

    // Also check untracked new files
    if let Ok(output) = std::process::Command::new("git")
        .args(["status", "--porcelain"])
        .current_dir(&cwd)
        .output()
    {
        if let Ok(porcelain) = String::from_utf8(output.stdout) {
            for line in porcelain.lines() {
                if line.starts_with("?? ") {
                    let path = line[3..].trim().to_string();
                    let name = std::path::Path::new(&path)
                        .file_name()
                        .map(|n| n.to_string_lossy().to_string())
                        .unwrap_or_else(|| path.clone());

                    if !changed_files.iter().any(|c| c["file_path"] == path) {
                        changed_files.push(serde_json::json!({
                            "file_path": path,
                            "file_name": name,
                            "additions": 1,
                            "deletions": 0,
                            "status": "created",
                        }));
                    }
                }
            }
        }
    }

    let conv_list: Vec<serde_json::Value> = conv_dirs
        .iter()
        .take(15)
        .map(|(id, _, _mod_time)| {
            serde_json::json!({
                "id": id,
                "is_active": id == &active_id,
            })
        })
        .collect();

    Ok(Json(serde_json::json!({
        "success": true,
        "active_conversation_id": active_id,
        "conversations": conv_list,
        "total_messages": messages.len(),
        "messages": messages,
        "edited_files": edited_files,
        "changed_files": changed_files,
        "active_model": active_model,
        "active_effort": active_effort,
        "is_generating": is_generating,
        "has_uncommitted_changes": !changed_files.is_empty(),
    })))
}

#[derive(serde::Deserialize)]
pub struct AntigravityDecisionRequest {
    pub action: String, // "accept_all", "reject_all", "revert_file", "stop", "continue"
    pub file_path: Option<String>,
    pub prompt: Option<String>,
}

pub async fn antigravity_decision_handler(
    State(state): State<Arc<AppState>>,
    Json(req): Json<AntigravityDecisionRequest>,
) -> Result<Json<serde_json::Value>, (axum::http::StatusCode, String)> {
    let cwd = std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from("/Users/arronkianparejas/agentdeck"));

    match req.action.as_str() {
        "accept_all" => {
            let res = std::process::Command::new("git")
                .args(["add", "-A"])
                .current_dir(&cwd)
                .output();

            let success = res.map(|o| o.status.success()).unwrap_or(false);
            Ok(Json(serde_json::json!({
                "success": success,
                "action": "accept_all",
                "message": "All file modifications accepted and staged.",
            })))
        }
        "reject_all" => {
            let _ = std::process::Command::new("git")
                .args(["restore", "."])
                .current_dir(&cwd)
                .output();
            let _ = std::process::Command::new("git")
                .args(["clean", "-fd"])
                .current_dir(&cwd)
                .output();

            Ok(Json(serde_json::json!({
                "success": true,
                "action": "reject_all",
                "message": "All uncommitted file edits reverted.",
            })))
        }
        "revert_file" => {
            if let Some(file) = &req.file_path {
                let _ = std::process::Command::new("git")
                    .args(["restore", file])
                    .current_dir(&cwd)
                    .output();
            }
            Ok(Json(serde_json::json!({
                "success": true,
                "action": "revert_file",
                "file": req.file_path,
            })))
        }
        "stop" => {
            let _ = state.agent_manager.stop_session("antigravity", "active").await;
            Ok(Json(serde_json::json!({
                "success": true,
                "action": "stop",
                "message": "Agent session halted.",
            })))
        }
        "continue" => {
            let prompt = req.prompt.unwrap_or_else(|| "Proceed with execution.".to_string());
            Ok(Json(serde_json::json!({
                "success": true,
                "action": "continue",
                "prompt": prompt,
            })))
        }
        _ => Err((axum::http::StatusCode::BAD_REQUEST, "Unknown decision action".to_string())),
    }
}



