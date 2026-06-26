package com.minivpn.app.ui.theme

import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color

// Brand seed palette (the fallback when dynamic color is unavailable, i.e.
// < API 31). On API 31+ Material You overrides primary/secondary/tertiary with
// the system wallpaper extraction; these only show on older devices.
private val BrandBlue = Color(0xFF1D6FB8)
private val BrandBlueDark = Color(0xFFA6C8FF)

val LightColors = lightColorScheme(
    primary = BrandBlue,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFD4E3F7),
    onPrimaryContainer = Color(0xFF0C447C),
)

val DarkColors = darkColorScheme(
    primary = BrandBlueDark,
    onPrimary = Color(0xFF042C53),
    primaryContainer = Color(0xFF0C447C),
    onPrimaryContainer = Color(0xFFD4E3F7),
)

// Connection-status semantics. Material 3 has no green/"connected" role, so we
// define fixed status colors that read correctly in both light and dark — the
// connected state should not drift with dynamic color (UX clarity). connecting
// and error reuse the theme's tertiary/error containers.
val ConnectedContainerLight = Color(0xFFB6E8C9)
val OnConnectedContainerLight = Color(0xFF0B5132)
val ConnectedContainerDark = Color(0xFF0B5132)
val OnConnectedContainerDark = Color(0xFFB6E8C9)
