pub mod handlers;

use crate::agents::AgentManager;
use crate::approvals::ApprovalManager;
use crate::config::Config;
use crate::events::EventBus;
use crate::security::SecurityManager;
use crate::terminal::TerminalManager;
use crate::watcher::ProjectWatcher;
use axum::routing::{delete, get, post};
use axum::Router;
use std::sync::{Arc, Mutex};
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;

pub struct AppState {
    pub config: Config,
    pub event_bus: EventBus,
    pub agent_manager: AgentManager,
    pub terminal_manager: TerminalManager,
    pub watcher: Arc<Mutex<ProjectWatcher>>,
    pub approvals: ApprovalManager,
    pub security: SecurityManager,
}

pub fn create_router(state: Arc<AppState>) -> Router {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    Router::new()
        // Health & System
        .route("/health", get(handlers::system::health_handler))
        .route("/api/status", get(handlers::system::status_handler))
        .route("/api/device", get(handlers::system::device_info_handler))
        .route("/api/diagnostics", get(handlers::system::diagnostics_handler))
        .route("/api/system/browse", get(handlers::system::browse_directories_handler))
        .route("/api/system/mkdir", post(handlers::system::create_directory_handler))
        .route("/api/system/ping_workstation", get(handlers::system::ping_workstation_handler))
        .route("/api/system/launch-app", post(handlers::system::launch_app_handler))
        .route("/api/system/screenshot", get(handlers::system::take_screenshot_handler))
        .route("/api/system/camera", get(handlers::system::take_camera_snapshot_handler))
        .route("/api/system/camera/stop", post(handlers::system::stop_camera_handler))
        .route("/api/system/play-sound", post(handlers::system::play_sound_handler))
        .route("/api/system/file", get(handlers::system::read_system_file_handler))
        .route("/api/system/antigravity/live-chat", get(handlers::system::antigravity_live_chat_handler))
        .route("/api/files/upload", post(handlers::system::upload_file_handler))
        // Projects
        .route("/api/projects", get(handlers::projects::list_projects).post(handlers::projects::create_project))
        .route("/api/projects/scaffold", post(handlers::projects::scaffold_project))
        .route("/api/projects/:id", delete(handlers::projects::delete_project))
        .route("/api/projects/:id/files", get(handlers::projects::list_project_files))
        .route("/api/projects/:id/files/content", get(handlers::projects::read_file_content))
        .route("/api/projects/:id/git/status", get(handlers::projects::get_project_git_status))
        .route("/api/projects/:id/git/diff", get(handlers::projects::get_project_git_diff))
        .route("/api/projects/:id/git/log", get(handlers::projects::get_project_git_log))
        .route("/api/projects/:id/git/commit", post(handlers::projects::commit_project_git))
        .route("/api/projects/:id/git/push", post(handlers::projects::push_project_git))
        .route("/api/projects/:id/git/pull", post(handlers::projects::pull_project_git))
        .route("/api/projects/:id/github", get(handlers::projects::get_project_github))
        // Agents & Sessions
        .route("/api/agents", get(handlers::agents::list_agents))
        .route("/api/agents/:id", get(handlers::agents::get_agent))
        .route("/api/sessions", get(handlers::agents::list_sessions).post(handlers::agents::start_session))
        .route("/api/sessions/:id", get(handlers::agents::get_session))
        .route("/api/sessions/:id/prompt", post(handlers::agents::send_prompt_to_session))
        .route("/api/sessions/:id/continue", post(handlers::agents::continue_session_handler))
        .route("/api/sessions/:id/stop", post(handlers::agents::stop_session_handler))
        .route("/api/sessions/:id/kill", post(handlers::agents::kill_session_handler))
        .route("/api/sessions/:id/events", get(handlers::agents::get_session_events))
        // Terminal PTY
        .route("/api/terminal/sessions", get(handlers::terminal::list_terminals))
        .route("/api/terminal/session", post(handlers::terminal::spawn_terminal))
        .route("/api/terminal/:id/input", post(handlers::terminal::write_terminal_input))
        .route("/api/terminal/:id/resize", post(handlers::terminal::resize_terminal))
        .route("/api/terminal/:id", delete(handlers::terminal::close_terminal))
        // Approvals
        .route("/api/approvals", get(handlers::approvals::list_approvals))
        .route("/api/approvals/:id/approve", post(handlers::approvals::approve_request))
        .route("/api/approvals/:id/deny", post(handlers::approvals::deny_request))
        // Auth & Accounts
        .route("/api/auth/profiles", get(handlers::auth::list_profiles).post(handlers::auth::create_profile))
        .route("/api/auth/profiles/:id/activate", post(handlers::auth::activate_profile))
        .route("/api/auth/profiles/:id", delete(handlers::auth::delete_profile))
        .route("/api/accounts/antigravity", get(handlers::auth::get_antigravity_account_handler))
        .route("/api/accounts/antigravity/switch", post(handlers::auth::switch_antigravity_account_handler))
        // Token Quota & Monitoring
        .route("/api/tokens/summary", get(handlers::tokens::get_token_summary))
        .route("/api/tokens/record", post(handlers::tokens::record_token_usage))
        // WebSockets
        .route("/ws/events", get(handlers::ws::ws_events_handler))
        .route("/ws/sessions/:id", get(handlers::ws::ws_session_handler))
        .route("/ws/terminal/:id", get(handlers::ws::ws_terminal_handler))
        .layer(axum::extract::DefaultBodyLimit::max(500 * 1024 * 1024))
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}
