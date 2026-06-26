package com.minivpn.app.vm

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import uniffi.minivpn_core.BackendServiceInterface
import uniffi.minivpn_core.Node

data class NodesUiState(
    val nodes: List<Node> = emptyList(),
    val selectedNodeId: String? = null,
    val errorMessage: String? = null,
)

/**
 * A3 Nodes (mirrors Swift NodeListViewModel). Loads shared/dedicated nodes from
 * the ② BackendService, supports manual selection + auto-select best. The
 * selection is shared with Connect (FR-09): both screens resolve the SAME VM
 * instance from the Activity ViewModelStore.
 */
class NodeListViewModel(private val backend: BackendServiceInterface) : ViewModel() {
    private val _ui = MutableStateFlow(NodesUiState())
    val ui: StateFlow<NodesUiState> = _ui.asStateFlow()

    fun load() {
        viewModelScope.launch {
            try {
                _ui.value = _ui.value.copy(nodes = backend.listNodes(), errorMessage = null)
            } catch (e: Exception) {
                _ui.value = _ui.value.copy(errorMessage = "$e")
            }
        }
    }

    /** Manual pick (expired nodes are filtered by the screen). */
    fun select(id: String) {
        _ui.value = _ui.value.copy(selectedNodeId = id)
    }

    /** Auto-select best — clears manual pick in favour of the backend's choice. */
    fun selectBest() {
        viewModelScope.launch {
            try {
                _ui.value = _ui.value.copy(selectedNodeId = backend.selectBest().nodeId, errorMessage = null)
            } catch (e: Exception) {
                _ui.value = _ui.value.copy(errorMessage = "$e")
            }
        }
    }
}
