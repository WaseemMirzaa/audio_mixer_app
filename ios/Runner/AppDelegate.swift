import Flutter
import UIKit
import AVFoundation
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate {

  private let effectsPlugin = AudioEffectsPlugin()
  private var incomingChannel: FlutterMethodChannel?
  private var eventSink: FlutterEventSink?
  private var pendingShared: [String: String]?
  private let allowedExt: Set<String> = ["mp3", "wav", "aac", "m4a"]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let effects = FlutterMethodChannel(
        name: "com.codetivelab.soundAxis/audio_effects",
        binaryMessenger: controller.binaryMessenger
      )
      effects.setMethodCallHandler(effectsPlugin.handle(_:result:))

      incomingChannel = FlutterMethodChannel(
        name: "com.codetivelab.soundAxis/incoming_audio",
        binaryMessenger: controller.binaryMessenger
      )
      incomingChannel?.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterMethodNotImplemented)
          return
        }
        switch call.method {
        case "getInitialSharedAudio":
          let payload = self.pendingShared
          self.pendingShared = nil
          result(payload)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let events = FlutterEventChannel(
        name: "com.codetivelab.soundAxis/incoming_audio_events",
        binaryMessenger: controller.binaryMessenger
      )
      events.setStreamHandler(IncomingAudioStreamHandler { [weak self] sink in
        // Cold start uses getInitialSharedAudio; only warm opens use the sink.
        self?.eventSink = sink
      } onCancel: { [weak self] in
        self?.eventSink = nil
      })
    }

    // Cold start via Open In / document URL.
    if let url = launchOptions?[.url] as? URL {
      _ = ingestSharedAudio(url: url, preferEvent: false)
    }

    return result
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if ingestSharedAudio(url: url, preferEvent: true) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  /// Copies a security-scoped shared audio file into the app documents cache
  /// and notifies Flutter.
  @discardableResult
  private func ingestSharedAudio(url: URL, preferEvent: Bool) -> Bool {
    let ext = url.pathExtension.lowercased()
    guard allowedExt.contains(ext) else { return false }

    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed { url.stopAccessingSecurityScopedResource() }
    }

    do {
      let displayName = url.lastPathComponent
      let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        .appendingPathComponent("incoming", isDirectory: true)
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      let dest = dir.appendingPathComponent(UUID().uuidString + "." + ext)
      if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
      }
      try FileManager.default.copyItem(at: url, to: dest)

      let attrs = try FileManager.default.attributesOfItem(atPath: dest.path)
      let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
      if size <= 0 || size > 100 * 1024 * 1024 {
        try? FileManager.default.removeItem(at: dest)
        return false
      }

      let payload = ["path": dest.path, "displayName": displayName]
      if let sink = eventSink {
        sink(payload)
      } else {
        pendingShared = payload
      }
      return true
    } catch {
      return false
    }
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    effectsPlugin.releaseAll()
    super.applicationWillTerminate(application)
  }
}

private final class IncomingAudioStreamHandler: NSObject, FlutterStreamHandler {
  private let onListen: (FlutterEventSink?) -> Void
  private let onCancel: () -> Void

  init(onListen: @escaping (FlutterEventSink?) -> Void, onCancel: @escaping () -> Void) {
    self.onListen = onListen
    self.onCancel = onCancel
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    onListen(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    onCancel()
    return nil
  }
}
