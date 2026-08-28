use crate::events::EventBus;
use crate::models::{AgentCapabilities, AgentInfo, AgentSession, AgentStartRequest, AgentStatus};
use async_trait::async_trait;

#[async_trait]
pub trait AgentAdapter: Send + Sync {
    fn id(&self) -> &str;
    fn display_name(&self) -> &str;
    async fn detect(&self) -> anyhow::Result<AgentInfo>;
    async fn start(&self, request: AgentStartRequest, event_bus: EventBus) -> anyhow::Result<AgentSession>;
    async fn send_prompt(&self, session_id: &str, prompt: &str) -> anyhow::Result<()>;
    async fn continue_session(&self, session_id: &str, event_bus: EventBus) -> anyhow::Result<()>;
    async fn stop(&self, session_id: &str) -> anyhow::Result<()>;
    async fn kill(&self, session_id: &str) -> anyhow::Result<()>;
    async fn status(&self, session_id: &str) -> anyhow::Result<AgentStatus>;
    async fn capabilities(&self) -> anyhow::Result<AgentCapabilities>;
}
