package com.zia.dashinbox

import android.content.Context

class Prefs(ctx: Context) {
    private val sp = ctx.getSharedPreferences("dashinbox", Context.MODE_PRIVATE)

    var access: String?
        get() = sp.getString("access", null)
        set(v) { sp.edit().putString("access", v).apply() }

    var refresh: String?
        get() = sp.getString("refresh", null)
        set(v) { sp.edit().putString("refresh", v).apply() }

    var email: String?
        get() = sp.getString("email", null)
        set(v) { sp.edit().putString("email", v).apply() }

    fun loggedIn(): Boolean = !refresh.isNullOrEmpty()

    fun clear() { sp.edit().clear().apply() }
}
