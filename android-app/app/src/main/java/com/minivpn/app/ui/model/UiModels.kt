package com.minivpn.app.ui.model

/**
 * Lightweight UI models for the Material 3 screens. Phase 3 renders these from
 * static sample data so the design is real and navigable; Phase 4 (rust-core
 * slice ② BackendService + thin VMs) will populate them from the live contract
 * models instead — the composables stay unchanged.
 */
data class NodeUi(
    val id: String,
    val region: String,
    val city: String,
    val latencyMs: Int,
    val dedicated: Boolean,
    val subtitle: String,
    val loadPercent: Int? = null, // shared nodes only
    val expired: Boolean = false, // expired dedicated → greyed, non-selectable (Q-01)
)

data class SubscriptionUi(
    val plan: String,
    val status: String,
    val expires: String,
)

data class DeviceUi(
    val id: String,
    val name: String,
    val platform: String,
    val isCurrent: Boolean, // current device cannot be revoked (Q-02)
)

/** Static sample data — Phase 3 only. Removed when Phase 4 wires the backend. */
object SampleData {
    val nodes = listOf(
        NodeUi("us-ny", "US", "New York", 24, dedicated = false, subtitle = "Shared · pro", loadPercent = 38),
        NodeUi("uk-ldn", "UK", "London", 29, dedicated = false, subtitle = "Shared · standard", loadPercent = 61),
        NodeUi("de-fra", "DE", "Frankfurt", 31, dedicated = true, subtitle = "10.0.0.2 · work"),
        NodeUi("jp-tyo", "JP", "Tokyo", 88, dedicated = true, subtitle = "10.0.0.9 · legacy", expired = true),
    )

    val subscription = SubscriptionUi(plan = "Pro", status = "active", expires = "Jul 12, 2026")

    val devices = listOf(
        DeviceUi("d1", "iPhone 15", "ios", isCurrent = false),
        DeviceUi("d2", "Pixel 8", "android", isCurrent = true),
        DeviceUi("d3", "MacBook Air", "macos", isCurrent = false),
    )
    const val deviceLimit = 5
}
