package com.minivpn.app

import android.app.Application
import com.minivpn.app.di.AppContainer

/**
 * Holds the app-lifetime [AppContainer] (rust-core ② BackendService +
 * SessionStore). Anchoring it here — not in the Activity — keeps a single
 * BackendService for the whole process, so it survives config changes instead
 * of leaking a fresh native handle on every rotation.
 */
class MiniVpnApplication : Application() {
    val container: AppContainer by lazy { AppContainer(this) }
}
