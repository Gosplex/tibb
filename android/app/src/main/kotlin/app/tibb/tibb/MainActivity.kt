package app.tibb.tibb

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Tibb's only native code on Android. One MethodChannel ("app.tibb/platform")
 * carries three things, with no third-party plugins:
 *
 *  1. Share-into-Tibb: ACTION_SEND / ACTION_SEND_MULTIPLE / ACTION_VIEW intents.
 *     Shared content URIs are streamed into the app's cache on a worker thread
 *     (never loaded into memory) and handed to Dart as plain file paths.
 *  2. Local notifications (no push service, no server).
 *  3. The Bridge foreground service, so a paired computer keeps working while
 *     Tibb is minimized.
 */
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())

    /** Dart has asked for shares at least once, so new ones can be pushed. */
    private var dartReady = false
    private var pendingShare: Map<String, Any?>? = null
    private var pendingPermission: MethodChannel.Result? = null

    // Registered at construction, as the Activity Result API requires.
    private val notificationPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            pendingPermission?.success(granted)
            pendingPermission = null
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TibbNotifications.ensureChannels(this)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result -> onCall(call, result) }
        channel = ch
        BridgeService.stopListener = {
            main.post { channel?.invokeMethod("onBridgeStopRequested", null) }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A restored activity must not re-deliver the share it was started with.
        if (savedInstanceState == null) handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onDestroy() {
        // Closing Tibb ends the Bridge session (brief §7.9). The Dart side goes
        // away with the activity, so the foreground service must go too.
        if (isFinishing) BridgeService.stop(this)
        BridgeService.stopListener = null
        channel?.setMethodCallHandler(null)
        channel = null
        super.onDestroy()
    }

    // ------------------------------------------------------------------ calls

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "takeInitialShare" -> {
                dartReady = true
                result.success(pendingShare)
                pendingShare = null
            }
            "moveToBack" -> result.success(moveTaskToBack(true))
            "notificationsAllowed" -> result.success(notificationsAllowed())
            "requestNotifications" -> requestNotifications(result)
            "notify" -> {
                TibbNotifications.show(
                    this,
                    id = call.argument<Int>("id") ?: 1,
                    channelId = call.argument<String>("channel") ?: TibbNotifications.CH_ARRIVALS,
                    title = call.argument<String>("title") ?: "Tibb",
                    body = call.argument<String>("body") ?: "",
                )
                result.success(null)
            }
            "startBridgeService" -> {
                BridgeService.start(
                    this,
                    call.argument<String>("title") ?: "Bridge is on",
                    call.argument<String>("body") ?: "",
                )
                result.success(null)
            }
            "stopBridgeService" -> {
                BridgeService.stop(this)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ---------------------------------------------------------- notifications

    private fun notificationsAllowed(): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestNotifications(result: MethodChannel.Result) {
        if (notificationsAllowed() || Build.VERSION.SDK_INT < 33) {
            result.success(notificationsAllowed())
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    // ----------------------------------------------------------------- shares

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE &&
            action != Intent.ACTION_VIEW
        ) return

        val text = if (action == Intent.ACTION_SEND) {
            intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        } else null
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        val uris = sharedUris(intent, action)
        if (text.isNullOrBlank() && uris.isEmpty()) return

        // Consume it so a config change can't deliver it twice.
        intent.action = null

        Thread {
            val files = ArrayList<Map<String, Any?>>()
            var failed = 0
            for (uri in uris) {
                val copied = copyToCache(uri, intent.type)
                if (copied != null) files.add(copied) else failed++
            }
            val payload = hashMapOf<String, Any?>(
                "text" to text,
                "subject" to subject,
                "files" to files,
                "failed" to failed,
            )
            main.post { deliver(payload) }
        }.start()
    }

    @Suppress("DEPRECATION")
    private fun sharedUris(intent: Intent, action: String): List<Uri> {
        val out = ArrayList<Uri>()
        when (action) {
            Intent.ACTION_SEND -> {
                val u: Uri? = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
                if (u != null) out.add(u)
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val list: ArrayList<Uri>? = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
                }
                if (list != null) out.addAll(list)
            }
            Intent.ACTION_VIEW -> intent.data?.let { out.add(it) }
        }
        // ClipData carries extra URIs some apps use instead of EXTRA_STREAM.
        val clip = intent.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                val u = clip.getItemAt(i).uri ?: continue
                if (!out.contains(u)) out.add(u)
            }
        }
        return out
    }

    /** Streams one shared URI into cache/shared/. Never buffers the whole file. */
    private fun copyToCache(uri: Uri, fallbackType: String?): Map<String, Any?>? {
        return try {
            var name: String? = null
            var size: Long = -1
            contentResolver.query(uri, null, null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val n = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val s = c.getColumnIndex(OpenableColumns.SIZE)
                    if (n >= 0) name = c.getString(n)
                    if (s >= 0 && !c.isNull(s)) size = c.getLong(s)
                }
            }
            var mime = contentResolver.getType(uri)
            if (mime.isNullOrBlank() || mime == "*/*") mime = fallbackType
            val displayName = (name ?: uri.lastPathSegment ?: "shared-file").substringAfterLast('/')
            if (mime.isNullOrBlank() || mime!!.endsWith("/*")) {
                val ext = displayName.substringAfterLast('.', "").lowercase()
                mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "application/octet-stream"
            }
            val dir = File(cacheDir, "shared").apply { mkdirs() }
            val safe = displayName.replace(Regex("[\\\\/:*?\"<>|\\u0000-\\u001f]"), "_").take(120)
            val target = File(dir, "${System.nanoTime()}-$safe")
            val input = contentResolver.openInputStream(uri) ?: return null
            input.use { inp -> target.outputStream().use { out -> inp.copyTo(out, 256 * 1024) } }
            hashMapOf(
                "path" to target.absolutePath,
                "name" to displayName,
                "mime" to mime,
                "size" to (if (size >= 0) size else target.length()),
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun deliver(payload: Map<String, Any?>) {
        val ch = channel
        if (dartReady && ch != null) {
            ch.invokeMethod("onShare", payload)
        } else {
            pendingShare = payload
        }
    }

    companion object {
        const val CHANNEL = "app.tibb/platform"
    }
}
