package com.minivpn.app.ui.account

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.DeviceUnknown
import androidx.compose.material.icons.filled.Laptop
import androidx.compose.material.icons.filled.Smartphone
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.minivpn.app.ui.model.DeviceUi
import com.minivpn.app.ui.model.SampleData
import com.minivpn.app.ui.model.SubscriptionUi
import com.minivpn.app.ui.theme.StatusColors

/**
 * 7.5 Account (Material 3). Subscription (read-only) + device list with
 * swipe-to-revoke (current device excluded, Q-02) + log out. Phase 3 static
 * data + local revoke; Phase 4 wires the backend.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountScreen(onLogout: () -> Unit) {
    val devices = remember { mutableStateListOf(*SampleData.devices.toTypedArray()) }
    Scaffold(
        topBar = { CenterAlignedTopAppBar(title = { Text("Account") }) },
    ) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("Subscription", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            SubscriptionCard(SampleData.subscription)

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Devices", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(
                    "${devices.size} of ${SampleData.deviceLimit}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            devices.forEach { device ->
                DeviceRow(device, onRevoke = { devices.remove(device) })
            }

            TextButton(
                onClick = onLogout,
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            ) {
                Text("Log out", color = MaterialTheme.colorScheme.error)
            }
        }
    }
}

@Composable
private fun SubscriptionCard(sub: SubscriptionUi) {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            InfoRow("Plan") { Text(sub.plan, style = MaterialTheme.typography.bodyMedium) }
            InfoRow("Status") { StatusChip(sub.status) }
            InfoRow("Expires") { Text(sub.expires, style = MaterialTheme.typography.bodyMedium) }
        }
    }
}

@Composable
private fun InfoRow(label: String, trailing: @Composable () -> Unit) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        trailing()
    }
}

@Composable
private fun StatusChip(status: String) {
    val active = status == "active"
    // "active" reads as positive → fixed success green (consistent with the
    // connected state, and stable under dynamic color). Other statuses neutral.
    Surface(
        shape = RoundedCornerShape(8.dp),
        color = if (active) StatusColors.connectedContainer else MaterialTheme.colorScheme.surface,
    ) {
        Text(
            status,
            style = MaterialTheme.typography.labelMedium,
            color = if (active) StatusColors.onConnectedContainer else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DeviceRow(device: DeviceUi, onRevoke: () -> Unit) {
    if (device.isCurrent) {
        // Current device cannot be revoked (Q-02) — no swipe affordance.
        DeviceContent(device)
        return
    }
    val state = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart) { onRevoke(); true } else false
        },
    )
    SwipeToDismissBox(
        state = state,
        enableDismissFromStartToEnd = false,
        backgroundContent = {
            Box(
                modifier = Modifier.fillMaxSize()
                    .background(MaterialTheme.colorScheme.errorContainer)
                    .padding(horizontal = 20.dp),
                contentAlignment = Alignment.CenterEnd,
            ) {
                Icon(Icons.Filled.Delete, contentDescription = "解绑", tint = MaterialTheme.colorScheme.onErrorContainer)
            }
        },
    ) {
        DeviceContent(device)
    }
}

@Composable
private fun DeviceContent(device: DeviceUi) {
    Surface(color = MaterialTheme.colorScheme.surface, modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(deviceIcon(device.platform), contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
            Column {
                Text(device.name, style = MaterialTheme.typography.bodyLarge)
                Text(
                    if (device.isCurrent) "${device.platform} · this device" else device.platform,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

private fun deviceIcon(platform: String): ImageVector = when (platform) {
    "ios", "android" -> Icons.Filled.Smartphone
    "macos", "windows", "linux" -> Icons.Filled.Laptop
    else -> Icons.Filled.DeviceUnknown
}
