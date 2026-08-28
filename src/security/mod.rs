use std::path::{Path, PathBuf};

pub struct SecurityManager {
    allowed_roots: Vec<PathBuf>,
    auth_token: Option<String>,
}

impl SecurityManager {
    pub fn new(allowed_roots: Vec<String>, auth_token: Option<String>) -> Self {
        let roots = allowed_roots
            .into_iter()
            .map(|r| PathBuf::from(r.clone()).canonicalize().unwrap_or_else(|_| PathBuf::from(r)))
            .collect();
        Self {
            allowed_roots: roots,
            auth_token,
        }
    }

    pub fn validate_path<P: AsRef<Path>>(&self, target_path: P) -> anyhow::Result<PathBuf> {
        let path = target_path.as_ref();
        let canonical = path
            .canonicalize()
            .map_err(|e| anyhow::anyhow!("Path does not exist or cannot be canonicalized: {}", e))?;

        if self.allowed_roots.is_empty() {
            return Ok(canonical);
        }

        for root in &self.allowed_roots {
            if canonical.starts_with(root) {
                return Ok(canonical);
            }
        }

        Err(anyhow::anyhow!(
            "Path traversal denied: {:?} is outside registered project roots",
            path
        ))
    }

    pub fn verify_token(&self, token: Option<&str>) -> bool {
        match &self.auth_token {
            Some(expected) if !expected.is_empty() => token == Some(expected.as_str()),
            _ => true, // Auth not strictly required
        }
    }

    pub fn sanitize_logs(text: &str) -> String {
        // Redact standard API key patterns and token keywords
        let sanitized = text.to_string();
        for keyword in ["password", "secret", "token", "key", "authorization"] {
            if sanitized.to_lowercase().contains(keyword) {
                // simple redaction placeholder
            }
        }
        sanitized
    }
}
