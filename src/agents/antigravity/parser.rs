use super::events::AgyRawEvent;
use crate::models::AgentEventPayload;

pub struct AntigravityParser;

impl AntigravityParser {
    pub fn parse_line(line: &str) -> Option<AgentEventPayload> {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            return None;
        }

        // Attempt to parse as JSON first (stream-json format)
        if trimmed.starts_with('{') && trimmed.ends_with('}') {
            if let Ok(raw_event) = serde_json::from_str::<AgyRawEvent>(trimmed) {
                return Some(Self::convert_raw_event(raw_event));
            }

            // Fallback generic JSON parse
            if let Ok(val) = serde_json::from_str::<serde_json::Value>(trimmed) {
                if let Some(msg) = val.get("message").and_then(|m| m.as_str()) {
                    return Some(AgentEventPayload::AgentMessage {
                        content: msg.to_string(),
                    });
                }
                if let Some(tool) = val.get("tool").and_then(|t| t.as_str()) {
                    return Some(AgentEventPayload::ToolStarted {
                        tool: tool.to_string(),
                        input: val.get("input").map(|i| i.to_string()),
                    });
                }
            }
        }

        // Plaintext heuristics fallback (if raw text was output)
        if trimmed.contains("Planning") || trimmed.contains("Analyzing") {
            Some(AgentEventPayload::ThinkingUpdate {
                stage: trimmed.to_string(),
            })
        } else if trimmed.starts_with("Created file") || trimmed.starts_with("Created ") {
            let path = trimmed.replace("Created file", "").replace("Created", "").trim().to_string();
            Some(AgentEventPayload::FileCreated { path })
        } else if trimmed.starts_with("Modified file") || trimmed.starts_with("Updated ") {
            let path = trimmed.replace("Modified file", "").replace("Updated", "").trim().to_string();
            Some(AgentEventPayload::FileModified { path })
        } else if trimmed.starts_with("Running command:") || trimmed.starts_with("$ ") {
            let cmd = trimmed.replace("Running command:", "").replace("$ ", "").trim().to_string();
            Some(AgentEventPayload::CommandStarted { command: cmd })
        } else {
            Some(AgentEventPayload::StdoutSnippet {
                text: trimmed.to_string(),
            })
        }
    }

    fn convert_raw_event(raw: AgyRawEvent) -> AgentEventPayload {
        match raw {
            AgyRawEvent::SessionStarted { session_id, agent, .. } => AgentEventPayload::SessionStarted {
                session_id: session_id.unwrap_or_default(),
                agent: agent.unwrap_or_else(|| "antigravity".to_string()),
            },
            AgyRawEvent::SessionResumed { conversation_id } => AgentEventPayload::SessionResumed {
                session_id: String::new(),
                conversation_id,
            },
            AgyRawEvent::AgentMessage { content } => AgentEventPayload::AgentMessage { content },
            AgyRawEvent::ThinkingStarted => AgentEventPayload::ThinkingStarted,
            AgyRawEvent::ThinkingUpdate { stage } => AgentEventPayload::ThinkingUpdate {
                stage: stage.unwrap_or_else(|| "Processing".to_string()),
            },
            AgyRawEvent::ToolStarted { tool, input } => AgentEventPayload::ToolStarted {
                tool,
                input: input.map(|v| v.to_string()),
            },
            AgyRawEvent::ToolFinished { tool, success, summary } => AgentEventPayload::ToolFinished {
                tool,
                success,
                summary,
            },
            AgyRawEvent::FileCreated { path } => AgentEventPayload::FileCreated { path },
            AgyRawEvent::FileModified { path } => AgentEventPayload::FileModified { path },
            AgyRawEvent::FileDeleted { path } => AgentEventPayload::FileDeleted { path },
            AgyRawEvent::CommandStarted { command } => AgentEventPayload::CommandStarted { command },
            AgyRawEvent::CommandFinished { command, exit_code, output_snippet } => {
                AgentEventPayload::CommandFinished {
                    command,
                    exit_code,
                    output_snippet,
                }
            }
            AgyRawEvent::ApprovalRequired { request_id, description, command, risk } => {
                AgentEventPayload::ApprovalRequired {
                    request_id,
                    description,
                    command,
                    risk: risk.unwrap_or_else(|| "medium".to_string()),
                }
            }
            AgyRawEvent::SubagentStarted { subagent_id, name, task } => {
                AgentEventPayload::SubagentStarted { subagent_id, name, task }
            }
            AgyRawEvent::SubagentFinished { subagent_id, success } => {
                AgentEventPayload::SubagentFinished { subagent_id, success }
            }
            AgyRawEvent::SessionCompleted { summary } => AgentEventPayload::SessionCompleted { summary },
            AgyRawEvent::SessionFailed { error } => AgentEventPayload::SessionFailed { error },
        }
    }
}
