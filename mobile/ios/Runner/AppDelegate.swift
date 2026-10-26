import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ConnectLinkPlugin") {
      ConnectLinkPlugin.register(with: registrar)
    }
  }
}

/// Hands `studyplan://connect?server=...` links (from the server's QR code) to
/// Dart: `getInitialLink` for a cold start, `onLink` while the app is running.
/// Same channel as `MainActivity.kt` on Android.
final class ConnectLinkPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private let channel: FlutterMethodChannel
  private var initialLink: String?

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "studyplan/connect_link", binaryMessenger: registrar.messenger())
    let instance = ConnectLinkPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addSceneDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "getInitialLink" {
      result(initialLink)
      initialLink = nil
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  private static func connectLink(_ url: URL?) -> String? {
    guard let url = url, url.scheme == "studyplan" else { return nil }
    return url.absoluteString
  }

  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    if let link = Self.connectLink(connectionOptions?.urlContexts.first?.url) {
      initialLink = link
      return true
    }
    return false
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    for context in URLContexts {
      if let link = Self.connectLink(context.url) {
        channel.invokeMethod("onLink", arguments: link)
        return true
      }
    }
    return false
  }
}
