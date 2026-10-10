import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appearanceKey = "alastudie.darkMode"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    applySavedAppearance()
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.alastudie/appearance",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setDarkMode", let enabled = call.arguments as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self else {
        result(nil)
        return
      }
      UserDefaults.standard.set(enabled, forKey: appearanceKey)
      applyAppearance(dark: enabled)
      result(nil)
    }
    applySavedAppearance()
  }

  private func applySavedAppearance() {
    applyAppearance(dark: UserDefaults.standard.bool(forKey: appearanceKey))
  }

  private func applyAppearance(dark: Bool) {
    let style: UIUserInterfaceStyle = dark ? .dark : .light
    window?.overrideUserInterfaceStyle = style
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      for sceneWindow in windowScene.windows {
        sceneWindow.overrideUserInterfaceStyle = style
      }
    }
  }
}
