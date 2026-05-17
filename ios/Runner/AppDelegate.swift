import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  // ─── Shared constants (must match ShareViewController.swift) ──────────
  private let kAppGroupId = "group.com.docshelf.myapp"
  private let kShareKey   = "ShareKey"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // ── Native method channel: read/clear pending share-intent data ──────
    // receive_sharing_intent fires eventSink too early on scene cold-starts
    // (before Flutter has registered a listener). The stream event is lost
    // and getInitialMedia() returns nil because initialMedia is never set
    // via the scene delegate code path. We work around this by letting Dart
    // poll this channel on startup and every app-resume.
    let registrar = engineBridge.pluginRegistry
      .registrar(forPlugin: "DocShelfShareIntent")
    guard let registrar else { return }

    let channel = FlutterMethodChannel(
      name: "docshelf/share_intent",
      binaryMessenger: registrar.messenger())

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self else { return }
      switch call.method {

      case "getAndClear":
        // Returns [String] of file:// paths, or empty list if nothing pending.
        guard let defaults = UserDefaults(suiteName: self.kAppGroupId),
              let data     = defaults.data(forKey: self.kShareKey) else {
          result([String]())
          return
        }
        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
          let paths = jsonArray
            .compactMap { $0["path"] as? String }
            .filter      { !$0.isEmpty }
          defaults.removeObject(forKey: self.kShareKey)
          defaults.synchronize()
          result(paths)
        } else {
          defaults.removeObject(forKey: self.kShareKey)
          result([String]())
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
