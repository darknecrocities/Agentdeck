use agentdeck::terminal::TerminalManager;
use std::time::Duration;
use tokio::time::sleep;

#[tokio::test]
async fn test_terminal_pty_session() {
    let mgr = TerminalManager::new();
    let session = mgr
        .spawn_session(None, None, 80, 24)
        .expect("Should spawn PTY session");

    let mut rx = session.output_tx.subscribe();

    // Write a simple echo command
    mgr.write_input(&session.info.id, b"echo 'agentdeck-terminal-alive'\n")
        .expect("Should write input");

    let mut received_alive = false;
    for _ in 0..20 {
        if let Ok(bytes) = rx.try_recv() {
            let s = String::from_utf8_lossy(&bytes);
            if s.contains("agentdeck-terminal-alive") {
                received_alive = true;
                break;
            }
        }
        sleep(Duration::from_millis(50)).await;
    }

    assert!(received_alive, "Terminal should execute and echo input bytes");
    assert!(mgr.close_session(&session.info.id));
}
