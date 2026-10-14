package com.moaymandev.hadithsearcher

import android.os.Bundle
import android.content.Intent
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.sentry.Sentry
import java.io.File

class MainActivity : FlutterActivity() {
    private var sharedTextChannel: MethodChannel? = null
    private var pendingSharedText: String? = null
    private var shareListenerReady = false

    private fun receiveSharedText(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") return
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.trim()
        if (text.isNullOrEmpty()) return
        if (shareListenerReady) {
            sharedTextChannel?.invokeMethod("sharedText", text)
        } else {
            pendingSharedText = text
        }
        intent.removeExtra(Intent.EXTRA_TEXT)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveSharedText(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.enableEdgeToEdge(window)
        receiveSharedText(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sharedTextChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hadithsearcher/shared_text")
        sharedTextChannel?.setMethodCallHandler { call, result ->
            if (call.method == "consumeSharedText") {
                shareListenerReady = true
                result.success(pendingSharedText)
                pendingSharedText = null
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hadithsearcher/telemetry")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configureDiagnosticsPrivacy" -> {
                        val options = Sentry.getCurrentScopes().options
                        val original = options.beforeSend
                        options.beforeSend = io.sentry.SentryOptions.BeforeSendCallback { event, hint ->
                            event.user = null
                            event.request = null
                            event.message = null
                            event.exceptions?.forEach { it.value = it.type }
                            event.breadcrumbs = emptyList()
                            if (original == null) event else original.execute(event, hint)
                        }
                        result.success(null)
                    }
                    "prepareDiagnosticsShutdown" -> {
                        val options = Sentry.getCurrentScopes().options
                        options.shutdownTimeoutMillis = 0
                        options.flushTimeoutMillis = 0
                        result.success(null)
                    }
                    "clearDiagnosticsCache" -> {
                        val cache = File(cacheDir, "sentry")
                        val deleted = !cache.exists() || cache.deleteRecursively()
                        if (deleted) result.success(null)
                        else result.error("cache", "Could not clear diagnostics cache", null)
                    }
                    "clearAnalyticsCache" -> {
                        val directories = listOf(
                            File(cacheDir, "posthog-disk-queue"),
                            File(cacheDir, "posthog-disk-replay-queue"),
                            File(cacheDir, "posthog-disk-logs-queue"),
                            File(applicationInfo.dataDir, "app_app_posthog-disk-queue")
                        )
                        val deleted = directories.map { !it.exists() || it.deleteRecursively() }.all { it }
                        val token = call.argument<String>("projectToken") ?: ""
                        val identityCleared = if (call.argument<Boolean>("clearIdentity") != false && token.isNotEmpty()) {
                            getSharedPreferences("posthog-android-$token", MODE_PRIVATE).edit().clear().commit()
                        } else true
                        if (deleted && identityCleared) result.success(null)
                        else result.error("cache", "Could not clear analytics cache", null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
