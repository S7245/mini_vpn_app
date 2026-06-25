package com.minivpn.app.control

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import uniffi.minivpn_core.ConnectionState
import uniffi.minivpn_core.ControlCommand
import uniffi.minivpn_core.ControlEvent
import uniffi.minivpn_core.ControlService
import uniffi.minivpn_core.EventObserver

/** UI-facing snapshot of the rust-core ① ControlService event stream. */
data class ConnectionUiState(
    val state: ConnectionState = ConnectionState.DISCONNECTED,
    val upBps: Long = 0,
    val downBps: Long = 0,
    val upBytes: Long = 0,
    val downBytes: Long = 0,
    val lastLog: String = "",
)

/**
 * Thin Kotlin VM over the rust-core `ControlService` (per ADR-C "中核": the
 * state machine lives in Rust; this wraps its event stream into a [StateFlow]
 * that Compose collects). `send(Connect/Disconnect)` drives it over FFI.
 *
 * THREADING (FINDINGS §8): `EventObserver.onEvent` is invoked on a Rust thread
 * (the ticker thread), so we hop to `Dispatchers.Main` before mutating the
 * StateFlow the UI observes — the Kotlin analogue of the Swift MainActor hop.
 */
class ConnectionViewModel : ViewModel() {
    private val _ui = MutableStateFlow(ConnectionUiState())
    val ui: StateFlow<ConnectionUiState> = _ui.asStateFlow()

    private val observer = object : EventObserver {
        override fun onEvent(event: ControlEvent) {
            // Callback arrives off a Rust thread → hop to Main, then apply.
            viewModelScope.launch(Dispatchers.Main) { apply(event) }
        }
    }

    private val service = ControlService(observer, liveTicker = true)

    private fun apply(event: ControlEvent) {
        // Tag "MiniVPN" so a headless `adb logcat` run can verify the live
        // rust-core → FFI → Main path (the events originate in Rust).
        Log.i("MiniVPN", "[${Thread.currentThread().name}] $event")
        _ui.value = when (event) {
            is ControlEvent.State -> _ui.value.copy(state = event.state)
            is ControlEvent.Stats -> _ui.value.copy(
                upBps = event.upBps,
                downBps = event.downBps,
                upBytes = event.upBytes,
                downBytes = event.downBytes,
            )
            is ControlEvent.Log -> _ui.value.copy(lastLog = "${event.level}: ${event.message}")
            is ControlEvent.Error -> _ui.value.copy(lastLog = "error: ${event.detail}")
        }
    }

    fun connect() = service.send(ControlCommand.Connect("placeholder-node"))

    // rust-core `stop()` joins the ticker thread (up to ~1s mid-sleep), so keep
    // it off the main thread. Resulting Disconnected/Log events still flow back
    // through the observer's Main hop.
    fun disconnect() {
        viewModelScope.launch(Dispatchers.IO) { service.send(ControlCommand.Disconnect) }
    }

    override fun onCleared() {
        super.onCleared()
        // Retire the Rust ticker thread, then free the FFI handle.
        service.send(ControlCommand.Disconnect)
        service.close()
    }
}
