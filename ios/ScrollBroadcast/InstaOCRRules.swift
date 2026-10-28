import Foundation

/// 화면 방송 프레임의 문자 인식 결과로 인스타그램 게시물/광고/추천/릴스를 알아보는 기준.
/// 안드로이드 InstaSelectors.kt 의 아이폰판. 아이폰은 view id 가 없어서 글자와 위치만 본다.
///
/// 좌표는 화면 대비 비율 (0~1, 왼쪽 위가 0,0).
/// 숫자가 이상하면 Mac 의 Console 앱에서 "ScrollBroadcast" 로그(인식된 글과 위치)를 보고 여기를 고친다.
enum InstaOCRRules {
  /// 프레임을 몇 초에 한 장 읽을지. 짧을수록 빠른 스크롤도 잡지만 배터리·메모리를 더 쓴다
  static let frameInterval: Double = 0.5

  /// 한국어 표시("광고", "회원님을 위한 추천")는 정확 모드에서만 읽힌다
  static let accurateRecognition = true

  /// 화면 1pt 의 실제 길이를 재기 위한 값. 최근 아이폰은 대략 1인치에 153~163pt
  static let pointsPerInch: Double = 155

  /// 광고 표시 문구
  static let adLabels = ["Ad", "Sponsored", "광고", "Paid partnership", "유료 광고"]

  /// 팔로우하지 않은 계정 추천 표시 문구 (게시물 위에 뜬다)
  static let suggestedLabels = ["Suggested for you", "회원님을 위한 추천", "추천 게시물", "Suggested posts"]

  /// 팔로우하지 않은 계정의 게시물 헤더 오른쪽에 붙는 버튼
  static let followLabels = ["Follow", "팔로우"]

  /// 릴스 화면 맨 위의 탭 이름. 이게 위쪽에 보이면 릴스 화면으로 본다
  static let reelsTabLabels = ["Reels", "릴스"]

  /// 인스타그램 사용자 이름 (영문 소문자·숫자·마침표·밑줄)
  static let username = try! NSRegularExpression(pattern: "^[a-z0-9._]{2,30}$")

  /// 피드 게시물 헤더의 작성자 이름 위치: 프로필 사진 오른쪽.
  /// 캡션 앞의 작성자 이름은 사진이 없어 더 왼쪽에서 시작하므로 이 범위로 거른다
  static let headerMinX = 0.08...0.30

  /// 위쪽 앱 바·아래쪽 탭 바를 뺀 피드 영역
  static let feedY = 0.05...0.92

  /// 헤더 아래 몇 줄 안에 광고 표시가 뜬다 (작성자 이름 아래 거리)
  static let headerBandBelow = 0.035

  /// 게시물 위 몇 줄 안에 "회원님을 위한 추천"이 뜬다
  static let suggestedAbove = 0.10

  /// 릴스 작성자 이름 위치: 화면 아래쪽 왼편
  static let reelAuthorMinY = 0.70
  static let reelAuthorMaxX = 0.35

  /// 같은 작성자 이름이 이 거리(화면 높이 단위) 안에 다시 보이면 같은 게시물로 본다
  static let samePostDistance = 0.6

  // ───────── 스크랩 ─────────

  /// 접힌 캡션 끝에 붙는 "더 보기" 문구 (긴 것부터)
  private static let moreLabels = ["… 더 보기", "... 더 보기", "… more", "... more", "...more", "더 보기", "more"]

  /// 글이 아니라 버튼·표시 문구라 스크랩 후보에서 뺀다
  private static let uiLabels = adLabels + suggestedLabels + followLabels + reelsTabLabels + [
    "Following", "팔로잉", "Reply", "답글 달기", "See translation", "번역 보기",
    "Original audio", "원본 오디오", "Friends", "친구",
  ]

  /// 우리 🧾 Live Activity 에 쓰인 글. 다이내믹 아일랜드가 화면에 겹쳐 찍혔을 때 뺀다
  private static let ownLabels = ["영수증", "스크랩", "오늘 인스타그램"]

