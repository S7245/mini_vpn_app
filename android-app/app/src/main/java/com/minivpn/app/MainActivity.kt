package com.minivpn.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.Surface
import com.minivpn.app.ui.MiniVpnApp
import com.minivpn.app.ui.theme.MiniVpnTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MiniVpnTheme {
                Surface { MiniVpnApp() }
            }
        }
    }
}
