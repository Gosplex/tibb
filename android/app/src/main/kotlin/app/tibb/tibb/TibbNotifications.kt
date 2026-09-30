package app.tibb.tibb

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/**
 * Local notifications only. Tibb notifies about events, never about absence
 * (brief §7.14). Three channels, named the way the design guide lists them.
 */
object TibbNotifications {
    const val CH_ARRIVALS = "from_computer"
    const val CH_BRIDGE = "bridge_status"
    const val CH_IMPORTS = "imports"

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        nm.createNotificationChannel(
            NotificationChannel(CH_ARRIVALS, "From your computer", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Items and clipboard text your computer saves to this phone."
            },
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_BRIDGE, "Bridge status", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Shown while your computer is connected."
                setShowBadge(false)
            },
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_IMPORTS, "Imports", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "When a WhatsApp or Tibb import finishes."
            },
        )
    }

    fun openAppIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    @SuppressLint("MissingPermission") // checked just below
    fun show(context: Context, id: Int, channelId: String, title: String, body: String) {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return
        ensureChannels(context)
        val n = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_stat_tibb)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setColor(0xFFF5B324.toInt())
            .setContentIntent(openAppIntent(context))
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(id, n)
        } catch (_: SecurityException) {
            // Notifications not allowed: the event is still visible in the app.
        }
    }
}
