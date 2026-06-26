package com.minivpn.app.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Power
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import com.minivpn.app.ui.account.AccountScreen
import com.minivpn.app.ui.auth.LoginScreen
import com.minivpn.app.ui.auth.RegisterScreen
import com.minivpn.app.ui.connect.ConnectScreen
import com.minivpn.app.ui.nodes.NodesScreen

/**
 * Session gate. A local bool stands in for real auth (Phase 4, rust-core slice
 * ②). Logged out → Login/Register flow; logged in → the Material 3 3-tab shell.
 */
@Composable
fun MiniVpnApp() {
    var loggedIn by rememberSaveable { mutableStateOf(false) }
    if (!loggedIn) {
        AuthFlow(onAuthenticated = { loggedIn = true })
    } else {
        MainScaffold(onLogout = { loggedIn = false })
    }
}

@Composable
private fun AuthFlow(onAuthenticated: () -> Unit) {
    var showRegister by rememberSaveable { mutableStateOf(false) }
    if (showRegister) {
        RegisterScreen(onBack = { showRegister = false }, onRegistered = onAuthenticated)
    } else {
        LoginScreen(onLogin = onAuthenticated, onRegister = { showRegister = true })
    }
}

private enum class Tab(val label: String, val icon: ImageVector) {
    Connect("Connect", Icons.Filled.Power),
    Nodes("Nodes", Icons.AutoMirrored.Filled.List),
    Account("Account", Icons.Filled.Person),
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
                        icon = { Icon(t.icon, contentDescription = t.label) },
                        label = { Text(t.label) },
                    )
                }
            }
        },
    ) { innerPadding ->
        // Each screen owns its TopAppBar (which handles the status-bar inset), so
        // only reserve the bottom-nav space here to avoid doubling the top inset.
        Box(modifier = Modifier.fillMaxSize().padding(bottom = innerPadding.calculateBottomPadding())) {
            when (Tab.entries[tab]) {
                Tab.Connect -> ConnectScreen()
                Tab.Nodes -> NodesScreen()
                Tab.Account -> AccountScreen(onLogout = onLogout)
            }
        }
    }
}
