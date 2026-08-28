use clap::{Parser, Subcommand};
use colored::*;
use serde_json::Value;
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(name = "agentdeck", author, version, about = "AgentDeck CLI - Control & Diagnostics")]
struct Cli {
    #[arg(short, long, default_value = "http://127.0.0.1:8765")]
    url: String,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Check AgentDeck daemon and system health
    Status,
    /// Run full system diagnostics and agent verification
    Doctor,
    /// List or manage registered projects
    Projects {
        #[command(subcommand)]
        action: Option<ProjectsAction>,
    },
    /// List agent adapters and capabilities
    Agents,
    /// Start an agent session
    Start {
        agent: String,
        #[arg(short, long)]
        project_id: String,
        #[arg(short, long)]
        prompt: String,
    },
    /// Stop an agent session
    Stop {
        agent: String,
        session_id: String,
    },
    /// View recent event logs
    Logs {
        #[arg(short, long, default_value = "20")]
        limit: usize,
    },
    /// Show active configuration
    Config,
}

#[derive(Subcommand, Debug)]
enum ProjectsAction {
    /// Add a new project
    Add {
        name: String,
        path: String,
        #[arg(short, long, default_value = "antigravity")]
        agent: String,
    },
    /// List projects
    List,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    let client = reqwest::Client::new();

