import Flutter
import UIKit

/// Dart 의 TrackerChannel 과 통신하는 채널. 안드로이드 MainActivity.kt 와 같은 메서드 이름을 쓴다.
/// 아이폰은 단축어 자동화로 이용 시간만 잰다. "측정 중"은 그 자동화가 돌았는지로 본다.
final class TrackerChannel {
  static let name = "scroll_receipt/tracker"

  private let channel: FlutterMethodChannel
  private let store = StatsStore()
  private let scraps = ScrapStore()

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: TrackerChannel.name, binaryMessenger: messenger)
    // 단축어 동작을 실행하려고 앱이 뒤에서 켜질 때도 여기를 지나므로, 진행 중인 세션을 끝내지 않는다
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      self.handle(call, result)
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "getToday": result(store.today())
    case "isServiceEnabled": result(store.automationSeen())
    case "openAccessibilitySettings":
      // 아이폰엔 접근성 서비스가 없다. 대신 자동화를 만들 단축어 앱을 연다
      if let url = URL(string: "shortcuts://") {
        UIApplication.shared.open(url)
      }
      result(nil)
    case "resetToday": store.resetToday(); result(nil)
    case "getScraps": result(scraps.all())
    case "deleteScrap":
      let id = ((call.arguments as? [String: Any])?["id"] as? NSNumber)?.int64Value ?? 0
      scraps.delete(id: id)
      result(nil)
    // TODO(iOS 4단계): Live Activity 버튼으로 열렸는지
    case "launchedFromBubble": result(false)
    // 아이폰은 앱이 스스로 직전 앱으로 돌아갈 수 없다
    case "moveTaskToBack": result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }
}
