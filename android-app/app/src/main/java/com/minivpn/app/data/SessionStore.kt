package com.minivpn.app.data

import android.content.Context
import uniffi.minivpn_core.TokenPair

/**
 * Persists the session token pair (Q-03: remember login). Mirrors Swift
 * `SessionStore`. Synchronous so the gate can restore on init without a flash.
 */
interface SessionStore {
    fun save(tokens: TokenPair)
    fun load(): TokenPair?
    fun clear()
}

/**
 * Mock-first impl: plaintext SharedPreferences (synchronous). The real impl
 * swaps to EncryptedSharedPreferences behind this same interface — same
 * synchronous API, just encrypted at rest (Q-A4).
 */
class PrefsSessionStore(context: Context) : SessionStore {
    private val prefs = context.applicationContext
        .getSharedPreferences("minivpn.session", Context.MODE_PRIVATE)

    override fun save(tokens: TokenPair) {
        prefs.edit()
            .putString(ACCESS, tokens.accessToken)
            .putString(REFRESH, tokens.refreshToken)
            .putString(TYPE, tokens.tokenType)
            .putInt(EXPIRES_IN, tokens.expiresIn)
            .apply()
    }

    override fun load(): TokenPair? {
        val access = prefs.getString(ACCESS, null) ?: return null
        return TokenPair(
            accessToken = access,
            refreshToken = prefs.getString(REFRESH, "") ?: "",
            tokenType = prefs.getString(TYPE, "Bearer") ?: "Bearer",
            expiresIn = prefs.getInt(EXPIRES_IN, 0),
        )
    }

    override fun clear() {
        prefs.edit().clear().apply()
    }

    private companion object {
        const val ACCESS = "access_token"
        const val REFRESH = "refresh_token"
        const val TYPE = "token_type"
        const val EXPIRES_IN = "expires_in"
    }
}
