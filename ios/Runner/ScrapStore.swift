import Foundation

/// 사용자가 직접 고른 게시물 글귀를 App Group UserDefaults 에 JSON 배열로 저장한다. 서버 전송 없음.
/// 안드로이드 ScrapStore.kt 와 같은 형식 ({id, text, author, savedAt}).
final class ScrapStore {
  private static let key = "scraps.items"

  private let prefs = UserDefaults(suiteName: StatsStore.appGroup) ?? .standard

  private func load() -> [[String: Any]] {
    guard let s = prefs.string(forKey: ScrapStore.key),
          let arr = try? JSONSerialization.jsonObject(with: Data(s.utf8)) as? [[String: Any]]
    else { return [] }
    return arr
  }

  private func save(_ arr: [[String: Any]]) {
    guard let data = try? JSONSerialization.data(withJSONObject: arr) else { return }
    prefs.set(String(decoding: data, as: UTF8.self), forKey: ScrapStore.key)
  }

  func add(text: String, author: String?) {
    let now = StatsStore.nowMs()
    var arr = load()
    arr.append(["id": now, "text": text, "author": author ?? NSNull(), "savedAt": now])
    save(arr)
  }

  /// 최근에 저장한 것부터
  func all() -> [[String: Any]] { load().reversed() }

  func delete(id: Int64) {
    save(load().filter { ($0["id"] as? NSNumber)?.int64Value != id })
  }

  // ── 스크랩 후보: 앱이 요청하면 화면 방송 확장이 최근 인스타그램 화면의 글을 문장으로 나눠 남긴다 ──
  // 아이폰 앱은 다른 앱 화면을 못 읽어서, 화면을 보고 있는 확장과 App Group 으로 주고받는다.

  /// 앱: 🧾 의 ✂️ 스크랩을 눌렀을 때. 이전 후보는 지운다
  func requestCandidates() {
    prefs.removeObject(forKey: "scraps.candidates")
    prefs.set(StatsStore.nowMs(), forKey: "scraps.requestedAt")
  }

  /// 확장: 아직 답하지 않은 요청이 있으면 그 시각
  func pendingRequest() -> Int64? {
    let at = Int64(prefs.integer(forKey: "scraps.requestedAt"))
    return at != 0 && at > Int64(prefs.integer(forKey: "scraps.answeredAt")) ? at : nil
  }

  /// 확장: 요청에 답한다 (읽은 글이 없으면 빈 목록)
  func answer(_ requestedAt: Int64, pieces: [String], author: String?) {
    let obj: [String: Any] = ["requestedAt": requestedAt, "pieces": pieces, "author": author ?? NSNull()]
    guard let data = try? JSONSerialization.data(withJSONObject: obj) else { return }
    prefs.set(String(decoding: data, as: UTF8.self), forKey: "scraps.candidates")
    prefs.set(requestedAt, forKey: "scraps.answeredAt")
  }

  /// 앱: 확장이 답했으면 {pieces, author}, 아직이면 nil
  func candidates() -> [String: Any]? {
    guard let s = prefs.string(forKey: "scraps.candidates"),
          let obj = try? JSONSerialization.jsonObject(with: Data(s.utf8)) as? [String: Any]
    else { return nil }
    return obj
  }
}
