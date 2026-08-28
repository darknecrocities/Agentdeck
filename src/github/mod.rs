use std::path::Path;
use tokio::process::Command;

pub struct GitHubManager;

impl GitHubManager {
    pub async fn get_repo_overview<P: AsRef<Path>>(workspace: P) -> anyhow::Result<serde_json::Value> {
        let path = workspace.as_ref();

        let gh_check = Command::new("which").arg("gh").output().await;
        if gh_check.is_err() || !gh_check.unwrap().status.success() {
            return Ok(serde_json::json!({
                "available": false,
                "reason": "GitHub CLI (gh) not found in PATH"
            }));
        }

        // Pull Requests
        let prs_out = Command::new("gh")
            .current_dir(path)
            .args(["pr", "list", "--json", "number,title,state,author,url", "--limit", "10"])
            .output()
            .await;

        let prs: serde_json::Value = match prs_out {
            Ok(out) if out.status.success() => {
                serde_json::from_slice(&out.stdout).unwrap_or(serde_json::json!([]))
            }
            _ => serde_json::json!([]),
        };

        // Issues
        let issues_out = Command::new("gh")
            .current_dir(path)
            .args(["issue", "list", "--json", "number,title,state,author,url", "--limit", "10"])
            .output()
            .await;

        let issues: serde_json::Value = match issues_out {
            Ok(out) if out.status.success() => {
                serde_json::from_slice(&out.stdout).unwrap_or(serde_json::json!([]))
            }
            _ => serde_json::json!([]),
        };

        // Workflow runs
        let runs_out = Command::new("gh")
            .current_dir(path)
            .args(["run", "list", "--json", "databaseId,status,conclusion,name,headBranch", "--limit", "5"])
            .output()
            .await;

        let runs: serde_json::Value = match runs_out {
            Ok(out) if out.status.success() => {
                serde_json::from_slice(&out.stdout).unwrap_or(serde_json::json!([]))
            }
            _ => serde_json::json!([]),
        };

        Ok(serde_json::json!({
            "available": true,
            "pull_requests": prs,
            "issues": issues,
            "runs": runs,
        }))
    }
}
