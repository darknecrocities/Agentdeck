use crate::agents::r#trait::AgentAdapter;
use crate::events::EventBus;
use crate::models::{AgentCapabilities, AgentEventPayload, AgentInfo, AgentSession, AgentStartRequest, AgentStatus};
use async_trait::async_trait;
use chrono::Utc;
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Stdio;
use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;
use tokio::sync::RwLock;
use uuid::Uuid;

pub struct ClaudeCodeAdapter {
    binary: String,
    active_sessions: Arc<RwLock<HashMap<String, u32>>>,
}

impl ClaudeCodeAdapter {
    pub fn new(binary: Option<String>) -> Self {
        Self {
            binary: binary.unwrap_or_else(|| "claude".to_string()),
            active_sessions: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    fn resolve_binary(&self) -> String {
        if PathBuf::from(&self.binary).exists() {
            return self.binary.clone();
        }
        let candidates = vec![
            "claude",
            "/Users/arronkianparejas/.nvm/versions/node/v20.20.2/bin/claude",
            "/usr/local/bin/claude",
        ];
        for c in candidates {
            if PathBuf::from(c).exists() {
                return c.to_string();
            }
        }
        self.binary.clone()
    }
}

#[async_trait]
impl AgentAdapter for ClaudeCodeAdapter {
    fn id(&self) -> &str {
        "claude"
    }

    fn display_name(&self) -> &str {
        "Claude Code"
    }

    async fn detect(&self) -> anyhow::Result<AgentInfo> {
        let binary = self.resolve_binary();
        let exists = PathBuf::from(&binary).exists() || which::which(&binary).is_ok();
        let mut version = None;
        if exists {
            if let Ok(out) = Command::new(&binary).arg("--version").output().await {
                if out.status.success() {
                    version = Some(String::from_utf8_lossy(&out.stdout).trim().to_string());
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
            authenticated: exists,
            capabilities: self.capabilities().await?,
        })
    }

    async fn start(&self, request: AgentStartRequest, event_bus: EventBus) -> anyhow::Result<AgentSession> {
        let binary = self.resolve_binary();
        let now = Utc::now();
        let session_id = Uuid::new_v4().to_string();

        let mut session = AgentSession {
            id: session_id.clone(),
            agent: "claude".to_string(),
            conversation_id: request.conversation_id,
            project_id: request.project_id.clone(),
            workspace: request.workspace_path.clone(),
            status: AgentStatus::Running,
            started_at: now,
            last_activity: now,
            pid: None,
            last_task: Some(request.prompt.clone()),
            progress_percent: None,
        };

        let mut cmd = Command::new(&binary);
        cmd.current_dir(&request.workspace_path);
        cmd.arg("-p").arg(&request.prompt);
        cmd.stdout(Stdio::piped());
        cmd.stderr(Stdio::piped());

        let mut child = cmd.spawn()?;
        let pid = child.id();
        session.pid = pid;

        let _ = event_bus.db().save_session(&session);
        let _ = event_bus.publish(
            Some(&session.id),
            Some(&session.project_id),
            "session_started",
            AgentEventPayload::SessionStarted {
                session_id: session.id.clone(),
                agent: "claude".to_string(),
            },
        );

        if let Some(p) = pid {
            let mut lock = self.active_sessions.write().await;
            lock.insert(session_id.clone(), p);
        }

        let stdout = child.stdout.take();
        let session_id_clone = session.id.clone();
        let project_id_clone = session.project_id.clone();
        let event_bus_out = event_bus.clone();

        if let Some(out) = stdout {
            tokio::spawn(async move {
                let mut reader = BufReader::new(out).lines();
                while let Ok(Some(line)) = reader.next_line().await {
                    let _ = event_bus_out.publish(
                        Some(&session_id_clone),
                        Some(&project_id_clone),
                        "agent_message",
                        AgentEventPayload::AgentMessage { content: line },
                    );
                }
            });
        }

        let session_id_exit = session.id.clone();
        let event_bus_exit = event_bus.clone();
        tokio::spawn(async move {
            if let Ok(status) = child.wait().await {
                let exit_code = status.code().unwrap_or(-1);
                if let Ok(Some(mut s)) = event_bus_exit.db().get_session(&session_id_exit) {
                    s.status = if exit_code == 0 {
                        AgentStatus::Completed
                    } else {
                        AgentStatus::Failed
                    };
                    let _ = event_bus_exit.db().save_session(&s);
                }
            }
        });

        Ok(session)
    }

    async fn send_prompt(&self, _session_id: &str, _prompt: &str) -> anyhow::Result<()> {
        Ok(())
    }

    async fn continue_session(&self, session_id: &str, event_bus: EventBus) -> anyhow::Result<()> {
        if let Some(s) = event_bus.db().get_session(session_id)? {
            let req = AgentStartRequest {
                project_id: s.project_id,
                workspace_path: s.workspace,
                prompt: s.last_task.unwrap_or_default(),
                conversation_id: Some(session_id.to_string()),
                model: None,
                effort: None,
            };
            self.start(req, event_bus).await?;
        }
        Ok(())
    }

    async fn stop(&self, session_id: &str) -> anyhow::Result<()> {
        let mut lock = self.active_sessions.write().await;
        if let Some(pid) = lock.remove(session_id) {
            #[cfg(unix)]
            unsafe {
                libc::kill(pid as i32, libc::SIGTERM);
            }
        }
        Ok(())
    }

    async fn kill(&self, session_id: &str) -> anyhow::Result<()> {
        let mut lock = self.active_sessions.write().await;
        if let Some(pid) = lock.remove(session_id) {
            #[cfg(unix)]
            unsafe {
                libc::kill(pid as i32, libc::SIGKILL);
            }
        }
        Ok(())
    }

    async fn status(&self, session_id: &str) -> anyhow::Result<AgentStatus> {
        let lock = self.active_sessions.read().await;
        if lock.contains_key(session_id) {
            Ok(AgentStatus::Running)
        } else {
            Ok(AgentStatus::Stopped)
        }
    }

    async fn capabilities(&self) -> anyhow::Result<AgentCapabilities> {
        Ok(AgentCapabilities {
            streaming: true,
            headless: true,
            subagents: false,
            conversation_continuation: true,
            file_watching: true,
            command_execution: true,
            approvals: true,
        })
    }
}
