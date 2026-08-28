use crate::events::EventBus;
use crate::models::{AgentEventPayload, ApprovalRequest, RiskLevel};
use chrono::Utc;
use uuid::Uuid;

pub struct ApprovalManager {
    event_bus: EventBus,
}

impl ApprovalManager {
    pub fn new(event_bus: EventBus) -> Self {
        Self { event_bus }
    }

    pub fn create_request(
        &self,
        session_id: &str,
        agent: &str,
        request_type: &str,
        description: &str,
        command: Option<String>,
        risk: RiskLevel,
    ) -> anyhow::Result<ApprovalRequest> {
        let id = Uuid::new_v4().to_string();
        let approval = ApprovalRequest {
            id: id.clone(),
            session_id: session_id.to_string(),
            agent: agent.to_string(),
            request_type: request_type.to_string(),
            description: description.to_string(),
            command: command.clone(),
            risk: risk.clone(),
            status: "pending".to_string(),
            created_at: Utc::now(),
            resolved_at: None,
        };

        self.event_bus.db().insert_approval(&approval)?;

        let _ = self.event_bus.publish(
            Some(session_id),
            None,
            "approval_required",
            AgentEventPayload::ApprovalRequired {
                request_id: id,
                description: description.to_string(),
                command,
                risk: risk.to_string(),
            },
        );

        Ok(approval)
    }

    pub fn list_pending(&self) -> anyhow::Result<Vec<ApprovalRequest>> {
        self.event_bus.db().list_pending_approvals()
    }

    pub fn resolve(&self, id: &str, approved: bool) -> anyhow::Result<bool> {
        let status = if approved { "approved" } else { "denied" };
        let success = self.event_bus.db().resolve_approval(id, status)?;

        if success {
            let _ = self.event_bus.publish(
                None,
                None,
                "approval_resolved",
                AgentEventPayload::ApprovalResolved {
                    request_id: id.to_string(),
                    approved,
                },
            );
        }

        Ok(success)
    }
}
