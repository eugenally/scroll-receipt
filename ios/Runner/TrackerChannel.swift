import Flutter
import UIKit

/// Dart 의 TrackerChannel 과 통신하는 채널. 안드로이드 MainActivity.kt 와 같은 메서드 이름을 쓴다.
/// 아이폰은 아직 측정 수단이 없어서 측정 관련 메서드는 "꺼져 있음"으로 답한다.
final class TrackerChannel {
  static let name = "scroll_receipt/tracker"

  private let channel: FlutterMethodChannel
  private let store = StatsStore()
  private let scraps = ScrapStore()

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: TrackerChannel.name, binaryMessenger: messenger)
    store.endStaleSession()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      self.handle(call, result)
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "getToday": result(store.today())
    // TODO(iOS 2·3단계): 단축어 자동화 / 화면 방송이 켜져 있는지로 바꾼다
    case "isServiceEnabled": result(false)
    case "openAccessibilitySettings":
      // 아이폰엔 접근성 서비스가 없다. 우선 이 앱의 설정 화면을 연다
      if let url = URL(string: UIApplication.openSettingsURLString) {
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
