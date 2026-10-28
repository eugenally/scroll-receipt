import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ReceiptWidgetBundle: WidgetBundle {
  var body: some Widget {
    ReceiptLiveActivity()
  }
}

/// 안드로이드 플로팅 🧾 버튼의 아이폰판. 인스타그램을 보는 동안 다이내믹 아일랜드·잠금 화면에 뜨고,
/// 누르면 앱의 영수증 화면이 열린다.
struct ReceiptLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: ReceiptActivityAttributes.self) { context in
      LockScreenView(state: context.state)
        .activityBackgroundTint(Color(red: 0.11, green: 0.11, blue: 0.12))
        .widgetURL(ReceiptActivityAttributes.receiptURL)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label { UsageText(state: context.state) } icon: { Text("🧾") }
            .font(.headline)
        }
        DynamicIslandExpandedRegion(.trailing) {
          FeedText(state: context.state)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text("눌러서 오늘의 영수증 보기")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } compactLeading: {
        Text("🧾")
      } compactTrailing: {
        UsageText(state: context.state)
          .font(.caption.monospacedDigit())
          .frame(maxWidth: 52)
      } minimal: {
        Text("🧾")
      }
      .widgetURL(ReceiptActivityAttributes.receiptURL)
    }
  }
}

private struct LockScreenView: View {
  let state: ReceiptActivityAttributes.ContentState

  var body: some View {
    HStack(spacing: 12) {
      Text("🧾").font(.largeTitle)
      VStack(alignment: .leading, spacing: 2) {
        Text("오늘 인스타그램").font(.caption).foregroundStyle(.secondary)
        UsageText(state: state).font(.title2.monospacedDigit().bold())
      }
      Spacer()
      FeedText(state: state).font(.subheadline).foregroundStyle(.secondary)
    }
    .foregroundStyle(.white)
    .padding()
  }
}

/// 오늘 이용 시간. 보는 중이면 갱신 없이 타이머로 계속 올라간다
private struct UsageText: View {
  let state: ReceiptActivityAttributes.ContentState

  var body: some View {
    if state.running {
      Text(timerInterval: state.since...Date.distantFuture, countsDown: false)
        .multilineTextAlignment(.trailing)
    } else {
      let minutes = Int(Date().timeIntervalSince(state.since) / 60)
      Text("\(minutes / 60)시간 \(minutes % 60)분")
    }
  }
}

/// 화면 방송으로 잰 스크롤 거리·광고 수. 잰 적 없는 날은 비운다
private struct FeedText: View {
  let state: ReceiptActivityAttributes.ContentState

  var body: some View {
    VStack(alignment: .trailing, spacing: 2) {
      if let m = state.meters { Text(String(format: "%.1fm", m)) }
      if let ads = state.ads { Text("광고 \(ads)개") }
    }
  }
}
