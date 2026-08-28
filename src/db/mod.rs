use crate::models::{AgentEventPayload, AgentSession, AgentStatus, ApprovalRequest, EventRecord, Project, RiskLevel};
use chrono::{DateTime, Utc};
use rusqlite::{params, Connection};
use std::sync::{Arc, Mutex};


#[derive(Clone)]
pub struct Database {
    conn: Arc<Mutex<Connection>>,
}

impl Database {
    pub fn new(path: &str) -> anyhow::Result<Self> {
        let conn = Connection::open(path)?;
        let db = Self {
            conn: Arc::new(Mutex::new(conn)),
        };
        db.init_schema()?;
        Ok(db)
    }

    pub fn new_in_memory() -> anyhow::Result<Self> {
        let conn = Connection::open_in_memory()?;
        let db = Self {
            conn: Arc::new(Mutex::new(conn)),
        };
        db.init_schema()?;
        Ok(db)
    }

    fn init_schema(&self) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute_batch(
            "
            CREATE TABLE IF NOT EXISTS projects (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                path TEXT NOT NULL,
                default_agent TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                agent TEXT NOT NULL,
                conversation_id TEXT,
                project_id TEXT NOT NULL,
                workspace TEXT NOT NULL,
                status TEXT NOT NULL,
                started_at TEXT NOT NULL,
                last_activity TEXT NOT NULL,
                pid INTEGER,
                last_task TEXT,
                progress_percent INTEGER
            );

            CREATE TABLE IF NOT EXISTS events (
                event_id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT,
                project_id TEXT,
                timestamp TEXT NOT NULL,
                event_type TEXT NOT NULL,
                payload_json TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS approvals (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                agent TEXT NOT NULL,
                request_type TEXT NOT NULL,
                description TEXT NOT NULL,
                command TEXT,
                risk TEXT NOT NULL,
                status TEXT NOT NULL,
                created_at TEXT NOT NULL,
                resolved_at TEXT
            );

            CREATE TABLE IF NOT EXISTS terminal_sessions (
                id TEXT PRIMARY KEY,
                project_id TEXT,
                shell TEXT NOT NULL,
                cols INTEGER NOT NULL,
                rows INTEGER NOT NULL,
                created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            ",
        )?;
        Ok(())
    }

    // Projects
    pub fn list_projects(&self) -> anyhow::Result<Vec<Project>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT id, name, path, default_agent, created_at, updated_at FROM projects")?;
        let rows = stmt.query_map([], |row| {
            let created_at_str: String = row.get(4)?;
            let updated_at_str: String = row.get(5)?;
            Ok(Project {
                id: row.get(0)?,
                name: row.get(1)?,
                path: row.get(2)?,
                default_agent: row.get(3)?,
                created_at: DateTime::parse_from_rfc3339(&created_at_str)
                    .map(|dt| dt.with_timezone(&Utc))
                    .unwrap_or_else(|_| Utc::now()),
                updated_at: DateTime::parse_from_rfc3339(&updated_at_str)
                    .map(|dt| dt.with_timezone(&Utc))
                    .unwrap_or_else(|_| Utc::now()),
            })
        })?;

        let mut list = Vec::new();
        for r in rows {
            list.push(r?);
        }
        Ok(list)
    }

