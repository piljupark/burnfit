import ActivityKit
import Foundation

/// 휴식 타이머 실시간 현황 (잠금 화면 · 다이내믹 아일랜드). 앱과 위젯 확장이 함께 쓴다.
/// 남은 시간은 위젯이 [startAt]~[endAt]으로 직접 센다 — 앱이 잠들어도 줄어든다.
@available(iOS 16.2, *)
struct RestTimerAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var startAt: Date
    var endAt: Date
  }
}
