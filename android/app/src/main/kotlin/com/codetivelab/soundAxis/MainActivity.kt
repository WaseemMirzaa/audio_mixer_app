package com.codetivelab.soundAxis

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import java.util.UUID

// audio_service 0.18+ requires AudioServiceActivity so the background
// AudioService can communicate with the Flutter engine over IPC.
class MainActivity : AudioServiceActivity() {

    private val effectsChannelName = "com.codetivelab.soundAxis/audio_effects"
    private val backupChannelName = "com.codetivelab.soundAxis/backup_export"
    private val incomingChannelName = "com.codetivelab.soundAxis/incoming_audio"
    private val incomingEventsName = "com.codetivelab.soundAxis/incoming_audio_events"
    private val effectsPlugin = AudioEffectsPlugin()

    private val allowedExt = setOf("mp3", "wav", "aac", "m4a")
    private var pendingShared: HashMap<String, String>? = null
    private var eventSink: EventChannel.EventSink? = null
    private var intentHandledForHash: Int? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingIntent(intent, fromNewIntent = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent, fromNewIntent = true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            effectsChannelName,
        ).setMethodCallHandler(effectsPlugin)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            backupChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSdkInt" -> result.success(Build.VERSION.SDK_INT)
                "saveToPublicDownloads" -> {
                    try {
                        val sourcePath = call.argument<String>("sourcePath")
                        val displayName = call.argument<String>("displayName")
                        if (sourcePath.isNullOrBlank() || displayName.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing backup path or name", null)
                            return@setMethodCallHandler
                        }
                        val saved = BackupExportHandler(this)
                            .saveToDownloads(sourcePath, displayName)
                        result.success(saved)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            incomingChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedAudio" -> {
                    val payload = pendingShared
                    pendingShared = null
                    result.success(payload)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            incomingEventsName,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                // Cold start is delivered via getInitialSharedAudio — do not
                // auto-flush pending here (broadcast listeners may not be ready).
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun handleIncomingIntent(intent: Intent?, fromNewIntent: Boolean) {
        if (intent == null) return
        val hash = System.identityHashCode(intent)
        if (!fromNewIntent && intentHandledForHash == hash) return

        val action = intent.action ?: return
        val uri: Uri? = when (action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
            }
            else -> null
        } ?: return

        val mime = intent.type ?: contentResolver.getType(uri)
        if (mime != null && !mime.startsWith("audio/") && mime != "*/*") {
            // Still allow if the file extension looks like audio (some apps send octet-stream).
            val nameHint = queryDisplayName(uri)
            val extHint = extensionOf(nameHint, mime)
            if (extHint == null) return
        }

        val copied = copyUriToCache(uri) ?: return
        intentHandledForHash = hash
        deliverSharedAudio(copied.first, copied.second, preferEvent = fromNewIntent)
    }

    private fun deliverSharedAudio(path: String, displayName: String, preferEvent: Boolean) {
        val payload = hashMapOf("path" to path, "displayName" to displayName)
        val sink = eventSink
        if (preferEvent && sink != null) {
            sink.success(payload)
        } else {
            pendingShared = payload
            // If Flutter is already listening (warm), push immediately too.
            sink?.success(payload)
            if (sink != null) pendingShared = null
        }
    }

    private fun copyUriToCache(uri: Uri): Pair<String, String>? {
        return try {
            val displayName = queryDisplayName(uri) ?: "shared_audio"
            val mime = contentResolver.getType(uri)
            val ext = extensionOf(displayName, mime) ?: return null
            val dir = File(cacheDir, "incoming")
            if (!dir.exists()) dir.mkdirs()
            val dest = File(dir, "${UUID.randomUUID()}.$ext")
            contentResolver.openInputStream(uri)?.use { input ->
                dest.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            if (!dest.exists() || dest.length() <= 0L) return null
            if (dest.length() > 100L * 1024L * 1024L) {
                dest.delete()
                return null
            }
            Pair(dest.absolutePath, displayName)
        } catch (_: Exception) {
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        if (uri.scheme == "file") return uri.lastPathSegment
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) return cursor.getString(idx)
                }
            }
        return uri.lastPathSegment
    }

    private fun extensionOf(name: String?, mime: String?): String? {
        val fromName = name
            ?.substringAfterLast('.', missingDelimiterValue = "")
            ?.lowercase(Locale.US)
        if (fromName != null && fromName in allowedExt) return fromName
        val fromMime = MimeTypeMap.getSingleton()
            .getExtensionFromMimeType(mime?.lowercase(Locale.US))
            ?.lowercase(Locale.US)
        return when {
            fromMime != null && fromMime in allowedExt -> fromMime
            mime == "audio/mpeg" -> "mp3"
            mime == "audio/mp4" || mime == "audio/m4a" || mime == "audio/x-m4a" -> "m4a"
            mime == "audio/aac" || mime == "audio/aacp" -> "aac"
            mime == "audio/wav" || mime == "audio/x-wav" || mime == "audio/wave" -> "wav"
            else -> null
        }
    }

    override fun onDestroy() {
        effectsPlugin.releaseAll()
        super.onDestroy()
    }
}
