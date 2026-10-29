package ru.gadzhilaev.takt

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.RadioButton
import android.widget.Spinner
import org.json.JSONArray
import org.json.JSONObject

/**
 * Per-instance configuration: task mode (mine/all) + project.
 * Settings stored by [appWidgetId] — never stores auth tokens.
 */
class TaktWidgetConfigActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.takt_widget_config)

        val modeMine = findViewById<RadioButton>(R.id.mode_mine)
        val modeAll = findViewById<RadioButton>(R.id.mode_all)
        val spinner = findViewById<Spinner>(R.id.project_spinner)
        val save = findViewById<Button>(R.id.save_button)

        val projects = loadProjects()
        val names = projects.map { it.second }.ifEmpty { listOf("Текущий проект") }
        val ids = projects.map { it.first }.ifEmpty { listOf("") }

        spinner.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, names)

        val existing = WidgetInstanceStore.load(this, appWidgetId)
        if (existing.mode == "all") modeAll.isChecked = true else modeMine.isChecked = true
        val idx = ids.indexOf(existing.projectId).takeIf { it >= 0 } ?: 0
        if (idx < names.size) spinner.setSelection(idx)

        save.setOnClickListener {
            val mode = if (modeAll.isChecked) "all" else "mine"
            val projectId = if (ids.isEmpty()) "" else ids[spinner.selectedItemPosition.coerceIn(0, ids.lastIndex)]
            WidgetInstanceStore.save(this, appWidgetId, mode, projectId)
            TaktWidgetProvider.updateAppWidget(this, AppWidgetManager.getInstance(this), appWidgetId)
            val result = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            setResult(RESULT_OK, result)
            finish()
        }
    }

    private fun loadProjects(): List<Pair<String, String>> {
        val prefs = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
        val raw = prefs.getString("snapshot", "") ?: ""
        if (raw.isBlank()) return emptyList()
        return try {
            val json = JSONObject(raw)
            val out = mutableListOf<Pair<String, String>>()
            val arr: JSONArray? = json.optJSONArray("projects")
            if (arr != null) {
                for (i in 0 until arr.length()) {
                    val p = arr.getJSONObject(i)
                    val id = p.optString("id")
                    val name = p.optString("name")
                    if (id.isNotBlank() && name.isNotBlank()) out.add(id to name)
                }
            }
            if (out.isEmpty()) {
                val id = json.optString("project_id")
                val name = json.optString("project_name")
                if (id.isNotBlank()) out.add(id to name.ifBlank { "Проект" })
            }
            out
        } catch (_: Exception) {
            emptyList()
        }
    }
}

object WidgetInstanceStore {
    private const val PREFS = "TaktWidgetInstancePrefs"

    data class Config(val mode: String, val projectId: String)

    fun save(context: android.content.Context, widgetId: Int, mode: String, projectId: String) {
        context.getSharedPreferences(PREFS, android.content.Context.MODE_PRIVATE)
            .edit()
            .putString(keyMode(widgetId), mode)
            .putString(keyProject(widgetId), projectId)
            .apply()
    }

    fun load(context: android.content.Context, widgetId: Int): Config {
        val prefs = context.getSharedPreferences(PREFS, android.content.Context.MODE_PRIVATE)
        return Config(
            mode = prefs.getString(keyMode(widgetId), "mine") ?: "mine",
            projectId = prefs.getString(keyProject(widgetId), "") ?: "",
        )
    }

    fun clear(context: android.content.Context, widgetId: Int) {
        context.getSharedPreferences(PREFS, android.content.Context.MODE_PRIVATE)
            .edit()
            .remove(keyMode(widgetId))
            .remove(keyProject(widgetId))
            .apply()
    }

    private fun keyMode(id: Int) = "mode_$id"
    private fun keyProject(id: Int) = "project_$id"
}
