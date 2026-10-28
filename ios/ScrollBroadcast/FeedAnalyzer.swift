import Foundation

/// 문자 인식으로 읽은 한 줄. 좌표는 화면 대비 비율 (왼쪽 위가 0,0)
struct TextLine {
  let text: String
  let minX: Double
  let minY: Double
  let maxY: Double
}

/// 화면 방송 프레임에서 읽은 글을 보고 게시물/광고/추천/릴스/스크롤 거리를 센다.
/// 안드로이드 ScrollTrackerService.kt 의 분류 부분을 글자·위치 기준으로 옮긴 것.
/// 화면 글자는 저장하지 않고, 개수와 거리만 StatsStore 에 쌓는다.
final class FeedAnalyzer {
  private let store: StatsStore
  private var prev: [TextLine] = []
  private var lastReelAuthor: String?
  private var countedDay = ""

  /// 지금까지 내린 거리 (화면 높이 단위, 아래로 내리면 +). 같은 게시물인지 위치로 가릴 때 쓴다
  private var offset = 0.0

  /// 이미 센 게시물: 작성자 이름 → [(피드 안 위치, 분류)]
  private var seen: [String: [(pos: Double, kind: String)]] = [:]

  init(store: StatsStore) { self.store = store }

  /// 인스타그램 밖(다른 앱)에서는 이전 프레임을 버려서, 돌아왔을 때 화면 차이를 스크롤로 세지 않게 한다
  func reset() {
    prev = []
    lastReelAuthor = nil
  }

  func analyze(_ lines: [TextLine], screenMeters: Double) {
    let day = store.dayKey()
    if day != countedDay {
      countedDay = day
      seen = [:]
      lastReelAuthor = nil
    }

    let isReels = lines.contains { $0.minY < 0.1 && InstaOCRRules.matches($0.text, InstaOCRRules.reelsTabLabels) }
    if isReels {
      classifyReel(lines, screenMeters: screenMeters)
    } else {
      lastReelAuthor = nil
      addScroll(lines, screenMeters: screenMeters)
      classifyFeed(lines)
    }
    prev = lines
  }

  // ───────── 스크롤 거리 ─────────

  /// 앞 프레임과 같은 글줄이 얼마나 위로 밀렸는지로 스크롤 양을 잰다.
  /// 위쪽 앱 바·탭 바처럼 고정된 글은 안 움직이므로 움직인 줄만 본다
  private func addScroll(_ lines: [TextLine], screenMeters: Double) {
    var moved: [Double] = []
    for cur in lines {
      guard let p = prev.first(where: { $0.text == cur.text && abs($0.minX - cur.minX) < 0.02 }) else { continue }
      let dy = p.minY - cur.minY
      if abs(dy) > 0.003 { moved.append(dy) }
    }
    guard moved.count >= 2 else { return }
    moved.sort()
    let median = moved[moved.count / 2]
    // 같은 글이 화면에 두 번 있으면 엉뚱한 줄끼리 짝지어질 수 있다. 절반 이상이 같은 만큼 움직였을 때만 믿는다
    let agree = moved.filter { abs($0 - median) < 0.01 }.count
    guard agree * 2 >= moved.count else { return }
    offset += median
    store.addMeters(abs(median) * screenMeters)
  }

  // ───────── 피드 게시물 ─────────

  private func classifyFeed(_ lines: [TextLine]) {
    let names = lines.filter {
      InstaOCRRules.isUsername($0.text)
        && InstaOCRRules.headerMinX.contains($0.minX)
        && InstaOCRRules.feedY.contains($0.minY)
    }
    for h in names {
      // 스토리 줄은 같은 높이에 이름이 여러 개 있다. 게시물 헤더가 아니다
      if names.contains(where: { $0.text != h.text && abs($0.minY - h.minY) < 0.01 }) { continue }
      let kind = kindOf(header: h, lines)
      count(author: h.text, pos: offset + h.minY, kind: kind)
    }
  }

  /// 헤더 줄과 그 바로 아래(광고 표시), 위(추천 표시)만 보고 분류한다
  private func kindOf(header h: TextLine, _ lines: [TextLine]) -> String {
    let band = lines.filter {
      $0.minY >= h.minY - 0.005 && $0.minY <= h.maxY + InstaOCRRules.headerBandBelow && $0.minX >= h.minX - 0.02
    }
    if band.contains(where: { InstaOCRRules.matches($0.text, InstaOCRRules.adLabels) }) { return "ads" }
    if band.contains(where: { InstaOCRRules.matches($0.text, InstaOCRRules.followLabels) }) { return "suggestedPosts" }
    let above = lines.filter { $0.maxY <= h.minY && $0.maxY >= h.minY - InstaOCRRules.suggestedAbove }
    if above.contains(where: { InstaOCRRules.matches($0.text, InstaOCRRules.suggestedLabels) }) { return "suggestedPosts" }
    return "friendPosts"
  }

  private func count(author: String, pos: Double, kind: String) {
    var list = seen[author] ?? []
    if let i = list.firstIndex(where: { abs($0.pos - pos) < InstaOCRRules.samePostDistance }) {
      let before = list[i].kind
      // 광고/추천 표시는 헤더보다 늦게 읽힐 때가 있다. 친구 게시물로 셌던 것만 옮겨 센다
      if before == kind || before != "friendPosts" { return }
      list[i].kind = kind
      store.add(before, -1)
    } else {
      list.append((pos, kind))
      if list.count > 20 { list.removeFirst() }
    }
    seen[author] = list
    store.add(kind)
  }

  // ───────── 릴스 ─────────

  /// 아래쪽 작성자 이름이 바뀌면 새 릴스. 릴스는 한 번에 한 화면씩 넘어가므로 화면 높이만큼 거리를 더한다
  private func classifyReel(_ lines: [TextLine], screenMeters: Double) {
    guard let author = lines.first(where: {
      InstaOCRRules.isUsername($0.text) && $0.minY > InstaOCRRules.reelAuthorMinY && $0.minX < InstaOCRRules.reelAuthorMaxX
    })?.text, author != lastReelAuthor else { return }
    let first = lastReelAuthor == nil
    lastReelAuthor = author
    // 릴스 광고 표시는 작성자 옆이 아니라 화면 아래쪽에 따로 뜬다. 화면 전체에서 찾는다
    let isAd = lines.contains { InstaOCRRules.matches($0.text, InstaOCRRules.adLabels) }
    store.add(isAd ? "ads" : "reels")
    if !first { store.addMeters(screenMeters) }
  }
}
