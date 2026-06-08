import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {

  private let effectsPlugin = AudioEffectsPlugin()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // GeneratedPluginRegistrant registers all Flutter plugins (including
    // just_audio_background which sets up the audio session).
    GeneratedPluginRegistrant.register(with: self)

    // Register our native audio-effects channel after Flutter engine is ready.
    // We use the FlutterAppDelegate's built-in FlutterViewController reference.
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.example.audio_mixer_app/audio_effects",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler(effectsPlugin.handle(_:result:))
    }

    return result
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    effectsPlugin.releaseAll()
    super.applicationWillTerminate(application)
  }
}