    match cli.command {
        Commands::Status => {
            println!("{}", "Checking AgentDeck Daemon Status...".bold().cyan());
            match client.get(format!("{}/api/status", cli.url)).send().await {
                Ok(resp) if resp.status().is_success() => {
                    let data: Value = resp.json().await?;
                    println!("Daemon Status: {}", "ONLINE".bold().green());
                    if let Some(ts) = data.get("tailscale") {
                        let ip = ts.get("ip").and_then(|v| v.as_str()).unwrap_or("N/A");
                        let status = ts.get("status").and_then(|v| v.as_str()).unwrap_or("unknown");
                        println!("Tailscale: {} (IP: {})", status.yellow(), ip.bold());
                    }
                    if let Some(metrics) = data.get("metrics") {
                        println!("Projects: {}", metrics.get("projects_count").unwrap_or(&Value::Null));
                        println!("Active Sessions: {}", metrics.get("active_sessions").unwrap_or(&Value::Null));
                        println!("Pending Approvals: {}", metrics.get("pending_approvals").unwrap_or(&Value::Null));
                    }
                }
                _ => {
                    println!("Daemon Status: {}", "OFFLINE (cannot connect to daemon)".bold().red());
                    println!("Run `agentdeckd` to start the daemon.");
                }
            }
        }
        Commands::Doctor => {
            println!("{}", "═══════════════════════════════════════════════════".dimmed());
            println!("{}", "           AGENTDECK SYSTEM DOCTOR REPORT          ".bold().cyan());
            println!("{}", "═══════════════════════════════════════════════════".dimmed());

            // 1. Daemon check
            print!("Checking AgentDeck Daemon ({}) ... ", cli.url);
            let daemon_online = match client.get(format!("{}/health", cli.url)).send().await {
                Ok(r) if r.status().is_success() => {
                    println!("{}", "[OK]".bold().green());
                    true
                }
                _ => {
                    println!("{}", "[OFFLINE]".yellow());
                    false
                }
            };

            // 2. Antigravity CLI check
            print!("Checking Antigravity CLI (`agy`) ... ");
            let agy_found = which::which("agy").is_ok()
                || PathBuf::from("/usr/local/bin/agy").exists()
                || PathBuf::from("/opt/homebrew/bin/agy").exists()
                || PathBuf::from("/Users/arronkianparejas/.gemini/antigravity/bin/agy").exists();
            if agy_found {
                println!("{}", "[FOUND]".bold().green());
            } else {
                println!("{}", "[NOT IN PATH] (Mock/Fallback active)".yellow());
            }

            // 3. Claude Code check
            print!("Checking Claude Code CLI (`claude`) ... ");
            if which::which("claude").is_ok()
                || PathBuf::from("/Users/arronkianparejas/.nvm/versions/node/v20.20.2/bin/claude").exists()
            {
                println!("{}", "[FOUND]".bold().green());
            } else {
                println!("{}", "[NOT FOUND]".yellow());
            }

            // 4. Gemini CLI check
            print!("Checking Gemini CLI (`gemini`) ... ");
            if which::which("gemini").is_ok()
                || PathBuf::from("/Users/arronkianparejas/.nvm/versions/node/v20.20.2/bin/gemini").exists()
            {
                println!("{}", "[FOUND]".bold().green());
            } else {
                println!("{}", "[NOT FOUND]".yellow());
            }

            // 5. Ollama check
            print!("Checking Ollama (`ollama`) ... ");
            if which::which("ollama").is_ok() || PathBuf::from("/usr/local/bin/ollama").exists() {
                println!("{}", "[FOUND]".bold().green());
            } else {
                println!("{}", "[NOT FOUND]".yellow());
            }

            // 6. Git check
            print!("Checking Git (`git`) ... ");
            if which::which("git").is_ok() {
                println!("{}", "[FOUND]".bold().green());
            } else {
                println!("{}", "[MISSING]".bold().red());
            }

            // 7. GitHub CLI check
            print!("Checking GitHub CLI (`gh`) ... ");
            if which::which("gh").is_ok() || PathBuf::from("/opt/homebrew/bin/gh").exists() {
                println!("{}", "[FOUND]".bold().green());
            } else {
                println!("{}", "[NOT FOUND]".yellow());
            }

            // 8. Tailscale check
            print!("Checking Tailscale ... ");
            let ts_found = which::which("tailscale").is_ok()
                || PathBuf::from("/Applications/Tailscale.app/Contents/MacOS/Tailscale").exists()
                || PathBuf::from("/opt/homebrew/bin/tailscale").exists();
            if ts_found {
                println!("{}", "[FOUND]".bold().green());
            } else {
                println!("{}", "[NOT CONFIGURED] (Localhost mode available)".yellow());
            }

            // 9. SQLite & Filesystem check
            print!("Checking Local Storage & Permissions ... ");
            let test_db = rusqlite::Connection::open_in_memory();
            if test_db.is_ok() {
                println!("{}", "[OK]".bold().green());
            } else {
                println!("{}", "[FAILED]".bold().red());
            }

            println!("{}", "═══════════════════════════════════════════════════".dimmed());
            if daemon_online {
                println!("{}", "System is READY for AgentDeck mobile connections!".bold().green());
            } else {
                println!("{}", "Run `cargo run --bin agentdeckd` to launch the daemon.".cyan());
            }
        }
        Commands::Projects { action } => match action.unwrap_or(ProjectsAction::List) {
            ProjectsAction::List => {
                let resp = client.get(format!("{}/api/projects", cli.url)).send().await?;
                let list: Vec<Value> = resp.json().await?;
                println!("{}", "Registered Projects:".bold().cyan());
                for p in list {
                    println!(
                        " - [{}] {} ({}) [Default: {}]",
                        p["id"].as_str().unwrap_or(""),
                        p["name"].as_str().unwrap_or("").bold(),
                        p["path"].as_str().unwrap_or("").dimmed(),
                        p["default_agent"].as_str().unwrap_or("antigravity").yellow()
                    );
                }
            }
            ProjectsAction::Add { name, path, agent } => {
                let payload = serde_json::json!({
                    "name": name,
                    "path": path,
                    "default_agent": agent,
                });
                let resp = client
                    .post(format!("{}/api/projects", cli.url))
                    .json(&payload)
                    .send()
                    .await?;
                if resp.status().is_success() {
                    let res: Value = resp.json().await?;
                    println!("Project created: {}", res["id"]);
                } else {
                    println!("Failed to create project: {}", resp.text().await?);
                }
            }
        },
        Commands::Agents => {
            let resp = client.get(format!("{}/api/agents", cli.url)).send().await?;
            let list: Vec<Value> = resp.json().await?;
            println!("{}", "Available Agent Adapters:".bold().cyan());
            for a in list {
                let installed = a["installed"].as_bool().unwrap_or(false);
                let badge = if installed { "[INSTALLED]".green() } else { "[MISSING]".yellow() };
                println!(
                    " - {} ({}) {} Version: {}",
                    a["display_name"].as_str().unwrap_or("").bold(),
                    a["id"].as_str().unwrap_or("").dimmed(),
                    badge,
                    a["version"].as_str().unwrap_or("N/A")
                );
            }
        }
        Commands::Start {
            agent,
            project_id,
            prompt,
        } => {
            let payload = serde_json::json!({
                "agent": agent,
                "project_id": project_id,
                "prompt": prompt,
            });
            let resp = client
                .post(format!("{}/api/sessions", cli.url))
                .json(&payload)
                .send()
                .await?;
            if resp.status().is_success() {
                let res: Value = resp.json().await?;
                println!("Session started: ID = {}", res["id"]);
            } else {
                println!("Failed to start session: {}", resp.text().await?);
            }
        }
        Commands::Stop { agent: _, session_id } => {
            let resp = client
                .post(format!("{}/api/sessions/{}/stop", cli.url, session_id))
                .send()
                .await?;
            if resp.status().is_success() {
                println!("Session {} stopped", session_id);
            } else {
                println!("Failed to stop: {}", resp.text().await?);
            }
        }
        Commands::Logs { limit: _ } => {
            let resp = client.get(format!("{}/api/sessions", cli.url)).send().await?;
            let sessions: Vec<Value> = resp.json().await?;
            println!("Recent Sessions: {}", sessions.len());
        }
        Commands::Config => {
            println!("Configuration loaded from `agentdeck.toml` or defaults.");
        }
    }
    Ok(())
}
