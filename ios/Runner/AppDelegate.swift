import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 기기 안 예약 알림(운동 리마인드)을 누른 것을 앱이 받도록 한다 (flutter_local_notifications)
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // 휴식 타이머 잠금 화면 · 다이내믹 아일랜드 (실시간 현황)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RestTimerActivityPlugin") {
      RestTimerActivityPlugin.register(with: registrar)
    }
  }
}
