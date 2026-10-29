package ru.gadzhilaev.takt

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

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

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            WidgetInstanceStore.clear(context, id)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?,
    ) {
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    companion object {
        private const val PREFS = "HomeWidgetPreferences"

        private enum class Size { SMALL, MEDIUM, LARGE }

        private data class Slot(
            val row: Int,
            val title: Int,
            val priority: Int,
            val status: Int?,
        )

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val config = WidgetInstanceStore.load(context, appWidgetId)
            val snapshot = parseSnapshot(prefs.getString("snapshot", "") ?: "", prefs, config)

            val size = resolveSize(appWidgetManager, appWidgetId)
            val layout = when (size) {
                Size.SMALL -> R.layout.takt_widget_small
                Size.LARGE -> R.layout.takt_widget_large
                Size.MEDIUM -> R.layout.takt_widget
            }
            val views = RemoteViews(context.packageName, layout)
            val titleLabel = when {
                size == Size.SMALL -> "Задачи"
                config.mode == "all" -> "Все задачи"
                else -> "Мои задачи"
            }

            try {
                views.setTextViewText(R.id.widget_title, titleLabel)
            } catch (_: Exception) {
            }

            if (!snapshot.loggedIn && snapshot.openCount == 0 && snapshot.tasks.isEmpty()) {
                views.setTextViewText(R.id.widget_project, "Takt")
                views.setTextViewText(R.id.widget_count, "—")
                setUrgentText(context, views, "Войдите в приложение", muted = true, visible = true)
                hideAllSlots(views, size)
                try {
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    views.setTextViewText(R.id.widget_empty, "Войдите, чтобы видеть задачи")
                } catch (_: Exception) {
                }
            } else {
                views.setTextViewText(R.id.widget_project, snapshot.projectName.ifBlank { "Takt" })
                views.setTextViewText(R.id.widget_count, snapshot.openCount.toString())
                try {
                    views.setTextViewText(R.id.widget_count_label, titleLabel)
                } catch (_: Exception) {
                }

                when (size) {
                    Size.SMALL -> {
                        val urgentText = when {
                            snapshot.openCount == 0 -> "Нет активных"
                            snapshot.urgentCount == 0 -> "Нет срочных"
                            else -> "${snapshot.urgentCount} срочных"
                        }
                        setUrgentText(
                            context,
                            views,
                            urgentText,
                            muted = snapshot.urgentCount == 0,
                            visible = true,
                        )
                    }
                    Size.MEDIUM, Size.LARGE -> {
                        if (snapshot.urgentCount > 0) {
                            setUrgentText(
                                context,
                                views,
                                "${snapshot.urgentCount} срочных",
                                muted = false,
                                visible = true,
                            )
                        } else {
                            setUrgentText(context, views, "", muted = false, visible = false)
                        }
                    }
                }
                bindTasks(context, views, snapshot, size)
            }

            val openUri = if (config.mode == "mine") {
                Uri.parse("takt://my-tasks")
            } else {
                buildBoardUri(snapshot.projectId)
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                pendingView(context, openUri, appWidgetId * 100),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun setUrgentText(
            context: Context,
            views: RemoteViews,
            text: String,
            muted: Boolean,
            visible: Boolean,
        ) {
            try {
                views.setTextViewText(R.id.widget_urgent, text)
                val colorRes = if (muted) R.color.takt_muted else R.color.takt_urgent
                views.setTextColor(R.id.widget_urgent, ContextCompat.getColor(context, colorRes))
                views.setViewVisibility(R.id.widget_urgent, if (visible) View.VISIBLE else View.GONE)
            } catch (_: Exception) {
            }
        }

        private fun slotsFor(size: Size): List<Slot> = when (size) {
            Size.SMALL -> emptyList()
            Size.MEDIUM -> listOf(
                Slot(R.id.widget_task_1, R.id.task_1_title, R.id.task_1_priority, null),
                Slot(R.id.widget_task_2, R.id.task_2_title, R.id.task_2_priority, null),
                Slot(R.id.widget_task_3, R.id.task_3_title, R.id.task_3_priority, null),
            )
            Size.LARGE -> listOf(
                Slot(R.id.widget_task_1, R.id.task_1_title, R.id.task_1_priority, R.id.task_1_status),
                Slot(R.id.widget_task_2, R.id.task_2_title, R.id.task_2_priority, R.id.task_2_status),
                Slot(R.id.widget_task_3, R.id.task_3_title, R.id.task_3_priority, R.id.task_3_status),
                Slot(R.id.widget_task_4, R.id.task_4_title, R.id.task_4_priority, R.id.task_4_status),
                Slot(R.id.widget_task_5, R.id.task_5_title, R.id.task_5_priority, R.id.task_5_status),
                Slot(R.id.widget_task_6, R.id.task_6_title, R.id.task_6_priority, R.id.task_6_status),
            )
        }

        private fun hideAllSlots(views: RemoteViews, size: Size) {
            for (slot in slotsFor(size)) views.setViewVisibility(slot.row, View.GONE)
        }

        private fun bindTasks(
            context: Context,
            views: RemoteViews,
            snapshot: Snapshot,
            size: Size,
        ) {
            val slots = slotsFor(size)
            if (slots.isEmpty()) return
            if (snapshot.tasks.isEmpty()) {
                hideAllSlots(views, size)
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setTextViewText(R.id.widget_empty, "Нет задач")
                return
            }
            views.setViewVisibility(R.id.widget_empty, View.GONE)
            val limit = minOf(snapshot.tasks.size, slots.size)
            for (i in slots.indices) {
                val slot = slots[i]
                if (i >= limit) {
                    views.setViewVisibility(slot.row, View.GONE)
                    continue
                }
                val task = snapshot.tasks[i]
                views.setViewVisibility(slot.row, View.VISIBLE)
                views.setTextViewText(slot.title, task.title)
                views.setInt(
                    slot.priority,
                    "setBackgroundColor",
                    ContextCompat.getColor(context, priorityColorRes(task.priority)),
                )
                if (slot.status != null) {
                    if (task.statusName.isNotBlank()) {
                        views.setViewVisibility(slot.status, View.VISIBLE)
                        views.setTextViewText(slot.status, task.statusName)
                    } else {
                        views.setViewVisibility(slot.status, View.GONE)
                    }
                }
                val taskUri = buildTaskUri(task.id, task.projectId.ifBlank { snapshot.projectId })
                views.setOnClickPendingIntent(
                    slot.row,
                    pendingView(context, taskUri, slot.row + i + (snapshot.projectId.hashCode() and 0xFFFF)),
                )
            }
        }

        private fun pendingView(context: Context, uri: Uri, requestCode: Int): PendingIntent {
            val launch = Intent(Intent.ACTION_VIEW, uri).apply {
                setPackage(context.packageName)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context,
                requestCode,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun buildBoardUri(projectId: String): Uri {
            val builder = Uri.parse("takt://board").buildUpon()
            if (projectId.isNotBlank()) builder.appendQueryParameter("project", projectId)
            return builder.build()
        }

        private fun buildTaskUri(taskId: String, projectId: String): Uri {
            val builder = Uri.parse("takt://task").buildUpon().appendQueryParameter("id", taskId)
            if (projectId.isNotBlank()) builder.appendQueryParameter("project", projectId)
            return builder.build()
        }

        private fun priorityColorRes(priority: String): Int = when (priority) {
            "urgent" -> R.color.takt_urgent
            "high" -> R.color.takt_high
            else -> R.color.takt_medium
        }

        private fun resolveSize(manager: AppWidgetManager, id: Int): Size {
            val options = manager.getAppWidgetOptions(id)
            val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 180)
            val minH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
            return when {
                minW < 180 || minH < 100 -> Size.SMALL
                minH >= 220 -> Size.LARGE
                else -> Size.MEDIUM
            }
        }

        private data class TaskRow(
            val id: String,
            val title: String,
            val priority: String,
            val statusName: String,
            val projectId: String,
        )

        private data class Snapshot(
            val loggedIn: Boolean,
            val projectName: String,
            val projectId: String,
            val openCount: Int,
            val urgentCount: Int,
            val tasks: List<TaskRow>,
        )

        private fun parseSnapshot(
            raw: String,
            prefs: SharedPreferences,
            config: WidgetInstanceStore.Config,
        ): Snapshot {
            var loggedIn = prefs.contains("logged_in") && prefs.getBoolean("logged_in", false)
            var projectName = prefs.getString("project_name", "") ?: ""
            var projectId = ""
            var openCount = prefs.getInt("open_count", 0)
            var urgentCount = prefs.getInt("urgent_count", 0)
            val tasks = mutableListOf<TaskRow>()
            val modeKey = if (config.mode == "all") "all" else "mine"

            if (raw.isNotBlank()) {
                try {
                    val json = JSONObject(raw)
                    if (json.has("logged_in")) loggedIn = json.optBoolean("logged_in", loggedIn)
                    projectId = config.projectId.ifBlank { json.optString("default_project_id", json.optString("project_id")) }
                    val byProject = json.optJSONObject("by_project")
                    val bucket = byProject?.optJSONObject(projectId)
                    if (bucket != null) {
                        projectName = bucket.optString("project_name", projectName)
                        val scope = bucket.optJSONObject(modeKey)
                        if (scope != null) {
                            openCount = scope.optInt("open_count", openCount)
                            urgentCount = scope.optInt("urgent_count", urgentCount)
                            fillTasks(scope.optJSONArray("tasks"), projectId, tasks)
                        }
                    } else {
                        // v2 / fallback
                        projectName = json.optString("project_name", projectName)
                        projectId = json.optString("project_id", projectId)
                        openCount = json.optInt("open_count", openCount)
                        urgentCount = json.optInt("urgent_count", urgentCount)
                        fillTasks(json.optJSONArray("tasks"), projectId, tasks)
                    }
                } catch (_: Exception) {
                }
            }

            if (!prefs.contains("logged_in") && !raw.contains("\"logged_in\"")) {
                loggedIn = projectName.isNotBlank() || tasks.isNotEmpty() || openCount > 0
            }

            return Snapshot(loggedIn, projectName, projectId, openCount, urgentCount, tasks)
        }

        private fun fillTasks(arr: JSONArray?, projectId: String, out: MutableList<TaskRow>) {
            if (arr == null) return
            for (i in 0 until arr.length()) {
                val t = arr.getJSONObject(i)
                out.add(
                    TaskRow(
                        id = t.optString("id"),
                        title = t.optString("title"),
                        priority = t.optString("priority", "medium"),
                        statusName = t.optString("status_name"),
                        projectId = t.optString("project_id", projectId),
                    ),
                )
            }
        }
    }
}
