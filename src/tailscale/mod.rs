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
        let binary_candidates = vec!["tailscale", "/Applications/Tailscale.app/Contents/MacOS/Tailscale", "/usr/local/bin/tailscale", "/opt/homebrew/bin/tailscale"];
        let mut found_bin = None;

        for b in binary_candidates {
            if which::which(b).is_ok() || std::path::Path::new(b).exists() {
                found_bin = Some(b.to_string());
                break;
            }
        }

        if found_bin.is_none() {
            // Check if tailscale interface exists via ifconfig
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
            if word.starts_with("100.") && word.split('.').count() == 4 {
                return Some(word.to_string());
            }
        }
        None
    }
}
