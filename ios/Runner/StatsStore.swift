import Foundation

/// 하루치 기록을 App Group 공유 UserDefaults 에 저장한다. 서버 전송 없음.
/// 안드로이드 StatsStore.kt 와 같은 키 형식: "2026-10-28.ads" 처럼 날짜 + 항목.
/// 앱과 (나중에 붙일) 화면 방송·위젯 확장이 같은 저장소를 보도록 App Group 을 쓴다.
final class StatsStore {
  static let appGroup = "group.com.eugenally.scrollReceipt"

  // App Group 이 서명에 없으면 nil → 앱 전용 저장소로 대신 (확장과는 공유 안 됨)
  private let prefs = UserDefaults(suiteName: StatsStore.appGroup) ?? .standard

  private static let dayFormat: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  private static let isoFormat: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return f
  }()

  static func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
  private func dayStr(_ ms: Int64) -> String {
    StatsStore.dayFormat.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
  }
  private func todayStr() -> String { dayStr(StatsStore.nowMs()) }
  private func key(_ name: String) -> String { "\(todayStr()).\(name)" }

  /// 오늘 날짜 ("2026-10-28"). 날이 바뀌었는지 확인할 때 쓴다
  func dayKey() -> String { todayStr() }

  private func startOfDay(_ ms: Int64) -> Int64 {
    let d = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: Double(ms) / 1000))
    return Int64(d.timeIntervalSince1970 * 1000)
  }

  private func nextMidnight(_ ms: Int64) -> Int64 {
    let start = Date(timeIntervalSince1970: Double(startOfDay(ms)) / 1000)
    let next = Calendar.current.date(byAdding: .day, value: 1, to: start)!
    return Int64(next.timeIntervalSince1970 * 1000)
  }

  private func long(_ k: String) -> Int64 { Int64(prefs.integer(forKey: k)) }

  func add(_ name: String, _ n: Int = 1) {
    prefs.set(prefs.integer(forKey: key(name)) + n, forKey: key(name))
    markFeedMeasured()
  }

  func addMeters(_ m: Double) {
    let k = key("scrollMm")
    prefs.set(long(k) + Int64(m * 1000), forKey: k)
    markFeedMeasured()
  }

  func count(_ name: String) -> Int { prefs.integer(forKey: key(name)) }

  func meters() -> Double { Double(long(key("scrollMm"))) / 1000 }

  /// 아이폰은 화면 방송을 켠 날에만 개수·거리를 잴 수 있다. 잰 날만 영수증에 숫자를 싣는다
  private func markFeedMeasured() { prefs.set(true, forKey: key("feedMeasured")) }
  func feedMeasured() -> Bool { prefs.bool(forKey: key("feedMeasured")) }

  // ── 이용 시간: 세션 시작 시각을 저장해 두고, 끝날 때 날짜별로 누적 ──

  /// 단축어 "닫힐 때" 자동화가 빠지면 세션이 끝나지 않는다. 한 세션은 이 길이까지만 센다
  static let maxSessionMs: Int64 = 3 * 60 * 60 * 1000

  /// 세션이 실제로 끝났다고 볼 시각 (지금, 또는 최대 길이에서 자른 시각)
  private func cappedEnd(_ start: Int64, _ end: Int64) -> Int64 {
    min(end, start + StatsStore.maxSessionMs)
  }

  /// 단축어 자동화가 한 번이라도 돌았는지 (홈 화면 "측정 중" 표시용)
  func noteAutomation() { prefs.set(StatsStore.nowMs(), forKey: "automationAt") }
  func automationSeen() -> Bool { long("automationAt") != 0 }

  /// 인스타그램이 지금 열려 있는지 (단축어 "열릴 때"~"닫힐 때" 사이)
  func sessionOpen() -> Bool { long("sessionStart") != 0 }

  // ── 화면 방송: 확장이 켜졌는지와 마지막으로 프레임을 받은 시각 ──
  func setBroadcasting(_ on: Bool) {
    prefs.set(on, forKey: "broadcasting")
    heartbeat()
  }

  func heartbeat() { prefs.set(StatsStore.nowMs(), forKey: "broadcastAt") }

  /// 확장이 죽으면 꺼짐 표시를 못 남기므로, 최근 10초 안에 프레임을 받았는지도 본다
  func isBroadcasting() -> Bool {
    prefs.bool(forKey: "broadcasting") && StatsStore.nowMs() - long("broadcastAt") < 10_000
  }

  func startSession() {
    // 이전 세션이 끝나지 않은 채 최대 길이를 넘겼으면 닫고 새로 시작한다
    let open = long("sessionStart")
    if open != 0 && StatsStore.nowMs() >= open + StatsStore.maxSessionMs { endSession() }
    if long("sessionStart") == 0 {
      let now = StatsStore.nowMs()
      prefs.set(now, forKey: "sessionStart")
      prefs.set(now, forKey: "lastActive")
    }
  }

  /// 인스타그램에서 활동이 있을 때 (몇 초에 한 번) 마지막 활동 시각을 남긴다
  func touch() {
    prefs.set(StatsStore.nowMs(), forKey: "lastActive")
  }

  /// 세션을 끝내고 이용 시간을 쌓는다. 자정을 넘긴 세션은 날짜별로 나눠 쌓는다
  func endSession(end: Int64 = StatsStore.nowMs()) {
    var start = long("sessionStart")
    if start == 0 { return }
    let end = cappedEnd(start, end)
    while start < end {
      let cut = min(nextMidnight(start), end)
      let k = "\(dayStr(start)).usageMs"
      prefs.set(long(k) + (cut - start), forKey: k)
      start = cut
    }
    prefs.set(0, forKey: "sessionStart")
  }

  /// 측정 중에 앱이나 확장이 죽으면 세션 시작 시각만 남는다.
  /// 다음에 시작할 때 마지막 활동 시각에서 그 세션을 끝내, 그 사이 시간이 쌓이지 않게 한다.
  func endStaleSession() {
    let start = long("sessionStart")
    if start == 0 { return }
    endSession(end: max(start, long("lastActive")))
  }

  func usageMs() -> Int64 {
    let start = long("sessionStart")
    let now = StatsStore.nowMs()
    // 진행 중인 세션은 오늘 0시 이후 부분만 오늘 이용 시간에 더한다
    let live = start == 0 ? 0 : max(0, cappedEnd(start, now) - max(start, startOfDay(now)))
    return long(key("usageMs")) + live
  }

  /// 첫날부터 지금까지 쌓인 이용 시간 전부 ("총 소비한 인생")
  func totalUsageMs() -> Int64 {
    let start = long("sessionStart")
    let live = start == 0 ? 0 : cappedEnd(start, StatsStore.nowMs()) - start
    let stored = prefs.dictionaryRepresentation()
      .filter { $0.key.hasSuffix(".usageMs") }
      .reduce(Int64(0)) { $0 + (($1.value as? NSNumber)?.int64Value ?? 0) }
    return stored + live
  }

  /// 화면 방송을 켜지 않은 날은 개수·거리를 null 로 보내, 영수증이 드립 문구로 대신하게 한다
  func today() -> [String: Any] {
    let measured = feedMeasured()
    // 채널로는 nil 대신 NSNull 을 보내야 Dart 에서 null 이 된다
    func ifMeasured(_ v: Any) -> Any { measured ? v : NSNull() }
    return [
      "date": StatsStore.isoFormat.string(from: Date()),
      "usageMs": usageMs(),
      "totalUsageMs": totalUsageMs(),
      "scrollMeters": ifMeasured(meters()),
      "friendPosts": ifMeasured(count("friendPosts")),
      "suggestedPosts": ifMeasured(count("suggestedPosts")),
      "ads": ifMeasured(count("ads")),
      "reels": ifMeasured(count("reels")),
      // 화면만 보는 아이폰은 좋아요 누른 걸 알 수 없다
      "likes": NSNull(),
    ]
  }

  func resetToday() {
    let prefix = "\(todayStr())."
    prefs.dictionaryRepresentation().keys
      .filter { $0.hasPrefix(prefix) }
      .forEach { prefs.removeObject(forKey: $0) }
    prefs.set(0, forKey: "sessionStart")
  }
}
