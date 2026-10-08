package com.example.user_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    /** Push channels used by the backend (notification-matrix.md §3, M18). */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        listOf(
            Triple("bookings", "Bookings & quotes", NotificationManager.IMPORTANCE_HIGH),
            Triple("reminders", "Reminders & checklist", NotificationManager.IMPORTANCE_HIGH),
            Triple("general", "Other", NotificationManager.IMPORTANCE_DEFAULT),
        ).forEach { (id, name, importance) ->
            manager.createNotificationChannel(NotificationChannel(id, name, importance))
        }
    }
}
