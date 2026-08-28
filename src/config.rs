use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub server: ServerConfig,
    pub network: NetworkConfig,
    pub security: SecurityConfig,
    pub agents: AgentsConfig,
    pub projects: ProjectsConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub db_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkConfig {
    pub mode: String, // "tailscale", "localhost", "all"
    pub tailscale_port: u16,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityConfig {
    pub require_auth: bool,
    pub auth_token: String,
    pub allowed_paths: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentsConfig {
    pub antigravity: AgentEntryConfig,
    pub claude: AgentEntryConfig,
    pub gemini: AgentEntryConfig,
    pub ollama: AgentEntryConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentEntryConfig {
    pub enabled: bool,
    pub binary: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectsConfig {
    pub roots: Vec<String>,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            server: ServerConfig {
                host: "0.0.0.0".to_string(),
                port: 8765,
                db_path: "agentdeck.db".to_string(),
            },
            network: NetworkConfig {
                mode: "tailscale".to_string(),
                tailscale_port: 8765,
            },
            security: SecurityConfig {
                require_auth: false,
                auth_token: "agentdeck-secret-token".to_string(),
                allowed_paths: vec![".".to_string()],
            },
            agents: AgentsConfig {
                antigravity: AgentEntryConfig {
                    enabled: true,
                    binary: "agy".to_string(),
                },
                claude: AgentEntryConfig {
                    enabled: true,
                    binary: "claude".to_string(),
                },
                gemini: AgentEntryConfig {
                    enabled: true,
                    binary: "gemini".to_string(),
                },
                ollama: AgentEntryConfig {
                    enabled: true,
                    binary: "ollama".to_string(),
                },
            },
            projects: ProjectsConfig {
                roots: vec!["/path/to/your/projects".to_string()],
            },
        }
    }
}

impl Config {
    pub fn load_from_file<P: AsRef<Path>>(path: P) -> anyhow::Result<Self> {
        let content = std::fs::read_to_string(path)?;
        let config: Config = toml::from_str(&content)?;
        Ok(config)
    }

    pub fn load_or_default(path_opt: Option<&str>) -> Self {
        let mut cfg = if let Some(p) = path_opt {
            Self::load_from_file(p).unwrap_or_default()
        } else if PathBuf::from("agentdeck.toml").exists() {
            Self::load_from_file("agentdeck.toml").unwrap_or_default()
        } else {
            Self::default()
        };
        cfg.apply_env_overrides();
        cfg
    }

    /// Environment variables always win over TOML / defaults.
    pub fn apply_env_overrides(&mut self) {
        if let Ok(v) = std::env::var("AGENTDECK_HOST") {
            self.server.host = v;
        }
        if let Ok(v) = std::env::var("AGENTDECK_PORT") {
            if let Ok(p) = v.parse::<u16>() {
                self.server.port = p;
            }
        }
        if let Ok(v) = std::env::var("AGENTDECK_DB_PATH") {
            self.server.db_path = v;
        }
        if let Ok(v) = std::env::var("AGENTDECK_NETWORK_MODE") {
            self.network.mode = v;
        }
        if let Ok(v) = std::env::var("AGENTDECK_REQUIRE_AUTH") {
            self.security.require_auth = v == "true" || v == "1";
        }
        if let Ok(v) = std::env::var("AGENTDECK_AUTH_TOKEN") {
            self.security.auth_token = v;
        }
        if let Ok(v) = std::env::var("AGENTDECK_AGY_BINARY") {
            self.agents.antigravity.binary = v;
        }
        if let Ok(v) = std::env::var("AGENTDECK_AGY_ENABLED") {
            self.agents.antigravity.enabled = v == "true" || v == "1";
        }
        if let Ok(v) = std::env::var("AGENTDECK_CLAUDE_BINARY") {
            self.agents.claude.binary = v;
        }
        if let Ok(v) = std::env::var("AGENTDECK_CLAUDE_ENABLED") {
            self.agents.claude.enabled = v == "true" || v == "1";
        }
        if let Ok(v) = std::env::var("AGENTDECK_GEMINI_BINARY") {
            self.agents.gemini.binary = v;
        }
        if let Ok(v) = std::env::var("AGENTDECK_GEMINI_ENABLED") {
            self.agents.gemini.enabled = v == "true" || v == "1";
        }
        if let Ok(v) = std::env::var("AGENTDECK_OLLAMA_BINARY") {
            self.agents.ollama.binary = v;
        }
        if let Ok(v) = std::env::var("AGENTDECK_OLLAMA_ENABLED") {
            self.agents.ollama.enabled = v == "true" || v == "1";
        }
        if let Ok(v) = std::env::var("AGENTDECK_PROJECT_ROOTS") {
            self.projects.roots = v.split(',').map(|s| s.trim().to_string()).collect();
        }
    }
}
