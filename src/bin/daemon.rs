use agentdeck::agents::AgentManager;
use agentdeck::api::{create_router, AppState};
use agentdeck::approvals::ApprovalManager;
use agentdeck::config::Config;
use agentdeck::db::Database;
use agentdeck::events::EventBus;
use agentdeck::security::SecurityManager;
use agentdeck::tailscale::TailscaleManager;
use agentdeck::terminal::TerminalManager;
use agentdeck::watcher::ProjectWatcher;
use clap::Parser;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use tracing::info;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[derive(Parser, Debug)]
#[command(name = "agentdeckd", author, version, about = "AgentDeck local daemon")]
struct DaemonArgs {
    #[arg(short, long)]
    config: Option<String>,

    #[arg(short, long)]
    port: Option<u16>,

    #[arg(long)]
    host: Option<String>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "agentdeck=info,agentdeckd=info,tower_http=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let args = DaemonArgs::parse();
    let mut config = Config::load_or_default(args.config.as_deref());

    if let Some(p) = args.port {
        config.server.port = p;
    }
    if let Some(h) = args.host {
        config.server.host = h;
    }

    info!("Starting AgentDeck daemon (agentdeckd) v{}", env!("CARGO_PKG_VERSION"));
    info!("Database path: {}", config.server.db_path);

    let db = Database::new(&config.server.db_path)?;
    let event_bus = EventBus::new(db.clone());
    let agent_manager = AgentManager::new(&config, event_bus.clone());
    let terminal_manager = TerminalManager::new();
    let watcher = Arc::new(Mutex::new(ProjectWatcher::new(event_bus.clone())?));
    let approvals = ApprovalManager::new(event_bus.clone());

    // Security manager with project roots
    let mut allowed_roots = config.projects.roots.clone();
    if let Ok(projects) = db.list_projects() {
        for p in projects {
            allowed_roots.push(p.path);
        }
    }
    let security = SecurityManager::new(
        allowed_roots,
        if config.security.require_auth {
            Some(config.security.auth_token.clone())
        } else {
            None
        },
    );

    // Watch registered projects
    if let Ok(projects) = db.list_projects() {
        if let Ok(mut w) = watcher.lock() {
            for p in projects {
                let _ = w.watch_directory(&p.id, &p.path);
            }
        }
    }

    let tailscale = TailscaleManager::detect().await;
    if tailscale.installed {
        info!("Tailscale detected! Status: {}, IP: {:?}", tailscale.status, tailscale.ip);
    } else {
        info!("Tailscale not detected, running on local interfaces.");
    }

    let state = Arc::new(AppState {
        config: config.clone(),
        event_bus,
        agent_manager,
        terminal_manager,
        watcher,
        approvals,
        security,
    });

    let app = create_router(state);
    let addr: SocketAddr = format!("{}:{}", config.server.host, config.server.port).parse()?;
    info!("AgentDeck daemon listening on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    info!("AgentDeck daemon shutdown gracefully");
    Ok(())
}

async fn shutdown_signal() {
    tokio::signal::ctrl_c()
        .await
        .expect("Failed to listen for ctrl+c");
    info!("Ctrl+C received, starting graceful shutdown...");
}
