use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum AgentStatus {
    Starting,
    Running,
    Waiting,
    AwaitingApproval,
    Paused,
    Completed,
    Failed,
    Crashed,
    Stopped,
    Unknown,
}

impl ToString for AgentStatus {
    fn to_string(&self) -> String {
        match self {
            AgentStatus::Starting => "starting".to_string(),
            AgentStatus::Running => "running".to_string(),
            AgentStatus::Waiting => "waiting".to_string(),
            AgentStatus::AwaitingApproval => "awaiting_approval".to_string(),
            AgentStatus::Paused => "paused".to_string(),
            AgentStatus::Completed => "completed".to_string(),
            AgentStatus::Failed => "failed".to_string(),
            AgentStatus::Crashed => "crashed".to_string(),
            AgentStatus::Stopped => "stopped".to_string(),
            AgentStatus::Unknown => "unknown".to_string(),
        }
    }
}

impl From<&str> for AgentStatus {
    fn from(s: &str) -> Self {
        match s {
            "starting" => AgentStatus::Starting,
            "running" => AgentStatus::Running,
            "waiting" => AgentStatus::Waiting,
            "awaiting_approval" => AgentStatus::AwaitingApproval,
            "paused" => AgentStatus::Paused,
            "completed" => AgentStatus::Completed,
            "failed" => AgentStatus::Failed,
            "crashed" => AgentStatus::Crashed,
            "stopped" => AgentStatus::Stopped,
            _ => AgentStatus::Unknown,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Project {
    pub id: String,
    pub name: String,
    pub path: String,
    pub default_agent: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentInfo {
    pub id: String,
    pub name: String,
    pub display_name: String,
    pub binary_path: Option<String>,
    pub installed: bool,
    pub version: Option<String>,
    pub authenticated: bool,
    pub capabilities: AgentCapabilities,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct AgentCapabilities {
    pub streaming: bool,
    pub headless: bool,
    pub subagents: bool,
    pub conversation_continuation: bool,
    pub file_watching: bool,
    pub command_execution: bool,
    pub approvals: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentStartRequest {
    pub project_id: String,
    pub workspace_path: String,
    pub prompt: String,
    pub conversation_id: Option<String>,
    pub model: Option<String>,
    pub effort: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentSession {
    pub id: String,
    pub agent: String,
    pub conversation_id: Option<String>,
    pub project_id: String,
    pub workspace: String,
    pub status: AgentStatus,
    pub started_at: DateTime<Utc>,
    pub last_activity: DateTime<Utc>,
    pub pid: Option<u32>,
    pub last_task: Option<String>,
    pub progress_percent: Option<u8>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
pub enum AgentEventPayload {
    SessionStarted { session_id: String, agent: String },
    SessionResumed { session_id: String, conversation_id: String },
    PromptSent { prompt: String },
    AgentMessage { content: String },
    ThinkingStarted,
    ThinkingUpdate { stage: String },
    ToolStarted { tool: String, input: Option<String> },
    ToolFinished { tool: String, success: bool, summary: Option<String> },
    FileCreated { path: String },
    FileModified { path: String },
    FileDeleted { path: String },
    CommandStarted { command: String },
    CommandFinished { command: String, exit_code: i32, output_snippet: Option<String> },
    ApprovalRequired { request_id: String, description: String, command: Option<String>, risk: String },
    ApprovalResolved { request_id: String, approved: bool },
    SubagentStarted { subagent_id: String, name: String, task: String },
    SubagentFinished { subagent_id: String, success: bool },
    SessionCompleted { summary: Option<String> },
    SessionFailed { error: String },
    SessionExited { code: i32 },
    StdoutSnippet { text: String },
    StderrSnippet { text: String },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EventRecord {
    pub event_id: i64,
    pub session_id: Option<String>,
    pub project_id: Option<String>,
    pub timestamp: DateTime<Utc>,
    pub event_type: String,
    pub payload: AgentEventPayload,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum RiskLevel {
    Low,
    Medium,
    High,
    Critical,
}

impl ToString for RiskLevel {
    fn to_string(&self) -> String {
        match self {
            RiskLevel::Low => "low".to_string(),
            RiskLevel::Medium => "medium".to_string(),
            RiskLevel::High => "high".to_string(),
            RiskLevel::Critical => "critical".to_string(),
        }
    }
}

impl From<&str> for RiskLevel {
    fn from(s: &str) -> Self {
        match s {
            "low" => RiskLevel::Low,
            "medium" => RiskLevel::Medium,
            "high" => RiskLevel::High,
            "critical" => RiskLevel::Critical,
            _ => RiskLevel::Medium,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApprovalRequest {
    pub id: String,
    pub session_id: String,
    pub agent: String,
    pub request_type: String,
    pub description: String,
    pub command: Option<String>,
    pub risk: RiskLevel,
    pub status: String, // "pending", "approved", "denied"
    pub created_at: DateTime<Utc>,
    pub resolved_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TerminalSessionInfo {
    pub id: String,
    pub project_id: Option<String>,
    pub shell: String,
    pub cols: u16,
    pub rows: u16,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitStatusInfo {
    pub branch: String,
    pub is_clean: bool,
    pub ahead: u32,
    pub behind: u32,
    pub modified_files: Vec<String>,
    pub staged_files: Vec<String>,
    pub untracked_files: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceInfo {
    pub os: String,
    pub hostname: String,
    pub cpu_usage: f32,
    pub memory_used_mb: u64,
    pub memory_total_mb: u64,
    pub disk_free_gb: f64,
    pub disk_total_gb: f64,
    pub tailscale_ip: Option<String>,
    pub tailscale_status: String,
    pub uptime_secs: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthProfile {
    pub id: String,
    pub agent_id: String, // "antigravity", "claude", "gemini", "openai", "ollama"
    pub account_name: String,
    pub token_masked: String,
    pub token_value: String,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateAuthProfileRequest {
    pub agent_id: String,
    pub account_name: String,
    pub token_value: String,
    pub set_active: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenUsageRecord {
    pub id: String,
    pub agent: String,
    pub model: String,
    pub session_id: Option<String>,
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub thinking_tokens: u64,
    pub total_tokens: u64,
    pub timestamp: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModelQuotaStatus {
    pub agent: String,
    pub model: String,
    pub tier: String, // "Pro", "Free", "Tier 1"
    pub requests_today: u64,
    pub requests_daily_limit: u64,
    pub tokens_today: u64,
    pub tokens_daily_limit: u64,
    pub percent_used: f64,
    pub is_available: bool,
    pub reset_time_utc: String,
    pub reset_countdown_seconds: i64,
    pub active_account: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModelTierQuota {
    pub weekly_limit_remaining: u32,
    pub weekly_reset_text: String,
    pub weekly_reset_seconds: i64,
    pub five_hour_limit_remaining: u32,
    pub five_hour_reset_text: String,
    pub five_hour_reset_seconds: i64,
    pub is_available: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenSummaryResponse {
    pub plan_name: Option<String>,
    pub plan_tier: Option<String>,
    pub credit_overages_enabled: Option<bool>,
    pub total_tokens_all_time: u64,
    pub total_tokens_today: u64,
    pub gemini_quota: ModelTierQuota,
    pub claude_gpt_quota: ModelTierQuota,
    pub models_quota: Vec<ModelQuotaStatus>,
    pub recent_usage: Vec<TokenUsageRecord>,
}
