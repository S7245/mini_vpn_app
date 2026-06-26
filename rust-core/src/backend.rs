//! Slice ② BackendService — the App ↔ cloud control plane (auth / nodes /
//! subscription / devices). This is the MOCK impl: it decodes the embedded
//! `contracts/mock` fixtures, mirroring Swift `MockBackendService`. Methods are
//! async (UniFFI tokio → Kotlin `suspend fun`) so the real networked impl drops
//! in behind the same exported API with no UI change.

use std::sync::Arc;

use crate::models::{Device, DeviceList, Node, NodeList, SelectBestResponse, Subscription, TokenPair};

/// Mirrors Swift `BackendError`. Surfaces as a Kotlin exception.
#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum BackendError {
    #[error("not implemented")]
    NotImplemented,
    #[error("unauthorized")]
    Unauthorized,
    #[error("device limit exceeded")]
    DeviceLimitExceeded,
    #[error("transport error: {detail}")]
    Transport { detail: String },
}

fn decode<T: serde::de::DeserializeOwned>(raw: &str) -> Result<T, BackendError> {
    serde_json::from_str(raw).map_err(|e| BackendError::Transport { detail: e.to_string() })
}

// Embedded contract fixtures (synced from contracts/mock by scripts/sync-mocks.sh).
const TOKEN_PAIR: &str = include_str!("../fixtures/token-pair.json");
const SUBSCRIPTION: &str = include_str!("../fixtures/subscription.json");
const DEVICE: &str = include_str!("../fixtures/device.json");
const DEVICE_LIST: &str = include_str!("../fixtures/device-list.json");
const NODE_LIST: &str = include_str!("../fixtures/node-list.json");
const SELECT_BEST: &str = include_str!("../fixtures/select-best.json");

/// Mock ② BackendService. A real transport will expose the SAME methods later
/// (mock→real swap, no UI change).
#[derive(uniffi::Object)]
pub struct BackendService;

#[uniffi::export(async_runtime = "tokio")]
impl BackendService {
    #[uniffi::constructor]
    pub fn new() -> Arc<Self> {
        Arc::new(Self)
    }

    pub async fn register(&self, _email: String, _password: String) -> Result<TokenPair, BackendError> {
        decode(TOKEN_PAIR)
    }
    pub async fn login(&self, _email: String, _password: String) -> Result<TokenPair, BackendError> {
        decode(TOKEN_PAIR)
    }
    pub async fn refresh(&self, _refresh_token: String) -> Result<TokenPair, BackendError> {
        decode(TOKEN_PAIR)
    }
    pub async fn logout(&self) -> Result<(), BackendError> {
        Ok(())
    }
    pub async fn change_password(&self, _old: String, _new: String) -> Result<(), BackendError> {
        Ok(())
    }

    pub async fn get_subscription(&self) -> Result<Subscription, BackendError> {
        decode(SUBSCRIPTION)
    }
    pub async fn list_devices(&self) -> Result<DeviceList, BackendError> {
        decode(DEVICE_LIST)
    }
    pub async fn register_device(&self, _name: String, _platform: String) -> Result<Device, BackendError> {
        decode(DEVICE)
    }
    pub async fn revoke_device(&self, _id: String) -> Result<(), BackendError> {
        Ok(())
    }

    pub async fn list_nodes(&self) -> Result<Vec<Node>, BackendError> {
        decode::<NodeList>(NODE_LIST).map(|l| l.nodes)
    }
    pub async fn select_best(&self) -> Result<SelectBestResponse, BackendError> {
        decode(SELECT_BEST)
    }

    pub async fn purchase_subscription(&self) -> Result<(), BackendError> {
        Err(BackendError::NotImplemented)
    }
    pub async fn purchase_dedicated_ip(&self) -> Result<(), BackendError> {
        Err(BackendError::NotImplemented)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::Node;

    fn svc() -> Arc<BackendService> {
        BackendService::new()
    }

    #[tokio::test]
    async fn login_decodes_token_pair() {
        let t = svc().login("a@b.com".into(), "pw".into()).await.unwrap();
        assert_eq!(t.token_type, "Bearer");
        assert_eq!(t.expires_in, 3600);
        assert!(t.access_token.starts_with("eyJ"));
    }

    #[tokio::test]
    async fn subscription_decodes() {
        let s = svc().get_subscription().await.unwrap();
        assert_eq!(s.plan, "monthly");
        assert_eq!(s.status, "active");
        assert_eq!(s.device_limit, 3);
        assert_eq!(s.expires_at.as_deref(), Some("2026-07-12T08:00:00Z"));
    }

    #[tokio::test]
    async fn device_list_decodes_with_limit() {
        let d = svc().list_devices().await.unwrap();
        assert_eq!(d.device_limit, 3);
        assert_eq!(d.devices.len(), 1);
        assert_eq!(d.devices[0].platform, "macos");
    }

    #[tokio::test]
    async fn nodes_decode_shared_and_dedicated() {
        let nodes = svc().list_nodes().await.unwrap();
        assert_eq!(nodes.len(), 3);
        // First two shared, last dedicated (per fixture).
        assert!(matches!(nodes[0], Node::Shared { .. }));
        match &nodes[2] {
            Node::Dedicated { static_ip, expires_at, city, .. } => {
                assert_eq!(static_ip, "203.0.113.9");
                assert_eq!(city, "San Jose");
                assert_eq!(expires_at, "2026-09-01T00:00:00Z");
            }
            _ => panic!("expected dedicated"),
        }
    }

    #[tokio::test]
    async fn select_best_decodes() {
        let r = svc().select_best().await.unwrap();
        assert_eq!(r.node_id, "44444444-4444-4444-8444-444444444444");
        assert!(!r.reason.is_empty());
    }

    #[tokio::test]
    async fn purchases_not_implemented() {
        assert!(matches!(
            svc().purchase_subscription().await,
            Err(BackendError::NotImplemented)
        ));
    }
}
