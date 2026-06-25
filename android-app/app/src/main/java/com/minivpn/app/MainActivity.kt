package com.minivpn.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import com.minivpn.app.ui.MiniVpnApp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            // Material 3 theming (Phase 3 will flesh out the palette). The
            // placeholder UI below proves the rust-core FFI link is live.
            MaterialTheme {
                Surface { MiniVpnApp() }
            }
        }
    }
}
