import ActivityKit
import Foundation

/// 안드로이드 플로팅 🧾 버튼 대신 띄우는 Live Activity 를 켜고 끈다.
/// 단축어 동작(LiveActivityIntent)이 인스타그램을 열 때 띄우고 닫을 때 내린다.
enum ReceiptActivity {
  private static func state(_ store: StatsStore) -> ReceiptActivityAttributes.ContentState {
    let measured = store.feedMeasured()
    return .init(
      since: Date().addingTimeInterval(-Double(store.usageMs()) / 1000),
      running: store.sessionOpen(),
      meters: measured ? store.meters() : nil,
      ads: measured ? store.count("ads") : nil
    )
  }

  /// 세션이 끝나지 않아도 최대 길이가 지나면 낡은 정보로 표시한다
  private static var staleDate: Date {
    Date().addingTimeInterval(Double(StatsStore.maxSessionMs) / 1000)
  }

  /// 이미 떠 있으면 내용만 고치고, 없으면 새로 띄운다
  static func show(_ store: StatsStore) async {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let content = ActivityContent(state: state(store), staleDate: staleDate)
    if let current = Activity<ReceiptActivityAttributes>.activities.first {
      await current.update(content)
    } else {
      _ = try? Activity.request(attributes: ReceiptActivityAttributes(), content: content, pushType: nil)
    }
  }

  /// 오늘 기록을 마지막으로 보여 주고 바로 내린다
  static func hide(_ store: StatsStore) async {
    let content = ActivityContent(state: state(store), staleDate: nil)
    for activity in Activity<ReceiptActivityAttributes>.activities {
      await activity.end(content, dismissalPolicy: .immediate)
    }
  }
}
