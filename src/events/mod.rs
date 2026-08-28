use crate::db::Database;
use crate::models::{AgentEventPayload, EventRecord};
use tokio::sync::broadcast;

#[derive(Clone)]
pub struct EventBus {
    sender: broadcast::Sender<EventRecord>,
    db: Database,
}

impl EventBus {
    pub fn new(db: Database) -> Self {
        let (sender, _) = broadcast::channel(1024);
        Self { sender, db }
    }

    pub fn subscribe(&self) -> broadcast::Receiver<EventRecord> {
        self.sender.subscribe()
    }

    pub fn publish(
        &self,
        session_id: Option<&str>,
        project_id: Option<&str>,
        event_type: &str,
        payload: AgentEventPayload,
    ) -> anyhow::Result<EventRecord> {
        // Persist sequentially to SQLite
        let record = self.db.insert_event(session_id, project_id, event_type, &payload)?;

        // Broadcast to live subscribers (WebSockets, listeners)
        if let Err(e) = self.sender.send(record.clone()) {
            // It's normal for send to fail if there are currently zero active subscribers
            tracing::trace!("No active EventBus subscribers: {}", e);
        }

        Ok(record)
    }

    pub fn get_replay_events(&self, after_event_id: i64, limit: usize) -> anyhow::Result<Vec<EventRecord>> {
        self.db.get_events_after(after_event_id, limit)
    }

    pub fn get_session_replay_events(&self, session_id: &str, after_event_id: i64) -> anyhow::Result<Vec<EventRecord>> {
        self.db.get_session_events(session_id, after_event_id)
    }

    pub fn db(&self) -> &Database {
        &self.db
    }
}
