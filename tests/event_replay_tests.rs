use agentdeck::db::Database;
use agentdeck::events::EventBus;
use agentdeck::models::AgentEventPayload;

#[tokio::test]
async fn test_event_persistence_and_replay() {
    let db = Database::new_in_memory().unwrap();
    let bus = EventBus::new(db.clone());

    // Publish 5 events
    for i in 1..=5 {
        bus.publish(
            Some("sess-1"),
            Some("proj-1"),
            "agent_message",
            AgentEventPayload::AgentMessage {
                content: format!("Step {}", i),
            },
        )
        .unwrap();
    }

    // Client reconnects and requests events after event_id 2
    let replayed = bus.get_replay_events(2, 10).unwrap();
    assert_eq!(replayed.len(), 3);
    assert_eq!(replayed[0].event_id, 3);
    assert_eq!(replayed[1].event_id, 4);
    assert_eq!(replayed[2].event_id, 5);

    // Session specific replay
    let session_replayed = bus.get_session_replay_events("sess-1", 3).unwrap();
    assert_eq!(session_replayed.len(), 2);
    assert_eq!(session_replayed[0].event_id, 4);
    assert_eq!(session_replayed[1].event_id, 5);
}
