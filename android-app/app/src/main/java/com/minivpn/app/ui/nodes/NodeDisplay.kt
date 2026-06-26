package com.minivpn.app.ui.nodes

import uniffi.minivpn_core.Node
import java.time.Instant
import kotlin.math.roundToInt

// Display helpers over the rust-core Node sum type (mirrors the computed
// properties in Swift's NodeListView). java.time requires core library
// desugaring (enabled in app/build.gradle.kts) given minSdk 24.

val Node.id: String
    get() = when (this) {
        is Node.Shared -> id
        is Node.Dedicated -> id
    }

val Node.region: String
    get() = when (this) {
        is Node.Shared -> region
        is Node.Dedicated -> region
    }

val Node.city: String
    get() = when (this) {
        is Node.Shared -> city
        is Node.Dedicated -> city
    }

val Node.latencyMs: Int
    get() = when (this) {
        is Node.Shared -> latencyMs
        is Node.Dedicated -> latencyMs
    }

val Node.isDedicated: Boolean
    get() = this is Node.Dedicated

/** Load percent for shared nodes; null for dedicated. */
val Node.loadPercent: Int?
    get() = when (this) {
        is Node.Shared -> (load * 100).roundToInt()
        is Node.Dedicated -> null
    }

val Node.subtitle: String
    get() = when (this) {
        is Node.Shared -> "Shared · $tier"
        is Node.Dedicated -> "$staticIp · $label"
    }

/** Expired dedicated nodes are greyed + non-selectable (Q-01). */
fun Node.isExpired(): Boolean = when (this) {
    is Node.Shared -> false
    is Node.Dedicated -> runCatching { Instant.parse(expiresAt) < Instant.now() }.getOrDefault(false)
}
