use super::parser::AntigravityParser;
use crate::events::EventBus;
use crate::models::{AgentEventPayload, AgentSession, AgentStatus};
use chrono::Utc;
use std::process::Stdio;
use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::process::{Child, ChildStdin, Command};
use tokio::sync::Mutex;
use tracing::{error, info, warn};

pub struct AntigravityProcess {
    pub session: AgentSession,
    pub stdin: Option<Arc<Mutex<ChildStdin>>>,
    pub child_pid: Option<u32>,
}

impl AntigravityProcess {
    pub async fn spawn(
        binary_path: &str,
        workspace: &str,
        prompt: &str,
        conversation_id: Option<&str>,
        session: AgentSession,
        event_bus: EventBus,
    ) -> anyhow::Result<Self> {
        let mut cmd = Command::new(binary_path);
        cmd.current_dir(workspace);

        // Official CLI flags
        cmd.arg("--output-format").arg("stream-json");

        if let Some(conv_id) = conversation_id {
            cmd.arg("--conversation").arg(conv_id);
            cmd.arg("--continue");
        }

        if !prompt.is_empty() {
            cmd.arg("-p").arg(prompt);
        }

        cmd.stdout(Stdio::piped());
        cmd.stderr(Stdio::piped());
        cmd.stdin(Stdio::piped());

        info!("Spawning Antigravity CLI: {:?}", cmd);

        let mut child: Child = match cmd.spawn() {
            Ok(c) => c,
            Err(e) => {
                error!("Failed to spawn {}: {}", binary_path, e);
                return Err(anyhow::anyhow!("Failed to spawn Antigravity CLI ({}): {}", binary_path, e));
            }
        };

        let pid = child.id();
        let mut running_session = session.clone();
        running_session.pid = pid;
        running_session.status = AgentStatus::Running;
        running_session.last_task = if !prompt.is_empty() {
            Some(prompt.to_string())
        } else {
            None
        };

        // Save session in DB
        let _ = event_bus.db().save_session(&running_session);

        // Publish SessionStarted event
        let _ = event_bus.publish(
            Some(&running_session.id),
            Some(&running_session.project_id),
            "session_started",
            AgentEventPayload::SessionStarted {
                session_id: running_session.id.clone(),
                agent: "antigravity".to_string(),
            },
        );

        let stdin = child.stdin.take().map(|s| Arc::new(Mutex::new(s)));
        let stdout = child.stdout.take();
        let stderr = child.stderr.take();

        let session_id_clone = running_session.id.clone();
        let project_id_clone = running_session.project_id.clone();
        let event_bus_stdout = event_bus.clone();

        // Spawn stdout monitoring task
        if let Some(out) = stdout {
            let session_id = session_id_clone.clone();
            let project_id = project_id_clone.clone();
            let bus = event_bus_stdout.clone();
            tokio::spawn(async move {
                let mut reader = BufReader::new(out).lines();
                while let Ok(Some(line)) = reader.next_line().await {
                    if let Some(payload) = AntigravityParser::parse_line(&line) {
                        let _ = bus.publish(Some(&session_id), Some(&project_id), "agent_event", payload);
                    }
                }
            });
        }

        // Spawn stderr monitoring task
        if let Some(err) = stderr {
            let session_id = session_id_clone.clone();
            let project_id = project_id_clone.clone();
            let bus = event_bus.clone();
            tokio::spawn(async move {
                let mut reader = BufReader::new(err).lines();
                while let Ok(Some(line)) = reader.next_line().await {
                    let trimmed = line.trim();
                    if !trimmed.is_empty() {
                        let _ = bus.publish(
                            Some(&session_id),
                            Some(&project_id),
                            "agent_stderr",
                            AgentEventPayload::StderrSnippet {
                                text: trimmed.to_string(),
                            },
                        );
                    }
                }
            });
        }

        // Spawn exit watcher task
        let session_id_exit = running_session.id.clone();
        let project_id_exit = running_session.project_id.clone();
        let event_bus_exit = event_bus.clone();
        tokio::spawn(async move {
            match child.wait().await {
                Ok(status) => {
                    let exit_code = status.code().unwrap_or(-1);
                    info!("Antigravity session {} exited with code {}", session_id_exit, exit_code);

                    let final_status = if exit_code == 0 {
                        AgentStatus::Completed
                    } else {
                        AgentStatus::Failed
                    };

                    if let Ok(Some(mut s)) = event_bus_exit.db().get_session(&session_id_exit) {
                        s.status = final_status;
                        s.last_activity = Utc::now();
                        let _ = event_bus_exit.db().save_session(&s);
                    }

                    let _ = event_bus_exit.publish(
                        Some(&session_id_exit),
                        Some(&project_id_exit),
                        "session_exited",
                        AgentEventPayload::SessionExited { code: exit_code },
                    );
                }
                Err(e) => {
                    warn!("Error waiting on child process: {}", e);
                }
            }
        });

        Ok(Self {
            session: running_session,
            stdin,
            child_pid: pid,
        })
    }

    pub async fn write_stdin(&self, input: &str) -> anyhow::Result<()> {
        if let Some(stdin_mutex) = &self.stdin {
            let mut guard = stdin_mutex.lock().await;
            guard.write_all(input.as_bytes()).await?;
            guard.write_all(b"\n").await?;
            guard.flush().await?;
            Ok(())
        } else {
            Err(anyhow::anyhow!("Process stdin is not available"))
        }
    }
}
