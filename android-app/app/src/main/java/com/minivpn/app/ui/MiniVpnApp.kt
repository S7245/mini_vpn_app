package com.minivpn.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.minivpn.app.control.ConnectionViewModel
import uniffi.minivpn_core.ConnectionState

/**
 * Session gate (Phase 2 placeholder). A local bool stands in for real auth —
 * that arrives in Phase 4 as rust-core slice ②. Logged out → Auth placeholder;
 * logged in → the 3-tab shell (Connect / Nodes / Account).
 */
@Composable
fun MiniVpnApp() {
    var loggedIn by rememberSaveable { mutableStateOf(false) }
    if (!loggedIn) {
        AuthPlaceholder(onLogin = { loggedIn = true })
    } else {
        MainScaffold(onLogout = { loggedIn = false })
    }
}

@Composable
private fun AuthPlaceholder(onLogin: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("MiniVPN", style = MaterialTheme.typography.headlineMedium)
        Text(
            "Auth placeholder — real login lands in Phase 4 (rust-core slice ②).",
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.padding(top = 8.dp, bottom = 24.dp),
        )
        Button(onClick = onLogin) { Text("Sign in (mock)") }
    }
}

private enum class Tab(val label: String) {
    Connect("Connect"),
    Nodes("Nodes"),
    Account("Account"),
}

@Composable
private fun MainScaffold(onLogout: () -> Unit) {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    Scaffold(
        bottomBar = {
            NavigationBar {
                Tab.entries.forEachIndexed { i, t ->
                    NavigationBarItem(
                        selected = tab == i,
                        onClick = { tab = i },
                        icon = {
                            Icon(
                                when (t) {
                                    Tab.Connect -> Icons.Filled.Lock
                                    Tab.Nodes -> Icons.AutoMirrored.Filled.List
                                    Tab.Account -> Icons.Filled.AccountCircle
                                },
                                contentDescription = t.label,
                            )
                        },
                        label = { Text(t.label) },
                    )
                }
            }
        },
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            when (Tab.entries[tab]) {
                Tab.Connect -> ConnectScreen()
                Tab.Nodes -> PlaceholderScreen("Nodes — Phase 4 (A3)")
                Tab.Account -> AccountPlaceholder(onLogout)
            }
        }
    }
}

/**
 * Connect placeholder — the live proof that the FFI link works: `send(Connect)`
 * drives the rust-core state machine, and the event stream (state + 1 Hz stats)
 * flows back through [ConnectionViewModel] into this UI.
 */
@Composable
private fun ConnectScreen(vm: ConnectionViewModel = viewModel()) {
    val ui by vm.ui.collectAsState()
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Connection", style = MaterialTheme.typography.headlineSmall)
        Text(
            ui.state.name,
            style = MaterialTheme.typography.displaySmall,
            color = when (ui.state) {
                ConnectionState.CONNECTED -> MaterialTheme.colorScheme.primary
                ConnectionState.CONNECTING -> MaterialTheme.colorScheme.tertiary
                ConnectionState.ERROR -> MaterialTheme.colorScheme.error
                ConnectionState.DISCONNECTED -> MaterialTheme.colorScheme.onSurfaceVariant
            },
        )
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Live stats (from rust-core ticker)", style = MaterialTheme.typography.labelLarge)
                Text(
                    "↑ ${ui.upBps} bps   ↓ ${ui.downBps} bps",
                    fontFamily = FontFamily.Monospace,
                )
                Text(
                    "↑ ${ui.upBytes} B   ↓ ${ui.downBytes} B",
                    fontFamily = FontFamily.Monospace,
                )
                Text(
                    ui.lastLog.ifEmpty { "—" },
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Light,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        }
        if (ui.state == ConnectionState.CONNECTED || ui.state == ConnectionState.CONNECTING) {
            OutlinedButton(onClick = vm::disconnect) { Text("Disconnect") }
        } else {
            Button(onClick = vm::connect) { Text("Connect") }
        }
    }
}

@Composable
private fun AccountPlaceholder(onLogout: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Account — Phase 4 (A4)", style = MaterialTheme.typography.titleMedium)
        OutlinedButton(onClick = onLogout, modifier = Modifier.padding(top = 16.dp)) {
            Text("Log out")
        }
    }
}

@Composable
private fun PlaceholderScreen(title: String) {
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium)
    }
}
