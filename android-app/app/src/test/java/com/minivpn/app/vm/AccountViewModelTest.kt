package com.minivpn.app.vm

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import uniffi.minivpn_core.Device
import uniffi.minivpn_core.DeviceList

@OptIn(ExperimentalCoroutinesApi::class)
class AccountViewModelTest {
    @get:Rule val mainRule = MainDispatcherRule()

    private fun device(id: String) = Device(id, "dev-$id", "android", "", "")

    @Test fun `load populates subscription and devices`() = runTest {
        val vm = AccountViewModel(
            FakeBackend(devices = DeviceList(listOf(device("d1"), device("d2")), 5)),
        )
        vm.load()
        advanceUntilIdle()
        assertEquals(2, vm.ui.value.devices.size)
        assertEquals(5, vm.ui.value.deviceLimit)
        assertEquals("active", vm.ui.value.subscription?.status)
    }

    @Test fun `current device is not revocable (Q-02)`() {
        val vm = AccountViewModel(FakeBackend())
        vm.currentDeviceId = "d1"
        assertFalse(vm.canRevoke("d1"))
        assertTrue(vm.canRevoke("d2"))
    }

    @Test fun `revoke removes a non-current device`() = runTest {
        val backend = FakeBackend(devices = DeviceList(listOf(device("d1"), device("d2")), 5))
        val vm = AccountViewModel(backend)
        vm.load(); advanceUntilIdle()
        vm.revoke("d2"); advanceUntilIdle()
        assertEquals(listOf("d1"), vm.ui.value.devices.map { it.id })
        assertEquals(listOf("d2"), backend.revoked)
    }

    @Test fun `revoke is blocked for the current device`() = runTest {
        val backend = FakeBackend(devices = DeviceList(listOf(device("d1")), 5))
        val vm = AccountViewModel(backend)
        vm.currentDeviceId = "d1"
        vm.load(); advanceUntilIdle()
        vm.revoke("d1"); advanceUntilIdle()
        assertEquals(1, vm.ui.value.devices.size)
        assertTrue(backend.revoked.isEmpty())
    }
}
