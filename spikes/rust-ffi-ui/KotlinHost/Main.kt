import uniffi.minivpn_ffi.*
import kotlinx.coroutines.*

// THROWAWAY SPIKE (Phase 4): run the UniFFI-generated Kotlin consumer on the
// HOST JVM against the Rust core's darwin dylib. This exercises the exact
// Android consumer mechanics — JNA loading the native lib, the callback
// interface implemented in Kotlin, the sealed-class enum, and async exports as
// `suspend fun`s driven through coroutines — without needing an emulator. Only
// the native target differs on real Android (.so via NDK) — the Kotlin path is
// identical.

class Obs : EventObserver {
    override fun onEvent(event: ControlEvent) {
        println("[${Thread.currentThread().name}] $event")
    }
}

fun main() = runBlocking {
    val svc = ControlService(Obs())

    println("== sync connect (callback stream) ==")
    svc.connect()
    delay(2500)
    svc.disconnect()

    println("== await ping() (tokio async over FFI -> Kotlin suspend) ==")
    println("ping -> ${svc.ping()}")

    println("== await streamTicks(3u) (tokio task -> FFI callback) ==")
    svc.streamTicks(3u)

    println("done")
}
