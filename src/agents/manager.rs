use super::antigravity::AntigravityAgent;
use super::claude_code::ClaudeCodeAdapter;
use super::ollama::OllamaAdapter;
use super::r#trait::AgentAdapter;
use crate::config::Config;
use crate::events::EventBus;
use crate::models::{AgentInfo, AgentSession, AgentStartRequest, AgentStatus};
use std::collections::HashMap;
use std::sync::Arc;

pub struct AgentManager {
    adapters: HashMap<String, Arc<dyn AgentAdapter>>,
    event_bus: EventBus,
}

impl AgentManager {
    pub fn new(config: &Config, event_bus: EventBus) -> Self {
        let mut adapters: HashMap<String, Arc<dyn AgentAdapter>> = HashMap::new();

        adapters.insert(
            "antigravity".to_string(),
            Arc::new(AntigravityAgent::new(Some(config.agents.antigravity.binary.clone()))),
        );
        adapters.insert(
            "claude".to_string(),
            Arc::new(ClaudeCodeAdapter::new(Some(config.agents.claude.binary.clone()))),
        );
        adapters.insert(
            "ollama".to_string(),
            Arc::new(OllamaAdapter::new(Some(config.agents.ollama.binary.clone()))),
        );

        Self { adapters, event_bus }
    }

    pub async fn list_agents(&self) -> Vec<AgentInfo> {
        let mut list = Vec::new();
        for adapter in self.adapters.values() {
            if let Ok(info) = adapter.detect().await {
                list.push(info);
            }
        }
        list
    }

    pub async fn get_agent(&self, id: &str) -> anyhow::Result<AgentInfo> {
        if let Some(adapter) = self.adapters.get(id) {
            adapter.detect().await
        } else {
            Err(anyhow::anyhow!("Agent adapter not found: {}", id))
        }
    }

    pub async fn start_session(&self, agent_id: &str, request: AgentStartRequest) -> anyhow::Result<AgentSession> {
        if let Some(adapter) = self.adapters.get(agent_id) {
            adapter.start(request, self.event_bus.clone()).await
        } else {
            Err(anyhow::anyhow!("Unknown agent: {}", agent_id))
        }
    }

    pub async fn send_prompt(&self, agent_id: &str, session_id: &str, prompt: &str) -> anyhow::Result<()> {
        if let Some(adapter) = self.adapters.get(agent_id) {
            adapter.send_prompt(session_id, prompt).await
        } else {
            Err(anyhow::anyhow!("Unknown agent: {}", agent_id))
        }
    }

    pub async fn continue_session(&self, agent_id: &str, session_id: &str) -> anyhow::Result<()> {
        if let Some(adapter) = self.adapters.get(agent_id) {
            adapter.continue_session(session_id, self.event_bus.clone()).await
        } else {
            Err(anyhow::anyhow!("Unknown agent: {}", agent_id))
        }
    }

    pub async fn stop_session(&self, agent_id: &str, session_id: &str) -> anyhow::Result<()> {
        if let Some(adapter) = self.adapters.get(agent_id) {
            adapter.stop(session_id).await
        } else {
            Err(anyhow::anyhow!("Unknown agent: {}", agent_id))
        }
    }

    pub async fn kill_session(&self, agent_id: &str, session_id: &str) -> anyhow::Result<()> {
        if let Some(adapter) = self.adapters.get(agent_id) {
            adapter.kill(session_id).await
        } else {
            Err(anyhow::anyhow!("Unknown agent: {}", agent_id))
        }
    }

    pub async fn get_session_status(&self, agent_id: &str, session_id: &str) -> anyhow::Result<AgentStatus> {
        if let Some(adapter) = self.adapters.get(agent_id) {
            adapter.status(session_id).await
        } else {
            Err(anyhow::anyhow!("Unknown agent: {}", agent_id))
        }
    }
}
