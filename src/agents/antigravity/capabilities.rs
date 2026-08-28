use crate::models::AgentCapabilities;

pub fn get_antigravity_capabilities() -> AgentCapabilities {
    AgentCapabilities {
        streaming: true,
        headless: true,
        subagents: true,
        conversation_continuation: true,
        file_watching: true,
        command_execution: true,
        approvals: true,
    }
}
