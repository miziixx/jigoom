package com.example.memo_app

import android.content.Context
import android.graphics.Color
import org.json.JSONArray
import org.json.JSONObject

object WidgetDataHelper {

    // ── Color helpers ──────────────────────────────────────────────

    fun readColor(prefs: android.content.SharedPreferences, key: String, default: Int): Int {
        return try {
            when (val v = prefs.all[key]) {
                is Int  -> v
                is Long -> v.toInt()
                else    -> default
            }
        } catch (_: Exception) { default }
    }

    data class WidgetColors(
        val bg: Int,
        val text: Int,
        val dim: Int,
        val border: Int,
        val teal: Int,
        val mint: Int,
        val accent: Int,
    )

    fun widgetColors(context: Context): WidgetColors {
        val p = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        return WidgetColors(
            bg     = readColor(p, "widget_bg",     Color.parseColor("#EDF2ED")),
            text   = readColor(p, "widget_text",   Color.parseColor("#556B2F")),
            dim    = readColor(p, "widget_dim",     Color.parseColor("#7A8F5A")),
            border = readColor(p, "widget_border", Color.parseColor("#B0C4B0")),
            teal   = readColor(p, "widget_teal",   Color.parseColor("#527A22")),
            mint   = readColor(p, "widget_mint",   Color.parseColor("#556B2F")),
            accent = readColor(p, "widget_accent", Color.parseColor("#B8882A")),
        )
    }

    // ── Flutter SharedPreferences reader ───────────────────────────

    private fun flutterPrefs(context: Context) =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    fun readMemos(context: Context): JSONArray {
        val raw = flutterPrefs(context).getString("flutter.memos_v1", "[]") ?: "[]"
        return try { JSONArray(raw) } catch (_: Exception) { JSONArray() }
    }

    fun readFolders(context: Context): JSONArray {
        val raw = flutterPrefs(context).getString("flutter.folders_v1", "[]") ?: "[]"
        return try { JSONArray(raw) } catch (_: Exception) { JSONArray() }
    }

    // ── Memo helpers ──────────────────────────────────────────────

    /** Returns the first non-empty content line, stripped of tag/checklist prefixes. */
    fun memoFirstLine(memo: JSONObject): String {
        val content = memo.optString("content", "")
        return content.split("\n")
            .firstOrNull { it.trim().isNotEmpty() }
            ?.replace(Regex("^- \\[[ x]] "), "")
            ?.replace(Regex("^• "), "")
            ?.replace(Regex("#[^ ]+"), "")
            ?.trim() ?: ""
    }

    /** Returns "YYYY-MM-DD" from the memo's createdAt ISO string. */
    fun memoDateKey(memo: JSONObject): String {
        val iso = memo.optString("createdAt", "")
        return if (iso.length >= 10) iso.substring(0, 10) else ""
    }

    /** "HH:MM" from createdAt. */
    fun memoTimeStr(memo: JSONObject): String {
        val iso = memo.optString("createdAt", "")
        return if (iso.length >= 16) iso.substring(11, 16) else "--:--"
    }

    /** Returns all folder IDs that are descendants (including self) of a given root folder. */
    fun allDescendantIds(folders: JSONArray, rootId: String): Set<String> {
        val result = mutableSetOf(rootId)
        var changed = true
        while (changed) {
            changed = false
            for (i in 0 until folders.length()) {
                val f = folders.getJSONObject(i)
                val id = f.optString("id")
                val parent = f.optString("parentId", "")
                if (parent in result && id !in result) {
                    result.add(id)
                    changed = true
                }
            }
        }
        return result
    }
}
