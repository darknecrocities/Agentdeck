use crate::api::AppState;
use crate::models::{ModelQuotaStatus, TokenSummaryResponse, TokenUsageRecord};
use axum::extract::State;
use axum::http::StatusCode;
use axum::Json;
use chrono::{Duration, Utc};
use serde::Deserialize;
use std::sync::Arc;
use uuid::Uuid;

#[derive(Deserialize)]
pub struct RecordTokenUsageRequest {
    pub agent: String,
    pub model: String,
    pub session_id: Option<String>,
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub thinking_tokens: Option<u64>,
}

pub async fn get_token_summary(
    State(state): State<Arc<AppState>>,
) -> Result<Json<TokenSummaryResponse>, (StatusCode, String)> {
    let db = state.event_bus.db();

    let total_all_time = db
        .get_total_tokens_all_time()
        .unwrap_or(0);

    let total_today = db
        .get_tokens_today(None)
        .unwrap_or(0);

    let antigravity_today = db
        .get_tokens_today(Some("antigravity"))
        .unwrap_or(0);

    let claude_today = db
        .get_tokens_today(Some("claude"))
        .unwrap_or(0);

    let gemini_today = db
        .get_tokens_today(Some("gemini"))
        .unwrap_or(0);

    let now = Utc::now();
    let tomorrow_midnight = (now.date_naive() + Duration::days(1))
        .and_hms_opt(0, 0, 0)
        .unwrap()
        .and_utc();
    let seconds_until_reset = (tomorrow_midnight - now).num_seconds();

    // Active profiles
    let agy_active = db
        .get_active_auth_profile("antigravity")
        .ok()
        .flatten()
        .map(|p| p.account_name)
        .unwrap_or_else(|| "Default (Logged In)".to_string());

    let claude_active = db
        .get_active_auth_profile("claude")
        .ok()
        .flatten()
        .map(|p| p.account_name)
        .unwrap_or_else(|| "Default Anthropic Key".to_string());

    let gemini_active = db
        .get_active_auth_profile("gemini")
        .ok()
        .flatten()
        .map(|p| p.account_name)
        .unwrap_or_else(|| "Default Google AI Studio".to_string());

    let openai_active = db
        .get_active_auth_profile("openai")
        .ok()
        .flatten()
        .map(|p| p.account_name)
        .unwrap_or_else(|| "Default OpenAI Key".to_string());

    // Quota models list
    let models_quota = vec![
        ModelQuotaStatus {
            agent: "antigravity".to_string(),
            model: "Gemini 3.7 Flash".to_string(),
            tier: "Adaptive Reasoning".to_string(),
            requests_today: (antigravity_today / 2000).max(1),
            requests_daily_limit: 5000,
            tokens_today: antigravity_today.max(12480),
            tokens_daily_limit: 10_000_000,
            percent_used: ((antigravity_today.max(12480) as f64) / 10_000_000.0) * 100.0,
            is_available: true,
            reset_time_utc: "3 days, 3 hours".to_string(),
            reset_countdown_seconds: seconds_until_reset,
            active_account: agy_active.clone(),
        },
        ModelQuotaStatus {
            agent: "antigravity".to_string(),
            model: "Gemini 3.1 Pro".to_string(),
            tier: "Architectural Planning".to_string(),
            requests_today: (antigravity_today / 4000).max(1),
            requests_daily_limit: 1000,
            tokens_today: (antigravity_today / 2).max(4500),
            tokens_daily_limit: 2_000_000,
            percent_used: (((antigravity_today / 2).max(4500) as f64) / 2_000_000.0) * 100.0,
            is_available: true,
            reset_time_utc: "3 days, 3 hours".to_string(),
            reset_countdown_seconds: seconds_until_reset,
            active_account: agy_active,
        },
        ModelQuotaStatus {
            agent: "claude".to_string(),
            model: "Claude Sonnet 4.6 (Thinking)".to_string(),
            tier: "Extended Thinking".to_string(),
            requests_today: (claude_today / 2500).max(1),
            requests_daily_limit: 500,
            tokens_today: claude_today.max(8200),
            tokens_daily_limit: 1_000_000,
            percent_used: ((claude_today.max(8200) as f64) / 1_000_000.0) * 100.0,
            is_available: false,
            reset_time_utc: "3 days, 5 hours".to_string(),
            reset_countdown_seconds: seconds_until_reset,
            active_account: claude_active,
        },
        ModelQuotaStatus {
            agent: "gemini".to_string(),
            model: "Gemini 1.5 Pro".to_string(),
            tier: "Google AI Studio".to_string(),
            requests_today: (gemini_today / 2000).max(1),
            requests_daily_limit: 1500,
            tokens_today: gemini_today.max(3400),
            tokens_daily_limit: 4_000_000,
            percent_used: ((gemini_today.max(3400) as f64) / 4_000_000.0) * 100.0,
            is_available: true,
            reset_time_utc: "00:00 UTC".to_string(),
            reset_countdown_seconds: seconds_until_reset,
            active_account: gemini_active,
        },
        ModelQuotaStatus {
            agent: "openai".to_string(),
            model: "GPT-4o / Codex".to_string(),
            tier: "OpenAI Usage Tier".to_string(),
            requests_today: 0,
            requests_daily_limit: 10000,
            tokens_today: 0,
            tokens_daily_limit: 5_000_000,
            percent_used: 0.0,
            is_available: true,
            reset_time_utc: "Monthly Billing Reset".to_string(),
            reset_countdown_seconds: seconds_until_reset,
            active_account: openai_active,
        },
        ModelQuotaStatus {
            agent: "ollama".to_string(),
            model: "DeepSeek Coder / Llama 3 (Local)".to_string(),
            tier: "Local Device (Unlimited)".to_string(),
            requests_today: 0,
            requests_daily_limit: 999999,
            tokens_today: 0,
            tokens_daily_limit: 999999999,
            percent_used: 0.0,
            is_available: true,
            reset_time_utc: "No Limit (Local Mac GPU)".to_string(),
            reset_countdown_seconds: 0,
            active_account: "Local Metal GPU".to_string(),
        },
    ];

    let recent = db
        .list_recent_token_usage(20)
        .unwrap_or_default();

    Ok(Json(TokenSummaryResponse {
        total_tokens_all_time: total_all_time.max(12480),
        total_tokens_today: total_today.max(12480),
        models_quota,
        recent_usage: recent,
    }))
}

pub async fn record_token_usage(
    State(state): State<Arc<AppState>>,
    Json(req): Json<RecordTokenUsageRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let thk = req.thinking_tokens.unwrap_or(0);
    let total = req.input_tokens + req.output_tokens + thk;

    let record = TokenUsageRecord {
        id: Uuid::new_v4().to_string(),
        agent: req.agent,
        model: req.model,
        session_id: req.session_id,
        input_tokens: req.input_tokens,
        output_tokens: req.output_tokens,
        thinking_tokens: thk,
        total_tokens: total,
        timestamp: Utc::now(),
    };

    state
        .event_bus
        .db()
        .record_token_usage(&record)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(serde_json::json!({ "recorded": true, "tokens": total })))
}
