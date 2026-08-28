use agentdeck::agents::antigravity::parser::AntigravityParser;
use agentdeck::agents::antigravity::AntigravityAgent;
use agentdeck::agents::AgentAdapter;
use agentdeck::db::Database;
use agentdeck::events::EventBus;
use agentdeck::models::{AgentEventPayload, AgentStartRequest};
use std::path::PathBuf;
use std::time::Duration;
use tokio::time::sleep;

#[test]
fn test_antigravity_parser_stream_json() {
    let json_line = r#"{"type":"tool_started","tool":"list_dir","input":{"path":"."}}"#;
    let event = AntigravityParser::parse_line(json_line).expect("Should parse tool_started");
    match event {
        AgentEventPayload::ToolStarted { tool, .. } => {
            assert_eq!(tool, "list_dir");
        }
        _ => panic!("Expected ToolStarted"),
    }

    let file_mod_line = r#"{"type":"file_modified","path":"src/main.rs"}"#;
    let event2 = AntigravityParser::parse_line(file_mod_line).expect("Should parse file_modified");
    match event2 {
        AgentEventPayload::FileModified { path } => {
            assert_eq!(path, "src/main.rs");
        }
        _ => panic!("Expected FileModified"),
    }
}

#[tokio::test]
async fn test_antigravity_fake_agent_execution() {
    let db = Database::new_in_memory().unwrap();
    let bus = EventBus::new(db.clone());
    let mut rx = bus.subscribe();

    let fake_agent_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures/fake-agent")
        .to_string_lossy()
        .to_string();

    let agent = AntigravityAgent::new(Some(fake_agent_path));
    let detect_info = agent.detect().await.expect("Should detect fake agent");
    assert!(detect_info.installed);
    assert_eq!(detect_info.version.unwrap(), "agy 1.2.0 (fake-agent test fixture)");

    let req = AgentStartRequest {
        project_id: "test-proj-1".to_string(),
        workspace_path: env!("CARGO_MANIFEST_DIR").to_string(),
        prompt: "Run object detection pipeline".to_string(),
        conversation_id: None,
        model: None,
        effort: None,
    };

    let session = agent.start(req, bus.clone()).await.expect("Should start session");
    assert_eq!(session.agent, "antigravity");

    // Receive events from fake agent
    let mut received_file_created = false;
    let mut received_cmd_finished = false;

    for _ in 0..20 {
        if let Ok(record) = rx.try_recv() {
            match record.payload {
                AgentEventPayload::FileCreated { path } => {
                    if path.contains("detector_service.dart") {
                        received_file_created = true;
                    }
                }
                AgentEventPayload::CommandFinished { exit_code, .. } => {
                    if exit_code == 0 {
                        received_cmd_finished = true;
                    }
                }
                _ => {}
            }
        }
        sleep(Duration::from_millis(50)).await;
    }

    assert!(received_file_created, "Expected FileCreated event from fake agent");
    assert!(received_cmd_finished, "Expected CommandFinished event from fake agent");
}
