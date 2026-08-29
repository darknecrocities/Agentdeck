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

pub async fn take_screenshot_handler() -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    use base64::Engine;
    let temp_dir = std::env::temp_dir();
    let file_name = format!("agentdeck_screen_{}.jpg", chrono::Utc::now().timestamp_millis());
    let target_path = temp_dir.join(&file_name);

    #[cfg(target_os = "macos")]
    {
        let output = tokio::process::Command::new("screencapture")
            .args(["-x", "-t", "jpg", target_path.to_str().unwrap_or("/tmp/screenshot.jpg")])
            .output()
            .await;

        if let Ok(out) = output {
            if out.status.success() && target_path.exists() {
                if let Ok(bytes) = std::fs::read(&target_path) {
                    let _ = std::fs::remove_file(&target_path);
                    let b64 = base64::engine::general_purpose::STANDARD.encode(&bytes);
                    return Ok(Json(serde_json::json!({
                        "success": true,
                        "image_base64": b64,
                        "size_bytes": bytes.len(),
                        "timestamp": chrono::Utc::now().to_rfc3339(),
                    })));
                }
            }
        }

        // Fallback to ffmpeg screen capture on macOS
        let ffmpeg_candidates = ["ffmpeg", "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"];
        for bin in ffmpeg_candidates {
            if which::which(bin).is_ok() || std::path::Path::new(bin).exists() {
                let res = tokio::process::Command::new(bin)
                    .args([
                        "-f", "avfoundation",
                        "-i", "1:none",
                        "-vframes", "1",
                        "-pix_fmt", "yuv420p",
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
                break;
            }
        }
    }

    #[cfg(target_os = "windows")]
    {
        // 1. Fast direct stdout capture with ffmpeg gdigrab if available
        if which::which("ffmpeg").is_ok() {
            let res = tokio::process::Command::new("ffmpeg")
                .args([
                    "-f", "gdigrab",
                    "-framerate", "30",
                    "-i", "desktop",
                    "-vframes", "1",
                    "-pix_fmt", "yuv420p",
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

        // 2. High-speed in-memory PowerShell GDI screen grab without disk IO
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

pub async fn take_camera_snapshot_handler() -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    use base64::Engine;

    #[cfg(target_os = "macos")]
    {
        let ffmpeg_candidates = ["/opt/homebrew/bin/ffmpeg", "ffmpeg", "/usr/local/bin/ffmpeg"];
        for bin in ffmpeg_candidates {
            if which::which(bin).is_ok() || std::path::Path::new(bin).exists() {
                let res = tokio::process::Command::new(bin)
                    .args([
                        "-f", "avfoundation",
                        "-framerate", "30",
                        "-video_size", "1280x720",
                        "-i", "0:none",
                        "-vframes", "1",
                        "-pix_fmt", "yuv420p",
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
            // 1. Discover available DirectShow video device name dynamically
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

            let mut try_names = Vec::new();
            if !detected_device.is_empty() {
                try_names.push(detected_device.clone());
            }
            try_names.extend(vec![
                "Integrated Camera".to_string(),
                "HD WebCam".to_string(),
                "HD Camera".to_string(),
                "USB Camera".to_string(),
                "Camera".to_string(),
                "Integrated Webcam".to_string(),
                "OBS Virtual Camera".to_string(),
            ]);

            for cam in try_names {
                let res = tokio::process::Command::new(&bin)
                    .args([
                        "-f", "dshow",
                        "-i", &format!("video={}", cam),
                        "-vframes", "1",
                        "-pix_fmt", "yuv420p",
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
                            "device": cam,
                            "timestamp": chrono::Utc::now().to_rfc3339(),
                        })));
                    }
                }
            }

            // Fallback: device index 0 via vfwcap
            let res2 = tokio::process::Command::new(&bin)
                .args([
                    "-f", "vfwcap",
                    "-i", "0",
                    "-vframes", "1",
                    "-f", "image2pipe",
                    "-vcodec", "mjpeg",
                    "-",
                ])
                .output()
                .await;

            if let Ok(out) = res2 {
                if out.status.success() && !out.stdout.is_empty() {
                    let b64 = base64::engine::general_purpose::STANDARD.encode(&out.stdout);
                    return Ok(Json(serde_json::json!({
                        "success": true,
                        "image_base64": b64,
                        "size_bytes": out.stdout.len(),
                        "device": "vfwcap:0",
                        "timestamp": chrono::Utc::now().to_rfc3339(),
                    })));
                }
            }
        }

        // 2. Native Windows WinRT MediaCapture API fallback (Zero external dependencies)
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

    #[cfg(target_os = "linux")]
    {
        if which::which("ffmpeg").is_ok() {
            let res = tokio::process::Command::new("ffmpeg")
                .args([
                    "-f", "v4l2",
                    "-i", "/dev/video0",
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
        axum::http::StatusCode::SERVICE_UNAVAILABLE,
        Json(serde_json::json!({
            "success": false,
            "error": "Workstation webcam capture requires camera permission or ffmpeg installed."
        })),
    ))
}

pub async fn stop_camera_handler() -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    #[cfg(target_os = "macos")]
    {
        let _ = tokio::process::Command::new("pkill")
            .args(["-9", "-f", "ffmpeg"])
            .output()
            .await;
        let _ = std::fs::remove_file("/tmp/agentdeck_cam_live.jpg");
    }

    #[cfg(target_os = "windows")]
    {
        let _ = tokio::process::Command::new("taskkill")
            .args(["/F", "/IM", "ffmpeg.exe"])
            .output()
            .await;
    }

    #[cfg(target_os = "linux")]
    {
        let _ = tokio::process::Command::new("pkill")
            .args(["-9", "-f", "ffmpeg"])
            .output()
            .await;
    }

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

    let active_id = query.id.clone().unwrap_or_else(|| {
        conv_dirs.first().map(|(id, _, _)| id.clone()).unwrap_or_default()
    });

    let target_log = brain_dir
        .join(&active_id)
        .join(".system_generated")
        .join("logs")
        .join("transcript.jsonl");

    let mut messages = Vec::new();
    if target_log.exists() {
        if let Ok(content) = std::fs::read_to_string(&target_log) {
            let lines: Vec<&str> = content.lines().collect();
            let limit = query.limit.unwrap_or(80);
            let start = if lines.len() > limit { lines.len() - limit } else { 0 };

            for line in &lines[start..] {
                if let Ok(val) = serde_json::from_str::<serde_json::Value>(line) {
                    let step_type = val["type"].as_str().unwrap_or("");
                    let source = val["source"].as_str().unwrap_or("");
                    let content_str = val["content"].as_str().unwrap_or("");
                    let thinking_str = val["thinking"].as_str().unwrap_or("");
                    let tool_calls = val["tool_calls"].clone();
                    let created_at = val["created_at"].as_str().unwrap_or("");

                    if step_type == "USER_INPUT" || source == "USER_EXPLICIT" {
                        let mut user_msg = content_str.to_string();
                        if let Some(start_tag) = user_msg.find("<USER_REQUEST>") {
                            if let Some(end_tag) = user_msg.find("</USER_REQUEST>") {
                                user_msg = user_msg[start_tag + 14..end_tag].trim().to_string();
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
                            messages.push(serde_json::json!({
                                "role": "tool_call",
                                "type": "TOOL_CALLS",
                                "tools": tool_calls,
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
    })))
}



