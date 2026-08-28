use super::capabilities::get_antigravity_capabilities;
use super::process::AntigravityProcess;
use super::session::AntigravitySessionState;
use crate::agents::r#trait::AgentAdapter;
use crate::events::EventBus;
use crate::models::{AgentCapabilities, AgentInfo, AgentSession, AgentStartRequest, AgentStatus};
use async_trait::async_trait;
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::process::Command;
use tokio::sync::RwLock;


pub struct AntigravityAgent {
    binary_override: Option<String>,
    active_processes: Arc<RwLock<HashMap<String, Arc<AntigravityProcess>>>>,
}

impl AntigravityAgent {
    pub fn new(binary_override: Option<String>) -> Self {
        Self {
            binary_override,
            active_processes: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub fn resolve_binary(&self) -> String {
        if let Some(b) = &self.binary_override {
            if PathBuf::from(b).exists() {
                return b.clone();
            }
        }

        // Standard paths
        let home = std::env::var("HOME").unwrap_or_else(|_| "/Users/arronkianparejas".to_string());
        let local_bin_agy = format!("{home}/.local/bin/agy");
        let gemini_bin_agy = format!("{home}/.gemini/antigravity/bin/agy");

        let candidates = vec![
            "agy",
            &local_bin_agy,
            "/opt/homebrew/bin/agy",
            "/usr/local/bin/agy",
            &gemini_bin_agy,
        ];

        for c in candidates {
            if which::which(c).is_ok() || PathBuf::from(c).exists() {
                return c.to_string();
            }
        }

        self.binary_override.clone().unwrap_or_else(|| "agy".to_string())
    }
}

#[async_trait]
impl AgentAdapter for AntigravityAgent {
    fn id(&self) -> &str {
        "antigravity"
    }

    fn display_name(&self) -> &str {
        "Antigravity CLI"
    }

    async fn detect(&self) -> anyhow::Result<AgentInfo> {
        let binary = self.resolve_binary();
        let which_res = which::which(&binary);
        let exists = which_res.is_ok() || PathBuf::from(&binary).exists();

        let mut version = None;
        let mut authenticated = false;

        if exists {
            let output = Command::new(&binary).arg("--version").output().await;
            if let Ok(out) = output {
                if out.status.success() {
                    let v_str = String::from_utf8_lossy(&out.stdout).trim().to_string();
                    version = Some(if v_str.is_empty() {
                        "1.0.0".to_string()
                    } else {
                        v_str
                    });
                    authenticated = true;
                }
            }
        }

        Ok(AgentInfo {
            id: self.id().to_string(),
            name: self.id().to_string(),
            display_name: self.display_name().to_string(),
            binary_path: if exists { Some(binary) } else { None },
            installed: exists,
            version,
            authenticated,
            capabilities: self.capabilities().await?,
        })
    }

    async fn start(&self, request: AgentStartRequest, event_bus: EventBus) -> anyhow::Result<AgentSession> {
        let binary = self.resolve_binary();
        let state = AntigravitySessionState::new(
            &request.project_id,
            &request.workspace_path,
            request.conversation_id.clone(),
        );

        let process = AntigravityProcess::spawn(
            &binary,
            &request.workspace_path,
            &request.prompt,
            request.conversation_id.as_deref(),
            request.model.as_deref(),
            request.effort.as_deref(),
            state.session.clone(),
            event_bus,
        )
        .await?;

        let session = process.session.clone();
        let process_arc = Arc::new(process);

        let mut lock = self.active_processes.write().await;
        lock.insert(session.id.clone(), process_arc);

        Ok(session)
    }

    async fn send_prompt(&self, session_id: &str, prompt: &str) -> anyhow::Result<()> {
        let lock = self.active_processes.read().await;
        if let Some(process) = lock.get(session_id) {
            process.write_stdin(prompt).await?;
            Ok(())
        } else {
            Err(anyhow::anyhow!("Session {} not actively running", session_id))
        }
    }

    async fn continue_session(&self, session_id: &str, event_bus: EventBus) -> anyhow::Result<()> {
        if let Some(session) = event_bus.db().get_session(session_id)? {
            let request = AgentStartRequest {
                project_id: session.project_id,
                workspace_path: session.workspace,
                prompt: String::new(),
                conversation_id: session.conversation_id.or(Some(session_id.to_string())),
                model: None,
                effort: None,
            };
            self.start(request, event_bus).await?;
            Ok(())
        } else {
            Err(anyhow::anyhow!("Session not found: {}", session_id))
        }
    }

    async fn stop(&self, session_id: &str) -> anyhow::Result<()> {
        let mut lock = self.active_processes.write().await;
        if let Some(proc) = lock.remove(session_id) {
            if let Some(pid) = proc.child_pid {
                #[cfg(unix)]
                unsafe {
                    libc::kill(pid as i32, libc::SIGTERM);
                }
            }
        }
        Ok(())
    }

    async fn kill(&self, session_id: &str) -> anyhow::Result<()> {
        let mut lock = self.active_processes.write().await;
        if let Some(proc) = lock.remove(session_id) {
            if let Some(pid) = proc.child_pid {
                #[cfg(unix)]
                unsafe {
                    libc::kill(pid as i32, libc::SIGKILL);
                }
            }
        }
        Ok(())
    }

    async fn status(&self, session_id: &str) -> anyhow::Result<AgentStatus> {
        let lock = self.active_processes.read().await;
        if lock.contains_key(session_id) {
            Ok(AgentStatus::Running)
        } else {
            Ok(AgentStatus::Stopped)
        }
    }

    async fn capabilities(&self) -> anyhow::Result<AgentCapabilities> {
        Ok(get_antigravity_capabilities())
    }
}
