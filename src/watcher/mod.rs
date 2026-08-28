use crate::events::EventBus;
use crate::models::AgentEventPayload;
use notify::{Config, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tracing::{error, info};

pub struct ProjectWatcher {
    _watcher: RecommendedWatcher,
    watched_paths: Arc<Mutex<HashMap<String, PathBuf>>>,
}

impl ProjectWatcher {
    pub fn new(event_bus: EventBus) -> anyhow::Result<Self> {
        let watched_paths = Arc::new(Mutex::new(HashMap::new()));
        let _watched_paths_clone = watched_paths.clone();

        // In-memory debouncer cache: path -> last_event_time
        let recent_events = Arc::new(Mutex::new(HashMap::<PathBuf, Instant>::new()));

        let watcher = RecommendedWatcher::new(
            move |res: Result<Event, notify::Error>| match res {
                Ok(event) => {
                    let mut is_ignored = false;
                    for p in &event.paths {
                        let path_str = p.to_string_lossy();
                        if path_str.contains("/.git/")
                            || path_str.contains("/target/")
                            || path_str.contains("/node_modules/")
                            || path_str.contains("/.dart_tool/")
                            || path_str.contains("/build/")
                            || path_str.ends_with(".db")
                            || path_str.ends_with(".db-journal")
                        {
                            is_ignored = true;
                            break;
                        }
                    }

                    if is_ignored {
                        return;
                    }

                    for path in event.paths {
                        let now = Instant::now();
                        {
                            let mut cache = recent_events.lock().unwrap();
                            if let Some(last_time) = cache.get(&path) {
                                if now.duration_since(*last_time) < Duration::from_millis(500) {
                                    // Coalesce rapid duplicate edits
                                    continue;
                                }
                            }
                            cache.insert(path.clone(), now);
                        }

                        let path_str = path.to_string_lossy().to_string();

                        let payload_opt = match event.kind {
                            EventKind::Create(_) => Some(AgentEventPayload::FileCreated { path: path_str }),
                            EventKind::Modify(_) => Some(AgentEventPayload::FileModified { path: path_str }),
                            EventKind::Remove(_) => Some(AgentEventPayload::FileDeleted { path: path_str }),
                            _ => None,
                        };

                        if let Some(payload) = payload_opt {
                            let _ = event_bus.publish(None, None, "file_event", payload);
                        }
                    }
                }
                Err(e) => {
                    error!("Watcher error: {:?}", e);
                }
            },
            Config::default(),
        )?;

        Ok(Self {
            _watcher: watcher,
            watched_paths,
        })
    }

    pub fn watch_directory<P: AsRef<Path>>(&mut self, project_id: &str, path: P) -> anyhow::Result<()> {
        let p = path.as_ref().to_path_buf();
        if p.exists() {
            self._watcher.watch(&p, RecursiveMode::Recursive)?;
            let mut lock = self.watched_paths.lock().unwrap();
            lock.insert(project_id.to_string(), p);
            info!("Watching project {} at {:?}", project_id, path.as_ref());
        }
        Ok(())
    }

    pub fn unwatch_directory(&mut self, project_id: &str) -> anyhow::Result<()> {
        let mut lock = self.watched_paths.lock().unwrap();
        if let Some(path) = lock.remove(project_id) {
            let _ = self._watcher.unwatch(&path);
        }
        Ok(())
    }
}
