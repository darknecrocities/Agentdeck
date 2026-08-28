use agentdeck::security::SecurityManager;
use std::path::PathBuf;

#[test]
fn test_path_traversal_protection() {
    let manifest_dir = env!("CARGO_MANIFEST_DIR");
    let sec = SecurityManager::new(vec![manifest_dir.to_string()], Some("token123".to_string()));

    // Allowed path
    let valid_path = PathBuf::from(manifest_dir).join("Cargo.toml");
    let res = sec.validate_path(&valid_path);
    assert!(res.is_ok(), "Valid internal path should be accepted");

    // Traversal attack
    let evil_path = PathBuf::from(manifest_dir).join("../../etc/passwd");
    let res_evil = sec.validate_path(&evil_path);
    assert!(res_evil.is_err(), "Path traversal must be rejected");

    // Token verification
    assert!(sec.verify_token(Some("token123")));
    assert!(!sec.verify_token(Some("wrong-token")));
    assert!(!sec.verify_token(None));
}
