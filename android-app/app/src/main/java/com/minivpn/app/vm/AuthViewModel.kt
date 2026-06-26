package com.minivpn.app.vm

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.minivpn.app.data.SessionStore
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import uniffi.minivpn_core.BackendException
import uniffi.minivpn_core.BackendServiceInterface
import uniffi.minivpn_core.TokenPair

data class AuthUiState(
    val isAuthenticated: Boolean = false,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

/**
 * A1 Auth + session gate (mirrors Swift AuthViewModel). Restores a persisted
 * session on init (Q-03 remember login); login/register persist the returned
 * tokens; logout clears them (best-effort backend logout, local session cleared
 * regardless). Thin Kotlin VM over the rust-core ② BackendService.
 */
class AuthViewModel(
    private val backend: BackendServiceInterface,
    private val store: SessionStore,
) : ViewModel() {
    private val _ui = MutableStateFlow(AuthUiState(isAuthenticated = store.load() != null))
    val ui: StateFlow<AuthUiState> = _ui.asStateFlow()

    fun login(email: String, password: String) =
        authenticate { backend.login(email, password) }

    fun register(email: String, password: String) =
        authenticate { backend.register(email, password) }

    fun logout() {
        viewModelScope.launch {
            try {
                backend.logout()
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                // best-effort; local session is cleared regardless
            }
            store.clear()
            _ui.value = _ui.value.copy(isAuthenticated = false, errorMessage = null)
        }
    }

    private fun authenticate(op: suspend () -> TokenPair) {
        viewModelScope.launch {
            _ui.value = _ui.value.copy(isLoading = true, errorMessage = null)
            try {
                val tokens = op()
                store.save(tokens)
                _ui.value = _ui.value.copy(isAuthenticated = true, isLoading = false)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _ui.value = _ui.value.copy(
                    isAuthenticated = false,
                    isLoading = false,
                    errorMessage = message(e),
                )
            }
        }
    }

    private fun message(e: Throwable): String = when (e) {
        is BackendException.Unauthorized -> "邮箱或密码错误"
        is BackendException.Transport -> "网络异常，请重试"
        else -> "登录失败，请重试"
    }
}
