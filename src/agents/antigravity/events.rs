use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum AgyRawEvent {
    #[serde(rename = "session_started")]
    SessionStarted {
        session_id: Option<String>,
        conversation_id: Option<String>,
        agent: Option<String>,
    },
    #[serde(rename = "session_resumed")]
    SessionResumed {
        conversation_id: String,
    },
    #[serde(rename = "agent_message")]
    AgentMessage {
        content: String,
    },
    #[serde(rename = "thinking_started")]
    ThinkingStarted,
    #[serde(rename = "thinking_update")]
    ThinkingUpdate {
        stage: Option<String>,
    },
    #[serde(rename = "tool_started")]
    ToolStarted {
        tool: String,
        input: Option<serde_json::Value>,
    },
    #[serde(rename = "tool_finished")]
    ToolFinished {
        tool: String,
        success: bool,
        summary: Option<String>,
    },
    #[serde(rename = "file_created")]
    FileCreated {
        path: String,
    },
    #[serde(rename = "file_modified")]
    FileModified {
        path: String,
    },
    #[serde(rename = "file_deleted")]
    FileDeleted {
        path: String,
    },
    #[serde(rename = "command_started")]
    CommandStarted {
        command: String,
    },
    #[serde(rename = "command_finished")]
    CommandFinished {
        command: String,
        exit_code: i32,
        output_snippet: Option<String>,
    },
    #[serde(rename = "approval_required")]
    ApprovalRequired {
        request_id: String,
        description: String,
        command: Option<String>,
        risk: Option<String>,
    },
    #[serde(rename = "subagent_started")]
    SubagentStarted {
        subagent_id: String,
        name: String,
        task: String,
    },
    #[serde(rename = "subagent_finished")]
    SubagentFinished {
        subagent_id: String,
        success: bool,
    },
    #[serde(rename = "session_completed")]
    SessionCompleted {
        summary: Option<String>,
    },
    #[serde(rename = "session_failed")]
    SessionFailed {
        error: String,
    },
}
