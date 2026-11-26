package com.moaymandev.hadithsearcher

import android.os.Bundle
import android.os.Build
import android.content.Intent
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.sentry.Sentry
import io.sentry.protocol.User
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hadithsearcher/updates")
            .setMethodCallHandler { call, result ->
                if (call.method == "supportedAbis") {
                    result.success(Build.SUPPORTED_ABIS.toList())
                } else if (call.method == "availableVersionCode") {
                    DistributionUpdates.availableVersionCode(this, result)
                } else {
                    result.notImplemented()
                }
            }
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
                        val installationId = call.argument<String>("installationId")
                        val distribution = call.argument<String>("distribution")
                        val options = Sentry.getCurrentScopes().options
                        val original = options.beforeSend
                        options.beforeSend = io.sentry.SentryOptions.BeforeSendCallback { event, hint ->
                            val report = if (original == null) event else original.execute(event, hint)
                            report?.apply {
                                user = installationId?.let { id -> User().apply { this.id = id } }
                                request = null
                                message = null
                                exceptions?.forEach { it.value = it.type }
                                breadcrumbs = emptyList()
                                distribution?.let { setTag("distribution", it) }
                            }
                        }
                        result.success(null)
                    }
                    "prepareDiagnosticsShutdown" -> {
                        val options = Sentry.getCurrentScopes().options
                        options.beforeSend = io.sentry.SentryOptions.BeforeSendCallback { _, _ -> null }
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
                    "analyticsDeviceContext" -> {
                        val token = call.argument<String>("projectToken").orEmpty()
                        val previousId = if (token.isEmpty()) null else {
                            val preferences = getSharedPreferences("posthog-android-$token", MODE_PRIVATE)
                            // The old client never identified users. Migrate only a generated UUID.
                            preferences.getString("anonymousId", null)?.takeIf {
                                runCatching { java.util.UUID.fromString(it).toString() == it }.getOrDefault(false)
                            }
                        }
                        val properties = mutableMapOf(
                            "deviceType" to if (resources.configuration.smallestScreenWidthDp >= 600) "Tablet" else "Mobile",
                            "osVersion" to Build.VERSION.RELEASE,
                        )
                        if (previousId != null) properties["previousId"] = previousId
                        result.success(properties)
                    }
                    "clearLegacyAnalytics" -> {
                        val directories = listOf(
                            File(cacheDir, "posthog-disk-queue"),
                            File(cacheDir, "posthog-disk-replay-queue"),
                            File(cacheDir, "posthog-disk-logs-queue"),
                            File(applicationInfo.dataDir, "app_app_posthog-disk-queue")
                        )
                        val deleted = directories.map { !it.exists() || it.deleteRecursively() }.all { it }
                        val token = call.argument<String>("projectToken") ?: ""
                        val identityCleared = if (token.isNotEmpty()) {
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
