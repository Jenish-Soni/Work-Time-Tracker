package com.example.time_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class TimeTrackerWidget : AppWidgetProvider() {
    companion object {
        const val ACTION_PUNCH_IN = "com.example.time_tracker.ACTION_PUNCH_IN"
        const val ACTION_PUNCH_OUT = "com.example.time_tracker.ACTION_PUNCH_OUT"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            ACTION_PUNCH_IN -> {
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                prefs.edit().putString("widget_action", "punch_in").apply()
                val backgroundIntent = Intent(context, MainActivity::class.java)
                backgroundIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(backgroundIntent)
            }
            ACTION_PUNCH_OUT -> {
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                prefs.edit().putString("widget_action", "punch_out").apply()
                val backgroundIntent = Intent(context, MainActivity::class.java)
                backgroundIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(backgroundIntent)
            }
        }
    }

    override fun onEnabled(context: Context) {
        // Enter relevant functionality for when the first widget is created
    }

    override fun onDisabled(context: Context) {
        // Enter relevant functionality for when the last widget is disabled
    }
}

internal fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    val widgetData = HomeWidgetPlugin.getData(context)
    val views = RemoteViews(context.packageName, R.layout.widget_layout)

    val status = widgetData.getString("status", "Paused")
    val duration = widgetData.getString("duration", "00:00:00")

    views.setTextViewText(R.id.widget_status, status)
    views.setTextViewText(R.id.widget_duration, duration)

    // Set up button click handlers
    val punchInIntent = Intent(context, TimeTrackerWidget::class.java).apply {
        action = TimeTrackerWidget.ACTION_PUNCH_IN
    }
    val punchInPendingIntent = PendingIntent.getBroadcast(
        context, 0, punchInIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.widget_punch_in_button, punchInPendingIntent)

    val punchOutIntent = Intent(context, TimeTrackerWidget::class.java).apply {
        action = TimeTrackerWidget.ACTION_PUNCH_OUT
    }
    val punchOutPendingIntent = PendingIntent.getBroadcast(
        context, 1, punchOutIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.widget_punch_out_button, punchOutPendingIntent)

    // Instruct the widget manager to update the widget
    appWidgetManager.updateAppWidget(appWidgetId, views)
}
