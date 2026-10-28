import Flutter
import ReplayKit
import UIKit

/// Dart 의 TrackerChannel 과 통신하는 채널. 안드로이드 MainActivity.kt 와 같은 메서드 이름을 쓴다.
/// 아이폰은 단축어 자동화로 이용 시간을, 화면 방송 확장(ScrollBroadcast)으로 개수·거리를 잰다.
/// "측정 중"은 단축어 자동화가 돌았는지로 본다.
final class TrackerChannel {
  static let name = "scroll_receipt/tracker"
  static let broadcastExtension = "com.eugenally.scrollReceipt.ScrollBroadcast"

  /// 🧾 Live Activity 를 눌러 앱이 열렸을 때 SceneDelegate 가 찾아 쓴다
  private(set) static weak var shared: TrackerChannel?

  private let channel: FlutterMethodChannel

  /// 🧾 Live Activity 에서 연 화면
  enum Target: String { case receipt, scrap }

  /// 🧾 로 열렸는데 Dart 가 아직 launchTarget 을 묻지 않은 경우.
  /// 앱이 막 켜질 때는 채널보다 주소가 먼저 올 수 있어 static 으로 둔다
  private static var pending: Target?
  private var dartAsked = false
  private let store = StatsStore()
  private let scraps = ScrapStore()

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: TrackerChannel.name, binaryMessenger: messenger)
    // 단축어 동작을 실행하려고 앱이 뒤에서 켜질 때도 여기를 지나므로, 진행 중인 세션을 끝내지 않는다
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      self.handle(call, result)
    }
    TrackerChannel.shared = self
  }

  /// 🧾 Live Activity 를 눌렀을 때. 앱이 막 켜졌으면 Dart 가 시작할 때 묻도록 남겨 두고,
  /// 이미 켜져 있었으면 바로 그 화면을 띄우게 한다 (안드로이드 onNewIntent 와 같은 흐름)
  static func open(_ target: Target) {
    // 스크랩은 화면 방송 확장에게 방금 본 화면의 글을 달라고 먼저 요청한다
    if target == .scrap { ScrapStore().requestCandidates() }
    if let ch = shared, ch.dartAsked {
      ch.channel.invokeMethod(target == .receipt ? "showReceipt" : "showScrapPicker", arguments: nil)
    } else {
      pending = target
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
    case "isBroadcasting": result(store.isBroadcasting())
    case "startBroadcast": showBroadcastPicker(); result(nil)
    case "resetToday": store.resetToday(); result(nil)
    case "getScraps": result(scraps.all())
    case "deleteScrap":
      let id = ((call.arguments as? [String: Any])?["id"] as? NSNumber)?.int64Value ?? 0
      scraps.delete(id: id)
      result(nil)
    case "launchedFromBubble":
      // 아이폰은 launchTarget 을 쓴다. 안드로이드와 같은 이름으로 묻는 경우를 위해 남겨 둔다
      result(TrackerChannel.pending == .receipt)
    case "launchTarget":
      dartAsked = true
      result(TrackerChannel.pending?.rawValue)
      TrackerChannel.pending = nil
    case "getScrapCandidates":
      // 확장이 아직 답하지 않았으면 null. 방송이 꺼져 있으면 답이 오지 않으므로 그것도 알려 준다
      var m = scraps.candidates() ?? [:]
      m["broadcasting"] = store.isBroadcasting()
      result(m)
    case "addScrap":
      let args = call.arguments as? [String: Any]
      if let text = args?["text"] as? String {
        scraps.add(text: text, author: args?["author"] as? String)
      }
      result(nil)
    // 아이폰은 앱이 스스로 직전 앱으로 돌아갈 수 없다
    case "moveTaskToBack": result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  /// 화면 방송은 사용자가 시스템 창에서 직접 시작해야 한다.
  /// 시스템 방송 버튼을 화면에 잠깐 붙여 눌러서, 우리 확장이 골라진 "방송 시작" 창을 띄운다
  private func showBroadcastPicker() {
    let window = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }
      .first
    let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    picker.preferredExtension = TrackerChannel.broadcastExtension
    picker.showsMicrophoneButton = false
    picker.alpha = 0.01   // 숨기면(isHidden) 눌리지 않는 경우가 있다
    window?.addSubview(picker)
    for case let button as UIButton in picker.subviews {
      button.sendActions(for: .allTouchEvents)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { picker.removeFromSuperview() }
  }
}
