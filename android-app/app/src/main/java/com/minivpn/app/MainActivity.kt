package com.minivpn.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.Surface
import androidx.compose.runtime.CompositionLocalProvider
import com.minivpn.app.di.LocalAppContainer
import com.minivpn.app.ui.MiniVpnApp
import com.minivpn.app.ui.theme.MiniVpnTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // App-lifetime singleton — survives config changes (no native-handle churn).
        val container = (application as MiniVpnApplication).container
        setContent {
            CompositionLocalProvider(LocalAppContainer provides container) {
                MiniVpnTheme {
                    Surface { MiniVpnApp() }
                }
            }
        }
    }
}
