package com.minivpn.app.vm

import com.minivpn.app.data.SessionStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.rules.TestWatcher
import org.junit.runner.Description
import uniffi.minivpn_core.BackendException
import uniffi.minivpn_core.BackendServiceInterface
import uniffi.minivpn_core.Device
import uniffi.minivpn_core.DeviceList
import uniffi.minivpn_core.Node
import uniffi.minivpn_core.SelectBestResponse
import uniffi.minivpn_core.Subscription
import uniffi.minivpn_core.TokenPair

/** Sets Dispatchers.Main to a test dispatcher so viewModelScope works in tests. */
@OptIn(ExperimentalCoroutinesApi::class)
class MainDispatcherRule(
    private val dispatcher: TestDispatcher = UnconfinedTestDispatcher(),
) : TestWatcher() {
    override fun starting(description: Description) = Dispatchers.setMain(dispatcher)
    override fun finished(description: Description) = Dispatchers.resetMain()
}

/** In-memory SessionStore for tests. */
class FakeSessionStore(var saved: TokenPair? = null) : SessionStore {
    override fun save(tokens: TokenPair) { saved = tokens }
    override fun load(): TokenPair? = saved
    override fun clear() { saved = null }
}

val SAMPLE_TOKEN = TokenPair("access", "refresh", "Bearer", 3600)

fun sharedNode(id: String, latency: Int = 50, load: Double = 0.3) =
    Node.Shared(id, "US", "NYC", latency, load, "standard")

fun dedicatedNode(id: String, expiresAt: String) =
    Node.Dedicated(id, "DE", "FRA", "label", "10.0.0.1", expiresAt, 30, 0.1)

/**
 * Fake BackendServiceInterface — pure Kotlin, no native lib, so the thin VMs are
 * unit-testable on the host JVM. Configure canned data / errors per test.
 */
open class FakeBackend(
    private val token: TokenPair = SAMPLE_TOKEN,
    private val loginError: BackendException? = null,
    private val nodes: List<Node> = emptyList(),
    private val best: SelectBestResponse = SelectBestResponse("best-node", "lowest latency"),
    private val subscription: Subscription = Subscription("monthly", "active", "2026-07-12T08:00:00Z", 3),
    private val devices: DeviceList = DeviceList(emptyList(), 3),
) : BackendServiceInterface {
    var loggedOut = false
    val revoked = mutableListOf<String>()

    override suspend fun register(email: String, password: String): TokenPair = token
    override suspend fun login(email: String, password: String): TokenPair {
        loginError?.let { throw it }
        return token
    }
    override suspend fun refresh(refreshToken: String): TokenPair = token
    override suspend fun logout() { loggedOut = true }
    override suspend fun changePassword(old: String, new: String) {}
    override suspend fun getSubscription(): Subscription = subscription
    override suspend fun listDevices(): DeviceList = devices
    override suspend fun registerDevice(name: String, platform: String): Device =
        Device("new", name, platform, "", "")
    override suspend fun revokeDevice(id: String) { revoked.add(id) }
    override suspend fun listNodes(): List<Node> = nodes
    override suspend fun selectBest(): SelectBestResponse = best
    override suspend fun purchaseSubscription() { throw BackendException.NotImplemented() }
    override suspend fun purchaseDedicatedIp() { throw BackendException.NotImplemented() }
}
