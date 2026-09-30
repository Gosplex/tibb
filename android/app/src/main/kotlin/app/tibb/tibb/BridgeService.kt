package app.tibb.tibb

import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Keeps Tibb's process in the foreground while a computer is connected, so the
 * Bridge server (which runs in Dart) survives the app being minimized. Holds a
 * Wi-Fi lock and a partial wake lock for as long as it runs, and nothing else.
 * The persistent notification is the honest signal that it is on (brief §7.9).
 */
class BridgeService : Service() {
    private var wifiLock: WifiManager.WifiLock? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopListener?.invoke()
            shutdown()
            return START_NOT_STICKY
        }
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Bridge is on"
        val body = intent?.getStringExtra(EXTRA_BODY) ?: "Tap to open Tibb."
        val notification = build(title, body)
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // The OS refused a foreground service. Bridge still works while Tibb is on screen.
            stopSelf()
            return START_NOT_STICKY
        }
        acquireLocks()
        return START_NOT_STICKY
    }

    private fun build(title: String, body: String) =
        NotificationCompat.Builder(this, TibbNotifications.CH_BRIDGE)
            .setSmallIcon(R.drawable.ic_stat_tibb)
            .setContentTitle(title)
            .setContentText(body)
            .setColor(0xFF0A7366.toInt())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(TibbNotifications.openAppIntent(this))
            .addAction(0, "Stop", stopIntent())
            .build()

    private fun stopIntent(): PendingIntent {
        val i = Intent(this, BridgeService::class.java).setAction(ACTION_STOP)
        return PendingIntent.getService(
            this, 1, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    @Suppress("DEPRECATION")
    private fun acquireLocks() {
        if (wifiLock == null) {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            val mode = if (Build.VERSION.SDK_INT >= 29) {
                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
            } else {
                WifiManager.WIFI_MODE_FULL_HIGH_PERF
            }
            wifiLock = wm?.createWifiLock(mode, "tibb:bridge")?.apply {
                setReferenceCounted(false)
                acquire()
            }
        }
        if (wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            wakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "tibb:bridge")?.apply {
                setReferenceCounted(false)
            }
        }
        // Re-arm on every start/update so long sessions stay awake.
        wakeLock?.acquire(MAX_WAKE_MS)
    }

    private fun releaseLocks() {
        try { wifiLock?.takeIf { it.isHeld }?.release() } catch (_: Exception) {}
        try { wakeLock?.takeIf { it.isHeld }?.release() } catch (_: Exception) {}
        wifiLock = null
        wakeLock = null
    }

    private fun shutdown() {
        releaseLocks()
        if (Build.VERSION.SDK_INT >= 24) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        releaseLocks()
        super.onDestroy()
    }

    companion object {
        private const val ACTION_STOP = "app.tibb.tibb.BRIDGE_STOP"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_BODY = "body"
        private const val NOTIFICATION_ID = 7001
        // Matches the 30-minute idle session limit, with headroom.
        private const val MAX_WAKE_MS = 45L * 60L * 1000L

        /** Set by MainActivity: the notification's Stop button ends the session in Dart. */
        @Volatile
        var stopListener: (() -> Unit)? = null

        fun start(context: Context, title: String, body: String) {
            TibbNotifications.ensureChannels(context)
            val i = Intent(context, BridgeService::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_BODY, body)
            try {
                ContextCompat.startForegroundService(context, i)
            } catch (_: Exception) {
                // Background-start restrictions: Bridge keeps working while Tibb is open.
            }
        }

        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, BridgeService::class.java))
            } catch (_: Exception) {}
        }
    }
}
