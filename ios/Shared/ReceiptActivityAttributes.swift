import ActivityKit
import Foundation

/// 다이내믹 아일랜드·잠금 화면에 띄우는 🧾 Live Activity 의 내용.
/// 앱(Runner)이 띄우고 고치며, 위젯 확장(ReceiptWidget)이 그린다. 두 타깃이 이 파일을 같이 쓴다.
struct ReceiptActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// 오늘 이용 시간이 0이었던 것으로 치는 시각. 지금 - since = 오늘 이용 시간이라,
    /// 위젯이 갱신 없이도 타이머로 시간을 계속 올린다
    var since: Date

    /// 인스타그램을 보는 중인지 (아니면 시간을 멈춰서 보여 준다)
    var running: Bool

    /// 화면 방송으로 잰 날만 값이 있다
    var meters: Double?
    var ads: Int?
  }

  /// 🧾 를 누르면 여는 주소. 앱은 이 주소로 열리면 바로 영수증 화면을 띄운다
  static let receiptURL = URL(string: "scrollreceipt://receipt")!

  /// ✂️ 스크랩을 누르면 여는 주소. 앱은 화면 방송 확장에게 방금 화면의 글을 받아 문장 고르기 화면을 띄운다
  static let scrapURL = URL(string: "scrollreceipt://scrap")!
}
