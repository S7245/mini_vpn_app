package com.minivpn.app.vm

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import uniffi.minivpn_core.SelectBestResponse

@OptIn(ExperimentalCoroutinesApi::class)
class NodeListViewModelTest {
    @get:Rule val mainRule = MainDispatcherRule()

    @Test fun `load populates nodes`() = runTest {
        val vm = NodeListViewModel(FakeBackend(nodes = listOf(sharedNode("a"), dedicatedNode("b", "2999-01-01T00:00:00Z"))))
        vm.load()
        advanceUntilIdle()
        assertEquals(2, vm.ui.value.nodes.size)
    }

    @Test fun `selectBest sets selected node id`() = runTest {
        val vm = NodeListViewModel(FakeBackend(best = SelectBestResponse("node-9", "fast")))
        vm.selectBest()
        advanceUntilIdle()
        assertEquals("node-9", vm.ui.value.selectedNodeId)
    }

    @Test fun `select sets manual pick`() {
        val vm = NodeListViewModel(FakeBackend())
        vm.select("manual-1")
        assertEquals("manual-1", vm.ui.value.selectedNodeId)
    }
}
