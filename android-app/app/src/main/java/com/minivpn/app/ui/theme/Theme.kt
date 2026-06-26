package com.minivpn.app.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

/**
 * Material 3 theme. Per Phase 3 decision: Dynamic Color (Material You) on
 * API 31+ — primary/secondary/tertiary extracted from the system wallpaper —
 * with the brand seed palette as the < API 31 fallback. Light/dark both
 * supported (follows the system setting).
 */
@Composable
fun MiniVpnTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit,
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColors
        else -> LightColors
    }
    MaterialTheme(colorScheme = colorScheme, content = content)
}

/** Connection-status container/content colors, dark-mode aware. */
object StatusColors {
    val connectedContainer
        @Composable get() = if (isSystemInDarkTheme()) ConnectedContainerDark else ConnectedContainerLight
    val onConnectedContainer
        @Composable get() = if (isSystemInDarkTheme()) OnConnectedContainerDark else OnConnectedContainerLight
}
