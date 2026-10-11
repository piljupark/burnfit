import ActivityKit
import Flutter
import Foundation

/// 다트 `RestTimerAlerts`가 부르는 휴식 타이머 실시간 현황 다리.
/// 채널 `refit/rest_activity`: `show`(startAt · endAt 밀리초) — 없으면 만들고 있으면 고친다, `end` — 지운다.
/// 아이폰 16.2 미만이거나 사용자가 실시간 현황을 꺼 두면 아무것도 하지 않는다.
class RestTimerActivityPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "refit/rest_activity", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(RestTimerActivityPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
      result(false)
      return
    }
    switch call.method {
    case "show":
      guard let args = call.arguments as? [String: Any],
        let start = args["startAt"] as? NSNumber,
        let end = args["endAt"] as? NSNumber
      else {
        result(FlutterError(code: "args", message: "startAt · endAt 필요", details: nil))
        return
      }
      let state = RestTimerAttributes.ContentState(
        startAt: Date(timeIntervalSince1970: start.doubleValue / 1000),
        endAt: Date(timeIntervalSince1970: end.doubleValue / 1000))
      Task {
        await RestTimerActivityPlugin.show(state)
        result(true)
      }
    case "end":
      Task {
        await RestTimerActivityPlugin.endAll()
        result(true)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 16.2, *)
  private static func show(_ state: RestTimerAttributes.ContentState) async {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    // 끝 시각이 지나면 위젯이 '휴식 끝'으로 바뀐다 (staleDate).
    let content = ActivityContent(state: state, staleDate: state.endAt)
    if let current = Activity<RestTimerAttributes>.activities.first {
      await current.update(content)
      return
    }
    do {
      _ = try Activity.request(
        attributes: RestTimerAttributes(), content: content, pushType: nil)
    } catch {
      NSLog("[RestTimerActivity] 시작 실패: \(error)")
    }
  }

  @available(iOS 16.2, *)
  private static func endAll() async {
    for activity in Activity<RestTimerAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }
}
