use crate::models::{AgentSession, AgentStatus};
use chrono::Utc;
use uuid::Uuid;

pub struct AntigravitySessionState {
    pub session: AgentSession,
}

impl AntigravitySessionState {
    pub fn new(project_id: &str, workspace: &str, conversation_id: Option<String>) -> Self {
        let now = Utc::now();
        Self {
            session: AgentSession {
                id: Uuid::new_v4().to_string(),
                agent: "antigravity".to_string(),
                conversation_id,
                project_id: project_id.to_string(),
                workspace: workspace.to_string(),
                status: AgentStatus::Starting,
                started_at: now,
                last_activity: now,
                pid: None,
                last_task: None,
                progress_percent: None,
            },
        }
    }
}
