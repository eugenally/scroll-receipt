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
}
