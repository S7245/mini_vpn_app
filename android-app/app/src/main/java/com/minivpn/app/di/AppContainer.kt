package com.minivpn.app.di

import android.content.Context
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.minivpn.app.control.ConnectionViewModel
import com.minivpn.app.data.PrefsSessionStore
import com.minivpn.app.data.SessionStore
import com.minivpn.app.vm.AccountViewModel
import com.minivpn.app.vm.AuthViewModel
import com.minivpn.app.vm.NodeListViewModel
import uniffi.minivpn_core.BackendService

/**
 * Minimal manual DI. Holds the app-lifetime singletons: the rust-core ②
 * BackendService (mock now, real later — one swap point) and the SessionStore.
 * The [factory] builds the thin Kotlin VMs against these. Phase 4's "中核".
 */
class AppContainer(context: Context) {
    val backend: BackendService = BackendService()
    val sessionStore: SessionStore = PrefsSessionStore(context)
    val factory: ViewModelProvider.Factory = AppViewModelFactory(this)
}

private class AppViewModelFactory(private val c: AppContainer) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T = when {
        modelClass.isAssignableFrom(AuthViewModel::class.java) -> AuthViewModel(c.backend, c.sessionStore)
        modelClass.isAssignableFrom(NodeListViewModel::class.java) -> NodeListViewModel(c.backend)
        modelClass.isAssignableFrom(AccountViewModel::class.java) -> AccountViewModel(c.backend)
        modelClass.isAssignableFrom(ConnectionViewModel::class.java) -> ConnectionViewModel()
        else -> throw IllegalArgumentException("Unknown ViewModel: ${modelClass.name}")
    } as T
}

/** Provides the [AppContainer] to the composable tree (set in MainActivity). */
val LocalAppContainer = staticCompositionLocalOf<AppContainer> {
    error("AppContainer not provided")
}
