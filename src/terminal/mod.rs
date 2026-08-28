use crate::models::TerminalSessionInfo;
use chrono::Utc;
use portable_pty::{native_pty_system, CommandBuilder, MasterPty, PtyPair, PtySize};
use std::collections::HashMap;
use std::io::{Read, Write};
use std::sync::{Arc, Mutex};
use tokio::sync::broadcast;
use uuid::Uuid;

pub struct PtySession {
    pub info: TerminalSessionInfo,
    pub master: Arc<Mutex<Box<dyn MasterPty + Send>>>,
    pub output_tx: broadcast::Sender<Vec<u8>>,
    pub writer: Arc<Mutex<Box<dyn Write + Send>>>,
}

pub struct TerminalManager {
    sessions: Arc<Mutex<HashMap<String, Arc<PtySession>>>>,
}

impl TerminalManager {
    pub fn new() -> Self {
        Self {
            sessions: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub fn spawn_session(
        &self,
        project_id: Option<String>,
        cwd: Option<String>,
        cols: u16,
        rows: u16,
    ) -> anyhow::Result<Arc<PtySession>> {
        let pty_system = native_pty_system();
        let pair: PtyPair = pty_system.openpty(PtySize {
            rows,
            cols,
            pixel_width: 0,
            pixel_height: 0,
        })?;

        let shell = std::env::var("SHELL").unwrap_or_else(|_| "/bin/zsh".to_string());
        let mut cmd = CommandBuilder::new(&shell);
        if let Some(dir) = cwd {
            cmd.cwd(dir);
        }

        let _child = pair.slave.spawn_command(cmd)?;
        let id = Uuid::new_v4().to_string();
        let (output_tx, _) = broadcast::channel(512);

        let mut reader = pair.master.try_clone_reader()?;
        let writer = Arc::new(Mutex::new(pair.master.take_writer()?));
        let master = Arc::new(Mutex::new(pair.master));

        let info = TerminalSessionInfo {
            id: id.clone(),
            project_id,
            shell,
            cols,
            rows,
            created_at: Utc::now(),
        };

        let output_tx_clone = output_tx.clone();
        // Background thread to read stdout/stderr from PTY master
        std::thread::spawn(move || {
            let mut buf = [0u8; 1024];
            while let Ok(n) = reader.read(&mut buf) {
                if n == 0 {
                    break;
                }
                let _ = output_tx_clone.send(buf[..n].to_vec());
            }
        });

        let session = Arc::new(PtySession {
            info,
            master,
            output_tx,
            writer,
        });

        let mut lock = self.sessions.lock().unwrap();
        lock.insert(id.clone(), session.clone());

        Ok(session)
    }

    pub fn get_session(&self, id: &str) -> Option<Arc<PtySession>> {
        let lock = self.sessions.lock().unwrap();
        lock.get(id).cloned()
    }

    pub fn list_sessions(&self) -> Vec<TerminalSessionInfo> {
        let lock = self.sessions.lock().unwrap();
        lock.values().map(|s| s.info.clone()).collect()
    }

    pub fn write_input(&self, id: &str, data: &[u8]) -> anyhow::Result<()> {
        if let Some(session) = self.get_session(id) {
            let mut writer = session.writer.lock().unwrap();
            writer.write_all(data)?;
            writer.flush()?;
            Ok(())
        } else {
            Err(anyhow::anyhow!("Terminal session not found: {}", id))
        }
    }

    pub fn resize(&self, id: &str, cols: u16, rows: u16) -> anyhow::Result<()> {
        if let Some(session) = self.get_session(id) {
            let master = session.master.lock().unwrap();
            master.resize(PtySize {
                rows,
                cols,
                pixel_width: 0,
                pixel_height: 0,
            })?;
            Ok(())
        } else {
            Err(anyhow::anyhow!("Terminal session not found: {}", id))
        }
    }

    pub fn close_session(&self, id: &str) -> bool {
        let mut lock = self.sessions.lock().unwrap();
        lock.remove(id).is_some()
    }
}
