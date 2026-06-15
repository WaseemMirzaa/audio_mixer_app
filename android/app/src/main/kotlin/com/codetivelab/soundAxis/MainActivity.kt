package com.codetivelab.soundAxis

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// audio_service 0.18+ requires AudioServiceActivity so the background
// AudioService can communicate with the Flutter engine over IPC.
class MainActivity : AudioServiceActivity() {

    private val channelName = "com.codetivelab.soundAxis/audio_effects"
    private val effectsPlugin = AudioEffectsPlugin()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        )
        channel.setMethodCallHandler(effectsPlugin)
    }

    override fun onDestroy() {
        effectsPlugin.releaseAll()
        super.onDestroy()
    }
}
