package com.dini.dini_flutter

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import org.json.JSONObject

class DiniWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }
    companion object {
        private const val PREFS = "dini_widget"
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = android.content.ComponentName(context, DiniWidgetProvider::class.java)
            manager.getAppWidgetIds(component).forEach { update(context, manager, it) }
        }
        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("snapshot", null)
            val json = raw?.let { runCatching { JSONObject(it) }.getOrNull() }
            val views = RemoteViews(context.packageName, R.layout.widget_dini)
            views.setTextViewText(R.id.widget_next_name, json?.optString("nextPrayer", "Sıradaki namaz") ?: "Sıradaki namaz")
            views.setTextViewText(R.id.widget_next_time, json?.optString("nextPrayerTime", "—")?.replace("T", " ") ?: "—")
            views.setTextViewText(R.id.widget_prayer_list, listOf("fajr", "dhuhr", "asr", "maghrib", "isha").joinToString("  ·  ") { key -> key.replaceFirstChar { it.uppercase() } + " " + (json?.optString(key, "—")?.replace("T", " ") ?: "—") })
            manager.updateAppWidget(id, views)
        }
    }
}
