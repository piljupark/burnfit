import ActivityKit
import SwiftUI
import WidgetKit

/// 휴식 타이머 잠금 화면 · 다이내믹 아일랜드 (앱 안 검정 휴식 막대와 같은 결: 검정 바탕 · 주황 진행).
/// 남은 시간 글자와 진행 막대는 시스템이 직접 센다 — 앱이 잠들어 있어도 줄어든다.
private let brandOrange = Color(red: 1.0, green: 122 / 255, blue: 51 / 255)
private let captionGray = Color(white: 0.62)

struct RestTimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RestTimerAttributes.self) { context in
      LockScreenView(state: context.state, ended: context.isStale)
        .activityBackgroundTint(Color.black)
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      let state = context.state
      let ended = context.isStale
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label {
            Text(ended ? "휴식 끝" : "휴식 중")
              .font(.system(size: 15, weight: .semibold))
          } icon: {
            Image(systemName: "timer").foregroundColor(brandOrange)
          }
          .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          RemainingText(state: state, ended: ended)
            .font(.system(size: 28, weight: .bold).monospacedDigit())
            .foregroundColor(ended ? brandOrange : .white)
            .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.bottom) {
          RestProgress(state: state, ended: ended)
            .padding(.horizontal, 4)
            .padding(.top, 6)
        }
      } compactLeading: {
        Image(systemName: "timer").foregroundColor(brandOrange)
      } compactTrailing: {
        RemainingText(state: state, ended: ended)
          .font(.system(size: 15, weight: .semibold).monospacedDigit())
          .foregroundColor(brandOrange)
          .frame(maxWidth: 52)
      } minimal: {
        Image(systemName: ended ? "checkmark" : "timer").foregroundColor(brandOrange)
      }
      .keylineTint(brandOrange)
    }
  }
}

/// 남은 시간 '1:23' (끝나면 '0:00').
private struct RemainingText: View {
  let state: RestTimerAttributes.ContentState
  let ended: Bool

  var body: some View {
    if ended {
      Text("0:00")
    } else {
      Text(timerInterval: state.startAt...state.endAt, countsDown: true)
        .multilineTextAlignment(.trailing)
    }
  }
}

private struct RestProgress: View {
  let state: RestTimerAttributes.ContentState
  let ended: Bool

  var body: some View {
    if ended {
      ProgressView(value: 0).tint(brandOrange)
    } else {
      ProgressView(timerInterval: state.startAt...state.endAt, countsDown: true) {
        EmptyView()
      } currentValueLabel: {
        EmptyView()
      }
      .tint(brandOrange)
    }
  }
}

private struct LockScreenView: View {
  let state: RestTimerAttributes.ContentState
  let ended: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text("REFIT")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(captionGray)
          Text(ended ? "휴식 끝 · 다음 세트를 시작하세요" : "휴식 중")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
        }
        Spacer()
        RemainingText(state: state, ended: ended)
          .font(.system(size: 34, weight: .bold).monospacedDigit())
          .foregroundColor(ended ? brandOrange : .white)
      }
      RestProgress(state: state, ended: ended)
    }
    .padding(16)
  }
}
