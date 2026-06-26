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
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ElevatedCard
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.minivpn.app.di.LocalAppContainer
import com.minivpn.app.ui.theme.StatusColors
import com.minivpn.app.vm.AccountViewModel
import uniffi.minivpn_core.Device
import uniffi.minivpn_core.Subscription
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * 7.5 Account (Material 3) over the real AccountViewModel. Subscription
 * (read-only) + device list with swipe-to-revoke (current device excluded,
 * Q-02) + log out.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountScreen(
    onLogout: () -> Unit,
    vm: AccountViewModel = viewModel(factory = LocalAppContainer.current.factory),
) {
    val ui by vm.ui.collectAsState()
    LaunchedEffect(Unit) { vm.load() }
    Scaffold(
        topBar = { CenterAlignedTopAppBar(title = { Text("Account") }) },
    ) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("Subscription", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            SubscriptionCard(ui.subscription)

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Devices", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(
                    "${ui.devices.size} of ${ui.deviceLimit}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            ui.devices.forEach { device ->
                DeviceRow(
                    device = device,
                    isCurrent = device.id == vm.currentDeviceId,
                    canRevoke = vm.canRevoke(device.id),
                    onRevoke = { vm.revoke(device.id) },
                )
            }

            TextButton(onClick = onLogout, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                Text("Log out", color = MaterialTheme.colorScheme.error)
            }
        }
    }
}

@Composable
private fun SubscriptionCard(sub: Subscription?) {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            if (sub == null) {
                Text("—", color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else {
                InfoRow("Plan") { Text(sub.plan, style = MaterialTheme.typography.bodyMedium) }
                InfoRow("Status") { StatusChip(sub.status) }
                InfoRow("Expires") { Text(formatDate(sub.expiresAt), style = MaterialTheme.typography.bodyMedium) }
            }
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
private fun DeviceRow(device: Device, isCurrent: Boolean, canRevoke: Boolean, onRevoke: () -> Unit) {
    if (!canRevoke) {
        // Current device cannot be revoked (Q-02) — no swipe affordance.
        DeviceContent(device, isCurrent)
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
        DeviceContent(device, isCurrent)
    }
}

@Composable
private fun DeviceContent(device: Device, isCurrent: Boolean) {
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
                    if (isCurrent) "${device.platform} · this device" else device.platform,
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

private val DATE_FMT = DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.US)

private fun formatDate(iso: String?): String {
    if (iso == null) return "—"
    return runCatching {
        Instant.parse(iso).atZone(ZoneId.systemDefault()).format(DATE_FMT)
    }.getOrDefault(iso)
}
