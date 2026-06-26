package com.minivpn.app.vm

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import uniffi.minivpn_core.BackendException

@OptIn(ExperimentalCoroutinesApi::class)
class AuthViewModelTest {
    @get:Rule val mainRule = MainDispatcherRule()

    @Test fun `restores persisted session on init`() {
        val vm = AuthViewModel(FakeBackend(), FakeSessionStore(saved = SAMPLE_TOKEN))
        assertTrue(vm.ui.value.isAuthenticated)
    }

    @Test fun `starts unauthenticated with empty store`() {
        val vm = AuthViewModel(FakeBackend(), FakeSessionStore())
        assertFalse(vm.ui.value.isAuthenticated)
    }

    @Test fun `login success authenticates and persists tokens`() = runTest {
        val store = FakeSessionStore()
        val vm = AuthViewModel(FakeBackend(), store)
        vm.login("a@b.com", "pw")
        advanceUntilIdle()
        assertTrue(vm.ui.value.isAuthenticated)
        assertNull(vm.ui.value.errorMessage)
        assertNotNull(store.saved)
    }

    @Test fun `login failure surfaces mapped error and stays unauthenticated`() = runTest {
        val vm = AuthViewModel(FakeBackend(loginError = BackendException.Unauthorized()), FakeSessionStore())
        vm.login("a@b.com", "bad")
        advanceUntilIdle()
        assertFalse(vm.ui.value.isAuthenticated)
        assertEquals("邮箱或密码错误", vm.ui.value.errorMessage)
    }

    @Test fun `logout clears session regardless of backend`() = runTest {
        val store = FakeSessionStore(saved = SAMPLE_TOKEN)
        val backend = FakeBackend()
        val vm = AuthViewModel(backend, store)
        vm.logout()
        advanceUntilIdle()
        assertFalse(vm.ui.value.isAuthenticated)
        assertNull(store.saved)
        assertTrue(backend.loggedOut)
    }
}
