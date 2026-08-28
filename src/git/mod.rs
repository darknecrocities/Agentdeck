use crate::models::GitStatusInfo;
use std::path::Path;
use tokio::process::Command;

pub struct GitManager;

impl GitManager {
    pub async fn get_status<P: AsRef<Path>>(workspace: P) -> anyhow::Result<GitStatusInfo> {
        let path = workspace.as_ref();

        // Check if git repo
        let branch_output = Command::new("git")
            .current_dir(path)
            .args(["rev-parse", "--abbrev-ref", "HEAD"])
            .output()
            .await?;

        if !branch_output.status.success() {
            return Ok(GitStatusInfo {
                branch: "none".to_string(),
                is_clean: true,
                ahead: 0,
                behind: 0,
                modified_files: vec![],
                staged_files: vec![],
                untracked_files: vec![],
            });
        }

        let branch = String::from_utf8_lossy(&branch_output.stdout).trim().to_string();

        // Get status porcelain
        let status_output = Command::new("git")
            .current_dir(path)
            .args(["status", "--porcelain"])
            .output()
            .await?;

        let status_text = String::from_utf8_lossy(&status_output.stdout);
        let mut modified_files = Vec::new();
        let mut staged_files = Vec::new();
        let mut untracked_files = Vec::new();

        for line in status_text.lines() {
            if line.len() < 4 {
                continue;
            }
            let index_status = line.chars().next().unwrap_or(' ');
            let worktree_status = line.chars().nth(1).unwrap_or(' ');
            let file_path = line[3..].trim().to_string();

            if index_status != ' ' && index_status != '?' {
                staged_files.push(file_path.clone());
            }
            if worktree_status == 'M' || worktree_status == 'D' {
                modified_files.push(file_path.clone());
            } else if index_status == '?' && worktree_status == '?' {
                untracked_files.push(file_path);
            }
        }

        let is_clean = modified_files.is_empty() && staged_files.is_empty() && untracked_files.is_empty();

        // Ahead/behind
        let mut ahead = 0;
        let mut behind = 0;
        if let Ok(rev_out) = Command::new("git")
            .current_dir(path)
            .args(["rev-list", "--left-right", "--count", "@{upstream}...HEAD"])
            .output()
            .await
        {
            if rev_out.status.success() {
                let counts = String::from_utf8_lossy(&rev_out.stdout);
                let parts: Vec<&str> = counts.split_whitespace().collect();
                if parts.len() >= 2 {
                    behind = parts[0].parse().unwrap_or(0);
                    ahead = parts[1].parse().unwrap_or(0);
                }
            }
        }

        Ok(GitStatusInfo {
            branch,
            is_clean,
            ahead,
            behind,
            modified_files,
            staged_files,
            untracked_files,
        })
    }

    pub async fn get_diff<P: AsRef<Path>>(workspace: P) -> anyhow::Result<String> {
        let output = Command::new("git")
            .current_dir(workspace)
            .args(["diff", "HEAD"])
            .output()
            .await?;

        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    }

    pub async fn get_log<P: AsRef<Path>>(workspace: P, limit: usize) -> anyhow::Result<Vec<serde_json::Value>> {
        let output = Command::new("git")
            .current_dir(workspace)
            .args([
                "log",
                &format!("-n{}", limit),
                "--pretty=format:%H|%an|%ae|%ad|%s",
                "--date=iso",
            ])
            .output()
            .await?;

        let text = String::from_utf8_lossy(&output.stdout);
        let mut logs = Vec::new();
        for line in text.lines() {
            let parts: Vec<&str> = line.split('|').collect();
            if parts.len() >= 5 {
                logs.push(serde_json::json!({
                    "hash": parts[0],
                    "author_name": parts[1],
                    "author_email": parts[2],
                    "date": parts[3],
                    "message": parts[4],
                }));
            }
        }
        Ok(logs)
    }

    pub async fn commit<P: AsRef<Path>>(workspace: P, message: &str) -> anyhow::Result<String> {
        Command::new("git")
            .current_dir(&workspace)
            .args(["add", "-A"])
            .output()
            .await?;

        let output = Command::new("git")
            .current_dir(workspace)
            .args(["commit", "-m", message])
            .output()
            .await?;

        if output.status.success() {
            Ok(String::from_utf8_lossy(&output.stdout).to_string())
        } else {
            Err(anyhow::anyhow!(
                "Git commit failed: {}",
                String::from_utf8_lossy(&output.stderr)
            ))
        }
    }

    pub async fn push<P: AsRef<Path>>(workspace: P) -> anyhow::Result<String> {
        let output = Command::new("git")
            .current_dir(workspace)
            .args(["push"])
            .output()
            .await?;

        if output.status.success() {
            Ok(String::from_utf8_lossy(&output.stdout).to_string())
        } else {
            Err(anyhow::anyhow!(
                "Git push failed: {}",
                String::from_utf8_lossy(&output.stderr)
            ))
        }
    }

    pub async fn pull<P: AsRef<Path>>(workspace: P) -> anyhow::Result<String> {
        let output = Command::new("git")
            .current_dir(workspace)
            .args(["pull"])
            .output()
            .await?;

        if output.status.success() {
            Ok(String::from_utf8_lossy(&output.stdout).to_string())
        } else {
            Err(anyhow::anyhow!(
                "Git pull failed: {}",
                String::from_utf8_lossy(&output.stderr)
            ))
        }
    }
}
