import AppIntents

/// 단축어 개인 자동화 "Instagram이 열릴 때"에 넣는 동작. 이용 시간 세션을 시작한다.
/// 아이폰은 다른 앱이 켜졌는지 알 수 없어서, 단축어가 대신 알려 준다.
struct StartInstagramIntent: AppIntent {
  static let title: LocalizedStringResource = "인스타그램 시작 기록"
  static let description = IntentDescription("인스타그램을 연 시각을 기록해 이용 시간을 재기 시작합니다.")
  static let openAppWhenRun = false

  func perform() async throws -> some IntentResult {
    let store = StatsStore()
    store.noteAutomation()
    store.startSession()
    return .result()
  }
}

/// 단축어 개인 자동화 "Instagram이 닫힐 때"에 넣는 동작. 세션을 끝내고 이용 시간을 쌓는다.
struct EndInstagramIntent: AppIntent {
  static let title: LocalizedStringResource = "인스타그램 종료 기록"
  static let description = IntentDescription("인스타그램을 닫은 시각까지의 이용 시간을 오늘 기록에 더합니다.")
  static let openAppWhenRun = false

  func perform() async throws -> some IntentResult {
    let store = StatsStore()
    store.noteAutomation()
    store.endSession()
    return .result()
  }
}
