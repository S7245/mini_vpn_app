package com.spike.ffi

import android.app.Activity
import android.os.Bundle
import android.util.Log
import android.widget.TextView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import uniffi.minivpn_ffi.ControlEvent
import uniffi.minivpn_ffi.ControlService
import uniffi.minivpn_ffi.EventObserver

// THROWAWAY SPIKE (Phase 4c): the UniFFI Kotlin consumer running ON Android,
// loading the cross-compiled arm64 .so via JNA. Logs to logcat tag "SPIKE" so a
// headless emulator run can be verified with `adb logcat`.

private const val TAG = "SPIKE"

class Obs(private val sink: (String) -> Unit) : EventObserver {
    override fun onEvent(event: ControlEvent) {
        sink("[${Thread.currentThread().name}] $event")
    }
}

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val tv = TextView(this)
        setContentView(tv)
        val sb = StringBuilder()
        fun emit(m: String) {
            Log.i(TAG, m)
            runOnUiThread { sb.appendLine(m); tv.text = sb.toString() }
        }

        val svc = ControlService(Obs { emit(it) })
        CoroutineScope(Dispatchers.Main).launch {
            emit("== connect (callback stream) ==")
            svc.connect()
            delay(2500)
            svc.disconnect()
            emit("== await ping() (tokio async over FFI) ==")
            emit("ping -> ${svc.ping()}")
            emit("== await streamTicks(3u) ==")
            svc.streamTicks(3u)
            emit("== done ==")
        }
    }
}
