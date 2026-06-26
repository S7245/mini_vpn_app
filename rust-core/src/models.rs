//! Slice ② models — mirror the Swift `apple-core` models and decode the SAME
//! `contracts/mock` fixtures. Rust fields are snake_case so they match the
//! contract JSON keys directly (no serde rename); UniFFI converts them to
//! camelCase on the Kotlin side, matching the contract's camelCase API names.

use serde::Deserialize;

#[derive(Debug, Clone, PartialEq, uniffi::Record, Deserialize)]
pub struct TokenPair {
    pub access_token: String,
    pub refresh_token: String,
    pub token_type: String,
    pub expires_in: i32,
}

#[derive(Debug, Clone, PartialEq, uniffi::Record, Deserialize)]
pub struct Subscription {
    pub plan: String,
    pub status: String,
    pub expires_at: Option<String>,
    pub device_limit: i32,
}

#[derive(Debug, Clone, PartialEq, uniffi::Record, Deserialize)]
pub struct Device {
    pub id: String,
    pub name: String,
    pub platform: String,
    pub last_seen_at: String,
    pub created_at: String,
}

#[derive(Debug, Clone, PartialEq, uniffi::Record, Deserialize)]
pub struct DeviceList {
    pub devices: Vec<Device>,
    pub device_limit: i32,
}

#[derive(Debug, Clone, PartialEq, uniffi::Record, Deserialize)]
pub struct SelectBestResponse {
    pub node_id: String,
    pub reason: String,
}

/// Sum type discriminated by the contract's `kind` field (internally tagged),
/// mirroring Swift `Node`. UniFFI renders this as a Kotlin sealed class.
#[derive(Debug, Clone, PartialEq, uniffi::Enum, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Node {
    Shared {
        id: String,
        region: String,
        city: String,
        latency_ms: i32,
        load: f64,
        tier: String,
    },
    Dedicated {
        id: String,
        region: String,
        city: String,
        label: String,
        static_ip: String,
        expires_at: String,
        latency_ms: i32,
        load: f64,
    },
}

/// Wrapper for `node-list.json` ({ "nodes": [...] }).
#[derive(Debug, Deserialize)]
pub struct NodeList {
    pub nodes: Vec<Node>,
}
