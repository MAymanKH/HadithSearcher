package com.moaymandev.hadithsearcher

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

internal class ReplayPlatform(context: Context, messenger: BinaryMessenger) {
    private val directory = File(context.noBackupFilesDir, "posthog-replay")
    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var upload: Upload? = null
    private val transport = MethodChannel(messenger, "hadithsearcher/replay")
    private val encoder = MethodChannel(
        messenger, "hadithsearcher/replay_encoder", StandardMethodCodec.INSTANCE,
        messenger.makeBackgroundTaskQueue()
    )

    init {
        transport.setMethodCallHandler { call, result ->
            when (call.method) {
                "queuePath" -> result.success(File(directory, "uploads.db").path)
                "clearQueue" -> worker.execute {
                    if (!directory.exists() || directory.deleteRecursively()) result.success(null)
                    else result.error("cache", "Could not clear replay queue", null)
                }
                "cancelUpload" -> {
                    upload?.cancel()
                    result.success(null)
                }
                "uploadOnWifi" -> {
                    val endpoint = call.argument<String>("endpoint")
                    val body = call.argument<ByteArray>("body")
                    if (endpoint == null || body == null) {
                        result.error("arguments", "Replay endpoint and payload are required", null)
                    } else {
                        uploadOnWifi(endpoint, body, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
        encoder.setMethodCallHandler { call, result ->
            if (call.method != "encodeWebp") {
                result.notImplemented()
            } else {
                val png = call.arguments as? ByteArray
                result.success(png?.let(::encodeWebp))
            }
        }
    }

    private fun uploadOnWifi(endpoint: String, body: ByteArray, result: MethodChannel.Result) {
        val network = connectivity?.activeNetwork
        val capabilities = network?.let { connectivity.getNetworkCapabilities(it) }
        if (network == null ||
            capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) != true ||
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
        ) {
            result.success(null)
            return
        }
        if (upload != null) {
            result.error("busy", "A replay upload is already running", null)
            return
        }
        val request = Upload(network, endpoint, body)
        upload = request
        worker.execute {
            val status = request.send()
            main.post {
                if (upload === request) upload = null
                result.success(status)
            }
        }
    }

    private fun encodeWebp(png: ByteArray): ByteArray? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        val bitmap = BitmapFactory.decodeByteArray(png, 0, png.size) ?: return null
        try {
            val output = ByteArrayOutputStream()
            return if (bitmap.compress(Bitmap.CompressFormat.WEBP_LOSSLESS, 70, output)) {
                output.toByteArray()
            } else null
        } finally {
            bitmap.recycle()
        }
    }

    fun close() {
        transport.setMethodCallHandler(null)
        encoder.setMethodCallHandler(null)
        upload?.cancel()
        worker.shutdown()
    }

    private class Upload(
        val network: Network,
        val endpoint: String,
        val body: ByteArray
    ) {
        private var connection: HttpURLConnection? = null
        private var cancelled = false

        fun send(): Int? {
            return try {
                val request = network.openConnection(URL(endpoint)) as HttpURLConnection
                try {
                    request.instanceFollowRedirects = false
                    request.requestMethod = "POST"
                    request.connectTimeout = 5000
                    request.readTimeout = 5000
                    request.doOutput = true
                    request.setRequestProperty("Content-Type", "application/json")
                    request.setRequestProperty("Content-Encoding", "gzip")
                    request.setFixedLengthStreamingMode(body.size)
                    if (track(request)) {
                        request.outputStream.use { it.write(body) }
                        request.responseCode
                    } else null
                } finally {
                    untrack()
                    request.disconnect()
                }
            } catch (_: IOException) {
                null
            }
        }

        @Synchronized
        private fun track(request: HttpURLConnection): Boolean {
            if (cancelled) return false
            connection = request
            return true
        }

        @Synchronized
        private fun untrack() {
            connection = null
        }

        fun cancel() {
            val request = synchronized(this) {
                cancelled = true
                connection
            }
            if (request != null) Thread { request.disconnect() }.start()
        }
    }
}
