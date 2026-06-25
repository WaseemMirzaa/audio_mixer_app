package com.codetivelab.soundAxis

import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// audio_service 0.18+ requires AudioServiceActivity so the background
// AudioService can communicate with the Flutter engine over IPC.
class MainActivity : AudioServiceActivity() {

    private val effectsChannelName = "com.codetivelab.soundAxis/audio_effects"
    private val backupChannelName = "com.codetivelab.soundAxis/backup_export"
    private val effectsPlugin = AudioEffectsPlugin()

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
    }

    override fun onDestroy() {
        effectsPlugin.releaseAll()
        super.onDestroy()
    }
}
