import ReplayKit
import UIKit
import Vision
import os

/// 화면 방송 확장. 사용자가 방송을 켠 동안 화면 프레임을 받아 기기 안에서 글자를 읽고,
/// 인스타그램을 보는 중일 때만 FeedAnalyzer 로 개수·거리를 센다.
/// 프레임은 저장하지 않는다. 읽은 글은 최근 몇 초 것만 메모리에 들고 있다가,
/// 사용자가 ✂️ 스크랩을 눌렀을 때만 문장 후보로 App Group 에 넘긴다. 밖으로는 보내지 않는다.
final class SampleHandler: RPBroadcastSampleHandler {
  private let store = StatsStore()
  private let scraps = ScrapStore()
  private lazy var analyzer = FeedAnalyzer(store: store)
  private let log = Logger(subsystem: "com.eugenally.scrollReceipt", category: "ScrollBroadcast")
  private var lastFrameAt: CFTimeInterval = 0

  /// 최근 인스타그램 화면에서 읽은 글 (스크랩 후보용). 0.5초에 한 장 × 10 = 약 5초
  private var recent: [(at: Int64, lines: [TextLine])] = []

  /// 화면 전체 높이의 실제 길이 (m)
  private let screenMeters = Double(UIScreen.main.bounds.height) / InstaOCRRules.pointsPerInch * 0.0254

  override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
    store.setBroadcasting(true)
  }

  override func broadcastFinished() {
    store.setBroadcasting(false)
  }

  override func broadcastPaused() {
    analyzer.reset()
  }

  // ReplayKit 이 한 번에 하나씩 부른다. 여기서 바로 읽는 동안 들어온 프레임은 버려진다
  override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with type: RPSampleBufferType) {
    guard type == .video else { return }
    let now = CACurrentMediaTime()
    guard now - lastFrameAt >= InstaOCRRules.frameInterval else { return }
    lastFrameAt = now
    store.heartbeat()
    answerScrapRequest()

    // 인스타그램이 열려 있는지는 단축어 자동화(2단계)가 남긴 세션으로 안다
    guard store.sessionOpen() else { return analyzer.reset() }
    guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    store.touch()

    let lines = recognize(pixels, orientation: orientation(of: sampleBuffer))
    // InstaOCRRules 조정용: Mac 의 Console 앱에서 "ScrollBroadcast" 로 걸러 본다 (디버그 로그라 기기에 남지 않음)
    let dump = lines.map { "\(String(format: "%.3f,%.3f", $0.minX, $0.minY)) \($0.text)" }.joined(separator: " | ")
    log.debug("\(dump, privacy: .public)")
    analyzer.analyze(lines, screenMeters: screenMeters)
    recent.append((StatsStore.nowMs(), lines))
    if recent.count > 10 { recent.removeFirst() }
  }

  /// ✂️ 스크랩 요청이 있으면 누르기 직전 인스타그램 화면의 글로 답한다.
  /// 다이내믹 아일랜드를 길게 눌러 펼치는 동안의 화면은 위쪽이 가려지므로, 요청보다 조금 앞선 화면을 고른다
  private func answerScrapRequest() {
    guard let at = scraps.pendingRequest() else { return }
    let frame = recent.last(where: { $0.at <= at - 800 }) ?? recent.first
    let (pieces, author) = InstaOCRRules.scrapPieces(frame?.lines ?? [])
    scraps.answer(at, pieces: pieces, author: author)
    recent = []
  }

  private func orientation(of buffer: CMSampleBuffer) -> CGImagePropertyOrientation {
    let raw = CMGetAttachment(buffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber
    return raw.flatMap { CGImagePropertyOrientation(rawValue: $0.uint32Value) } ?? .up
  }

  private func recognize(_ pixels: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> [TextLine] {
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = InstaOCRRules.accurateRecognition ? .accurate : .fast
    req.recognitionLanguages = ["ko-KR", "en-US"]
    req.usesLanguageCorrection = false
    do {
      try VNImageRequestHandler(cvPixelBuffer: pixels, orientation: orientation).perform([req])
    } catch {
      return []
    }
    return (req.results ?? []).compactMap { obs in
      guard let s = obs.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces), !s.isEmpty
      else { return nil }
      // Vision 좌표는 왼쪽 아래가 0,0 이라 위아래를 뒤집는다
      let b = obs.boundingBox
      return TextLine(text: s, minX: Double(b.minX), minY: Double(1 - b.maxY), maxY: Double(1 - b.minY))
    }
  }
}
