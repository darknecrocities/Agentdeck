use tokio::process::Command;

#[derive(Debug, Clone)]
pub struct TailscaleInfo {
    pub installed: bool,
    pub ip: Option<String>,
    pub status: String,
}

pub struct TailscaleManager;

impl TailscaleManager {
    pub async fn detect() -> TailscaleInfo {
        let mut binary_candidates = vec![
            "tailscale",
            "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
            "/usr/local/bin/tailscale",
            "/opt/homebrew/bin/tailscale",
            "C:\\Program Files\\Tailscale\\tailscale.exe",
            "C:\\Program Files (x86)\\Tailscale\\tailscale.exe",
        ];

        // Check localappdata on Windows
        if let Ok(local_app_data) = std::env::var("LOCALAPPDATA") {
            let win_path = format!("{}\\Tailscale\\tailscale.exe", local_app_data);
            if std::path::Path::new(&win_path).exists() {
                binary_candidates.insert(0, Box::leak(win_path.into_boxed_str()));
            }
        }

        let mut found_bin = None;
        for b in &binary_candidates {
            if which::which(b).is_ok() || std::path::Path::new(b).exists() {
                found_bin = Some(b.to_string());
                break;
            }
        }

        if found_bin.is_none() {
            // Check if tailscale interface exists on Unix via ifconfig
            #[cfg(not(target_os = "windows"))]
            {
                if let Ok(out) = Command::new("ifconfig").arg("utun").output().await {
                    let text = String::from_utf8_lossy(&out.stdout);
                    if text.contains("100.") {
                        return TailscaleInfo {
                            installed: true,
                            ip: Self::extract_ip_from_text(&text),
                            status: "online (interface detected)".to_string(),
                        };
                    }
                }
            }

            // Check if tailscale interface exists on Windows via PowerShell / ipconfig
            #[cfg(target_os = "windows")]
            {
                let ps_script = r#"(Get-NetIPAddress -InterfaceAlias "*Tailscale*" -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress"#;
                if let Ok(out) = Command::new("powershell").args(["-NoProfile", "-Command", ps_script]).output().await {
                    let text = String::from_utf8_lossy(&out.stdout).trim().to_string();
                    if text.starts_with("100.") {
                        return TailscaleInfo {
                            installed: true,
                            ip: Some(text),
                            status: "online (Tailscale IPv4 detected)".to_string(),
                        };
                    }
                }

                if let Ok(out) = Command::new("ipconfig").output().await {
                    let text = String::from_utf8_lossy(&out.stdout);
                    if text.contains("100.") {
                        return TailscaleInfo {
                            installed: true,
                            ip: Self::extract_ip_from_text(&text),
                            status: "online (ipconfig detected)".to_string(),
                        };
                    }
                }
            }

            return TailscaleInfo {
                installed: false,
                ip: None,
                status: "not_installed".to_string(),
            };
        }

        let bin = found_bin.unwrap();
        // Check ip
        let ip_out = Command::new(&bin).arg("ip").arg("-4").output().await;
        let ip = match ip_out {
            Ok(out) if out.status.success() => {
                let s = String::from_utf8_lossy(&out.stdout).trim().to_string();
                if !s.is_empty() {
                    Some(s)
                } else {
                    None
                }
            }
            _ => None,
        };

        // Check status
        let status_out = Command::new(&bin).arg("status").output().await;
        let status = match status_out {
            Ok(out) if out.status.success() => "online".to_string(),
            _ => "offline_or_stopped".to_string(),
        };

        TailscaleInfo {
            installed: true,
            ip,
            status,
        }
    }

    fn extract_ip_from_text(text: &str) -> Option<String> {
        for word in text.split_whitespace() {
            let clean = word.trim_matches(|c: char| !c.is_ascii_digit() && c != '.');
            if clean.starts_with("100.") && clean.split('.').count() == 4 {
                return Some(clean.to_string());
            }
        }
        None
    }
}
