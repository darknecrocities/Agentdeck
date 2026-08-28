use crate::models::RiskLevel;

pub fn classify_command_risk(command: &str) -> RiskLevel {
    let lower = command.trim().to_lowercase();

    // Critical risks
    if lower.contains("rm -rf /")
        || lower.contains("sudo")
        || lower.contains("mkfs")
        || lower.contains("dd if=")
        || lower.contains("shutdown")
        || lower.contains("reboot")
    {
        return RiskLevel::Critical;
    }

    // High risks
    if lower.contains("rm -rf")
        || lower.contains("git push --force")
        || lower.contains("git push -f")
        || lower.contains("git reset --hard")
        || lower.contains("drop table")
        || lower.contains("drop database")
        || lower.contains("curl") && lower.contains("| bash")
        || lower.contains("curl") && lower.contains("| sh")
        || lower.contains("wget") && lower.contains("| bash")
    {
        return RiskLevel::High;
    }

    // Medium risks
    if lower.starts_with("git push")
        || lower.starts_with("npm publish")
        || lower.starts_with("cargo publish")
        || lower.starts_with("npm install -g")
        || lower.starts_with("pip install")
        || lower.starts_with("brew install")
        || lower.starts_with("kill ")
        || lower.starts_with("pkill ")
    {
        return RiskLevel::Medium;
    }

    RiskLevel::Low
}
