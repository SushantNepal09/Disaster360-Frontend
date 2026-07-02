package com.example.disaster360

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.view.View
import android.graphics.Color

class EmergencyWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val hasReport = prefs.getBoolean("flutter.widget_has_report", false)
        val disasterType = prefs.getString("flutter.widget_disaster_type", "Unknown") ?: "Unknown"
        val reportStatus = prefs.getString("flutter.widget_report_status", "Pending") ?: "Pending"
        val rescueStatus = prefs.getString("flutter.widget_rescue_status", "Not Assigned") ?: "Not Assigned"
        val location = prefs.getString("flutter.widget_location", "Location Unknown") ?: "Location Unknown"

        for (appWidgetId in appWidgetIds) {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("disaster360://emergency"))
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP

            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val views = RemoteViews(context.packageName, R.layout.emergency_widget)
            views.setOnClickPendingIntent(R.id.widget_action_btn, pendingIntent)

            if (!hasReport) {
                views.setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
                views.setViewVisibility(R.id.widget_data_state, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_empty_state, View.GONE)
                views.setViewVisibility(R.id.widget_data_state, View.VISIBLE)

                views.setTextViewText(R.id.widget_disaster_type, disasterType)
                views.setTextViewText(R.id.widget_status, reportStatus)
                views.setTextViewText(R.id.widget_rescue, "● $rescueStatus")
                views.setTextViewText(R.id.widget_location, location)

                // Set icon and background based on disaster type
                when (disasterType.lowercase()) {
                    "flood" -> {
                        views.setImageViewResource(R.id.widget_disaster_icon, R.drawable.ic_flood)
                        views.setInt(R.id.widget_disaster_icon, "setBackgroundResource", R.drawable.widget_icon_flood_bg)
                    }
                    "fire" -> {
                        views.setImageViewResource(R.id.widget_disaster_icon, R.drawable.ic_fire)
                        views.setInt(R.id.widget_disaster_icon, "setBackgroundResource", R.drawable.widget_icon_fire_bg)
                    }
                    "storm" -> {
                        views.setImageViewResource(R.id.widget_disaster_icon, R.drawable.ic_storm)
                        views.setInt(R.id.widget_disaster_icon, "setBackgroundResource", R.drawable.widget_icon_storm_bg)
                    }
                    "earthquake" -> {
                        views.setImageViewResource(R.id.widget_disaster_icon, R.drawable.ic_earthquake)
                        views.setInt(R.id.widget_disaster_icon, "setBackgroundResource", R.drawable.widget_icon_earthquake_bg)
                    }
                    "landslide" -> {
                        views.setImageViewResource(R.id.widget_disaster_icon, R.drawable.ic_landslide)
                        views.setInt(R.id.widget_disaster_icon, "setBackgroundResource", R.drawable.widget_icon_landslide_bg)
                    }
                    "road damage" -> {
                        views.setImageViewResource(R.id.widget_disaster_icon, R.drawable.ic_road_damage)
                        views.setInt(R.id.widget_disaster_icon, "setBackgroundResource", R.drawable.widget_icon_road_damage_bg)
                    }
                    else -> {
                        views.setImageViewResource(R.id.widget_disaster_icon, R.drawable.ic_warning_orange)
                        views.setInt(R.id.widget_disaster_icon, "setBackgroundResource", R.drawable.widget_icon_default_bg)
                    }
                }

                // Set colors based on status
                if (reportStatus.lowercase() == "verified") {
                    views.setTextColor(R.id.widget_status, Color.parseColor("#00E676")) // Green
                } else {
                    views.setTextColor(R.id.widget_status, Color.parseColor("#FF9800")) // Orange
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