  /// "좋아요 1,234개", "12.3K", "3일 전" 같은 숫자·시간 표시
  private static let countOrTime = try! NSRegularExpression(
    pattern: #"^(좋아요|조회수|댓글)?\s*[\d,.]+\s*(만|천|[KkMm])?\s*(개|회|명|likes?|views?|comments?)?$"#
      + #"|^\d+\s*(초|분|시간|일|주)\s*전$|^\d+\s*(seconds?|minutes?|hours?|days?|weeks?)\s+ago$"#,
    options: [.caseInsensitive])

  private static let sentenceEnd = try! NSRegularExpression(pattern: #"(?<=[.!?。])\s+"#)

  /// 위쪽 상태 표시줄·아래쪽 탭 바는 글이 아니다
  private static let scrapY = 0.04...0.93

  /// 스크랩 버튼을 누르기 직전 화면에서 읽은 글을 고를 수 있는 문장 조각과 작성자로 나눈다.
  /// 안드로이드 InstaSelectors.scrapPieces 의 아이폰판. 문자 인식은 화면에 보이는 줄 단위라
  /// 같은 문단으로 이어지는 줄을 먼저 합친다.
  static func scrapPieces(_ lines: [TextLine]) -> (pieces: [String], author: String?) {
    let visible = lines
      .filter { scrapY.contains($0.minY) }
      .filter { l in !ownLabels.contains { l.text.contains($0) } }
      .sorted { ($0.minY, $0.minX) < ($1.minY, $1.minX) }

    // 화면 가운데를 차지한 게시물의 작성자: 가운데보다 위에 있는 작성자 중 가장 아래 것
    let authors = visible.filter {
      isUsername($0.text)
        && (headerMinX.contains($0.minX) || ($0.minY > reelAuthorMinY && $0.minX < reelAuthorMaxX))
    }
    let author = (authors.last { $0.minY <= 0.5 } ?? authors.first)?.text

    // 왼쪽이 맞고 바로 아래에 붙은 줄은 한 문단으로 잇는다
    var paragraphs: [String] = []
    var last: TextLine?
    for l in visible {
      if let p = last, abs(l.minX - p.minX) < 0.03, l.minY - p.maxY < (p.maxY - p.minY) * 0.6 {
        paragraphs[paragraphs.count - 1] += " " + l.text
      } else {
        paragraphs.append(l.text)
      }
      last = l
    }

    let authorPrefix = author.map { "\($0) " }
    var out: [String] = []
    for para in paragraphs {
      var t = para.trimmingCharacters(in: .whitespaces)
      for m in moreLabels where t.hasSuffix(m) {
        t = String(t.dropLast(m.count)).trimmingCharacters(in: .whitespaces)
      }
      // 캡션은 "작성자 본문" 형태라 앞의 작성자 이름을 뗀다
      if let pre = authorPrefix, t.hasPrefix(pre) { t = String(t.dropFirst(pre.count)) }
      let ns = t as NSString
      var start = 0
      var parts: [String] = []
      for m in sentenceEnd.matches(in: t, range: NSRange(location: 0, length: ns.length)) {
        parts.append(ns.substring(with: NSRange(location: start, length: m.range.location - start)))
        start = m.range.location + m.range.length
      }
      parts.append(ns.substring(from: start))
      for piece in parts {
        let s = piece.trimmingCharacters(in: .whitespaces)
        guard s.count >= 2, s.contains(where: \.isLetter), s != author,
              !matches(s, uiLabels),
              countOrTime.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) == nil,
              !out.contains(s)
        else { continue }
        out.append(s)
        if out.count >= 60 { return (out, author) }
      }
    }
    return (out, author)
  }

  static func isUsername(_ s: String) -> Bool {
    username.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
  }

  static func matches(_ s: String, _ labels: [String]) -> Bool {
    labels.contains { s.caseInsensitiveCompare($0) == .orderedSame }
  }
}
