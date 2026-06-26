package com.minivpn.app.vm

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import uniffi.minivpn_core.BackendServiceInterface
import uniffi.minivpn_core.Device
import uniffi.minivpn_core.Subscription

data class AccountUiState(
    val subscription: Subscription? = null,
    val devices: List<Device> = emptyList(),
    val deviceLimit: Int = 0,
    val errorMessage: String? = null,
)

/**
 * A4 Account (mirrors Swift AccountViewModel). Subscription (read-only) + device
 * list + unbind. The current device is never revocable (Q-02). Thin Kotlin VM
 * over the ② BackendService.
 */
class AccountViewModel(private val backend: BackendServiceInterface) : ViewModel() {
    private val _ui = MutableStateFlow(AccountUiState())
    val ui: StateFlow<AccountUiState> = _ui.asStateFlow()

    /**
     * The device this app runs on — NOT revocable (Q-02). Set by the app once a
     * real backend identifies the current device; null in mock until then.
     */
    var currentDeviceId: String? = null

    fun load() {
        viewModelScope.launch {
            try {
                val sub = backend.getSubscription()
                val list = backend.listDevices()
                _ui.value = AccountUiState(
                    subscription = sub,
                    devices = list.devices,
                    deviceLimit = list.deviceLimit,
                    errorMessage = null,
                )
            } catch (e: Exception) {
                _ui.value = _ui.value.copy(errorMessage = "$e")
            }
        }
    }

    /** Whether a device may be unbound — the current device may not (Q-02). */
    fun canRevoke(id: String): Boolean = id != currentDeviceId

    /** FR-12: unbind a device; removes it locally on success. */
    fun revoke(id: String) {
        if (!canRevoke(id)) return
        viewModelScope.launch {
            try {
                backend.revokeDevice(id)
                _ui.value = _ui.value.copy(
                    devices = _ui.value.devices.filterNot { it.id == id },
                    errorMessage = null,
                )
            } catch (e: Exception) {
                _ui.value = _ui.value.copy(errorMessage = "$e")
            }
        }
    }
}
