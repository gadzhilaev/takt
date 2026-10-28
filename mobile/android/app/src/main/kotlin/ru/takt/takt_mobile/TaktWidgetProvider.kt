package ru.takt.takt_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * Home-screen widget (small / medium / large via layout variants).
 * Reads snapshot written by Flutter [home_widget] — never stores auth tokens.
 */
class TaktWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        private const val PREFS = "HomeWidgetPreferences"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val prefs: SharedPreferences =
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val projectName = prefs.getString("project_name", null) ?: "Takt"
            val openCount = prefs.getInt("open_count", 0)
            val snapshot = prefs.getString("snapshot", "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.takt_widget)
            views.setTextViewText(R.id.widget_project, projectName)
            views.setTextViewText(R.id.widget_count, "$openCount незавершённых")

            val lines = StringBuilder()
            if (snapshot.isNotBlank()) {
                try {
                    val json = JSONObject(snapshot)
                    val tasks = json.optJSONArray("tasks")
                    if (tasks != null) {
                        val limit = minOf(tasks.length(), 5)
                        for (i in 0 until limit) {
                            val t = tasks.getJSONObject(i)
                            val title = t.optString("title")
                            val prio = t.optString("priority")
                            val mark = when (prio) {
                                "urgent" -> "!"
                                "high" -> "•"
                                else -> "·"
                            }
                            lines.append("$mark $title\n")
                        }
                    }
                } catch (_: Exception) {
                    /* keep empty */
                }
            }
            if (lines.isEmpty()) {
                views.setTextViewText(R.id.widget_tasks, "Нет открытых задач")
            } else {
                views.setTextViewText(R.id.widget_tasks, lines.toString().trim())
            }
            views.setViewVisibility(R.id.widget_tasks, View.VISIBLE)

            val launch = Intent(Intent.ACTION_VIEW, Uri.parse("takt://board")).apply {
                setPackage(context.packageName)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val pending = PendingIntent.getActivity(
                context,
                0,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
