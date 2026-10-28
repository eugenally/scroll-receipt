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

  static func isUsername(_ s: String) -> Bool {
    username.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
  }

  static func matches(_ s: String, _ labels: [String]) -> Bool {
    labels.contains { s.caseInsensitiveCompare($0) == .orderedSame }
  }
}