    pub fn insert_project(&self, project: &Project) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO projects (id, name, path, default_agent, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                project.id,
                project.name,
                project.path,
                project.default_agent,
                project.created_at.to_rfc3339(),
                project.updated_at.to_rfc3339()
            ],
        )?;
        Ok(())
    }

    pub fn get_project(&self, id: &str) -> anyhow::Result<Option<Project>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT id, name, path, default_agent, created_at, updated_at FROM projects WHERE id = ?1")?;
        let mut rows = stmt.query(params![id])?;
        if let Some(row) = rows.next()? {
            let created_at_str: String = row.get(4)?;
            let updated_at_str: String = row.get(5)?;
            Ok(Some(Project {
                id: row.get(0)?,
                name: row.get(1)?,
                path: row.get(2)?,
                default_agent: row.get(3)?,
                created_at: DateTime::parse_from_rfc3339(&created_at_str)
                    .map(|dt| dt.with_timezone(&Utc))
                    .unwrap_or_else(|_| Utc::now()),
                updated_at: DateTime::parse_from_rfc3339(&updated_at_str)
                    .map(|dt| dt.with_timezone(&Utc))
                    .unwrap_or_else(|_| Utc::now()),
            }))
        } else {
            Ok(None)
        }
    }

    pub fn delete_project(&self, id: &str) -> anyhow::Result<bool> {
        let conn = self.conn.lock().unwrap();
        let affected = conn.execute("DELETE FROM projects WHERE id = ?1", params![id])?;
        Ok(affected > 0)
    }

    // Sessions
    pub fn save_session(&self, session: &AgentSession) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO sessions (id, agent, conversation_id, project_id, workspace, status, started_at, last_activity, pid, last_task, progress_percent)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
            params![
                session.id,
                session.agent,
                session.conversation_id,
                session.project_id,
                session.workspace,
                session.status.to_string(),
                session.started_at.to_rfc3339(),
                session.last_activity.to_rfc3339(),
                session.pid,
                session.last_task,
                session.progress_percent
            ],
        )?;
        Ok(())
    }

    pub fn get_session(&self, id: &str) -> anyhow::Result<Option<AgentSession>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, agent, conversation_id, project_id, workspace, status, started_at, last_activity, pid, last_task, progress_percent
             FROM sessions WHERE id = ?1",
        )?;
        let mut rows = stmt.query(params![id])?;
        if let Some(row) = rows.next()? {
            let status_str: String = row.get(5)?;
            let started_at_str: String = row.get(6)?;
            let last_activity_str: String = row.get(7)?;
            Ok(Some(AgentSession {
                id: row.get(0)?,
                agent: row.get(1)?,
                conversation_id: row.get(2)?,
                project_id: row.get(3)?,
                workspace: row.get(4)?,
                status: AgentStatus::from(status_str.as_str()),
                started_at: DateTime::parse_from_rfc3339(&started_at_str)
                    .map(|dt| dt.with_timezone(&Utc))
                    .unwrap_or_else(|_| Utc::now()),
                last_activity: DateTime::parse_from_rfc3339(&last_activity_str)
                    .map(|dt| dt.with_timezone(&Utc))
                    .unwrap_or_else(|_| Utc::now()),
                pid: row.get(8)?,
                last_task: row.get(9)?,
                progress_percent: row.get(10)?,
            }))
        } else {
            Ok(None)
        }
    }

    pub fn list_sessions(&self) -> anyhow::Result<Vec<AgentSession>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, agent, conversation_id, project_id, workspace, status, started_at, last_activity, pid, last_task, progress_percent
             FROM sessions ORDER BY started_at DESC",
        )?;
        let rows = stmt.query_map([], |row| {
            let status_str: String = row.get(5)?;
            let started_at_str: String = row.get(6)?;
            let last_activity_str: String = row.get(7)?;
            Ok(AgentSession {
                id: row.get(0)?,
                agent: row.get(1)?,
                conversation_id: row.get(2)?,
                project_id: row.get(3)?,
                workspace: row.get(4)?,
                status: AgentStatus::from(status_str.as_str()),
                started_at: DateTime::parse_from_rfc3339(&started_at_str)
                    .map(|dt| dt.with_timezone(&Utc))
                    .unwrap_or_else(|_| Utc::now()),
                last_activity: DateTime::parse_from_rfc3339(&last_activity_str)
                    .map(|dt| dt.with_timezone(&Utc))
                    .unwrap_or_else(|_| Utc::now()),
                pid: row.get(8)?,
                last_task: row.get(9)?,
                progress_percent: row.get(10)?,
            })
        })?;

        let mut list = Vec::new();
        for r in rows {
            list.push(r?);
        }
        Ok(list)
    }

    // Events
    pub fn insert_event(
        &self,
        session_id: Option<&str>,
        project_id: Option<&str>,
        event_type: &str,
        payload: &AgentEventPayload,
    ) -> anyhow::Result<EventRecord> {
        let timestamp = Utc::now();
        let payload_json = serde_json::to_string(payload)?;
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT INTO events (session_id, project_id, timestamp, event_type, payload_json) VALUES (?1, ?2, ?3, ?4, ?5)",
            params![session_id, project_id, timestamp.to_rfc3339(), event_type, payload_json],
        )?;
        let event_id = conn.last_insert_rowid();
        Ok(EventRecord {
            event_id,
            session_id: session_id.map(|s| s.to_string()),
            project_id: project_id.map(|s| s.to_string()),
            timestamp,
            event_type: event_type.to_string(),
            payload: payload.clone(),
        })
    }

    pub fn get_events_after(&self, after_event_id: i64, limit: usize) -> anyhow::Result<Vec<EventRecord>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT event_id, session_id, project_id, timestamp, event_type, payload_json
             FROM events WHERE event_id > ?1 ORDER BY event_id ASC LIMIT ?2",
        )?;
        let rows = stmt.query_map(params![after_event_id, limit as i64], |row| {
            let timestamp_str: String = row.get(3)?;
            let payload_json: String = row.get(5)?;
            let payload: AgentEventPayload = serde_json::from_str(&payload_json)
                .unwrap_or(AgentEventPayload::AgentMessage {
                    content: payload_json.clone(),
                });
            Ok(EventRecord {
                event_id: row.get(0)?,
                session_id: row.get(1)?,
                project_id: row.get(2)?,
                timestamp: DateTime::parse_from_rfc3339(&timestamp_str)
                    .map(|dt| dt.with_timezone(&Utc))
                    .unwrap_or_else(|_| Utc::now()),
                event_type: row.get(4)?,
                payload,
            })
        })?;

        let mut list = Vec::new();
        for r in rows {
            list.push(r?);
        }
        Ok(list)
    }

    pub fn get_session_events(&self, session_id: &str, after_event_id: i64) -> anyhow::Result<Vec<EventRecord>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT event_id, session_id, project_id, timestamp, event_type, payload_json
             FROM events WHERE session_id = ?1 AND event_id > ?2 ORDER BY event_id ASC",
        )?;
        let rows = stmt.query_map(params![session_id, after_event_id], |row| {
            let timestamp_str: String = row.get(3)?;
            let payload_json: String = row.get(5)?;
            let payload: AgentEventPayload = serde_json::from_str(&payload_json)
                .unwrap_or(AgentEventPayload::AgentMessage {
                    content: payload_json.clone(),
                });
            Ok(EventRecord {
                event_id: row.get(0)?,
                session_id: row.get(1)?,
                project_id: row.get(2)?,
                timestamp: DateTime::parse_from_rfc3339(&timestamp_str)
                    .map(|dt| dt.with_timezone(&Utc))
                    .unwrap_or_else(|_| Utc::now()),
                event_type: row.get(4)?,
                payload,
            })
        })?;

        let mut list = Vec::new();
        for r in rows {
            list.push(r?);
        }
        Ok(list)
    }

    // Approvals
    pub fn insert_approval(&self, approval: &ApprovalRequest) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO approvals (id, session_id, agent, request_type, description, command, risk, status, created_at, resolved_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
            params![
                approval.id,
                approval.session_id,
                approval.agent,
                approval.request_type,
                approval.description,
                approval.command,
                approval.risk.to_string(),
                approval.status,
                approval.created_at.to_rfc3339(),
                approval.resolved_at.map(|dt| dt.to_rfc3339()),
            ],
        )?;
        Ok(())
    }

    pub fn list_pending_approvals(&self) -> anyhow::Result<Vec<ApprovalRequest>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, session_id, agent, request_type, description, command, risk, status, created_at, resolved_at
             FROM approvals WHERE status = 'pending' ORDER BY created_at ASC",
        )?;
        let rows = stmt.query_map([], |row| {
            let risk_str: String = row.get(6)?;
            let created_at_str: String = row.get(8)?;
            let resolved_at_str: Option<String> = row.get(9)?;
            Ok(ApprovalRequest {
                id: row.get(0)?,
                session_id: row.get(1)?,
                agent: row.get(2)?,
                request_type: row.get(3)?,
                description: row.get(4)?,
                command: row.get(5)?,
                risk: RiskLevel::from(risk_str.as_str()),
                status: row.get(7)?,
                created_at: DateTime::parse_from_rfc3339(&created_at_str)
                    .map(|dt| dt.with_timezone(&Utc))
                    .unwrap_or_else(|_| Utc::now()),
                resolved_at: resolved_at_str.and_then(|s| {
                    DateTime::parse_from_rfc3339(&s)
                        .map(|dt| dt.with_timezone(&Utc))
                        .ok()
                }),
            })
        })?;

        let mut list = Vec::new();
        for r in rows {
            list.push(r?);
        }
        Ok(list)
    }

    pub fn resolve_approval(&self, id: &str, status: &str) -> anyhow::Result<bool> {
        let conn = self.conn.lock().unwrap();
        let now = Utc::now().to_rfc3339();
        let affected = conn.execute(
            "UPDATE approvals SET status = ?1, resolved_at = ?2 WHERE id = ?3 AND status = 'pending'",
            params![status, now, id],
        )?;
        Ok(affected > 0)
    }
}
