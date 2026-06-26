package com.minivpn.app.ui.connect

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Power
import androidx.compose.material.icons.filled.Public
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.minivpn.app.control.ConnectionViewModel
import com.minivpn.app.ui.theme.StatusColors
import uniffi.minivpn_core.ConnectionState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConnectScreen(vm: ConnectionViewModel = viewModel()) {
    val ui by vm.ui.collectAsState()
    Scaffold(
        topBar = { CenterAlignedTopAppBar(title = { Text("MiniVPN") }) },
    ) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            val container = statusContainer(ui.state)
            val content = statusContent(ui.state)

            Surface(
                color = container,
                shape = RoundedCornerShape(28.dp),
                modifier = Modifier.size(120.dp).clickable(enabled = ui.state != ConnectionState.CONNECTING) {
                    if (ui.state == ConnectionState.CONNECTED) vm.disconnect() else vm.connect()
                },
            ) {
                Box(contentAlignment = Alignment.Center) {
                    if (ui.state == ConnectionState.CONNECTING) {
                        CircularProgressIndicator(color = content)
                    } else {
                        Icon(
                            Icons.Filled.Power,
                            contentDescription = if (ui.state == ConnectionState.CONNECTED) "Disconnect" else "Connect",
                            tint = content,
                            modifier = Modifier.size(52.dp),
                        )
                    }
                }
            }

            Text(
                statusLabel(ui.state),
                style = MaterialTheme.typography.titleLarge,
                color = content,
            )

            NodeCard()

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MetricCard("Download", Icons.Filled.ArrowDownward, ui.downBps, ui.downBytes, Modifier.weight(1f))
                MetricCard("Upload", Icons.Filled.ArrowUpward, ui.upBps, ui.upBytes, Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun NodeCard() {
    // Phase 3: static "Auto-select". Phase 4 wires the selected node (FR-09).
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.elevatedCardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant,
        ),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(Icons.Filled.Public, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Column(modifier = Modifier.weight(1f)) {
                Text("Auto-select", style = MaterialTheme.typography.bodyLarge)
                Text(
                    "lowest latency",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Icon(
                Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun MetricCard(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    bps: Long,
    bytes: Long,
    modifier: Modifier = Modifier,
) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(12.dp),
        modifier = modifier,
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(icon, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(title, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text(
                formatRate(bps),
                style = MaterialTheme.typography.titleMedium,
                fontFamily = FontFamily.Monospace,
                fontSize = 18.sp,
            )
            Text(
                "${formatBytes(bytes)} total",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable private fun statusContainer(s: ConnectionState): Color = when (s) {
    ConnectionState.CONNECTED -> StatusColors.connectedContainer
    ConnectionState.CONNECTING -> MaterialTheme.colorScheme.tertiaryContainer
    ConnectionState.ERROR -> MaterialTheme.colorScheme.errorContainer
    ConnectionState.DISCONNECTED -> MaterialTheme.colorScheme.surfaceVariant
}

@Composable private fun statusContent(s: ConnectionState): Color = when (s) {
    ConnectionState.CONNECTED -> StatusColors.onConnectedContainer
    ConnectionState.CONNECTING -> MaterialTheme.colorScheme.onTertiaryContainer
    ConnectionState.ERROR -> MaterialTheme.colorScheme.onErrorContainer
    ConnectionState.DISCONNECTED -> MaterialTheme.colorScheme.onSurfaceVariant
}

private fun statusLabel(s: ConnectionState): String = when (s) {
    ConnectionState.DISCONNECTED -> "未连接"
    ConnectionState.CONNECTING -> "连接中…"
    ConnectionState.CONNECTED -> "已连接"
    ConnectionState.ERROR -> "连接出错"
}

private fun formatRate(bps: Long): String = when {
    bps >= 1_000_000 -> "%.1f Mb/s".format(bps / 1_000_000.0)
    bps >= 1_000 -> "${bps / 1_000} kb/s"
    else -> "$bps b/s"
}

private fun formatBytes(bytes: Long): String = when {
    bytes >= 1_000_000 -> "%.1f MB".format(bytes / 1_000_000.0)
    bytes >= 1_000 -> "%.1f KB".format(bytes / 1_000.0)
    else -> "$bytes B"
}
