import ReplayKit
import UIKit
import Vision
import os

/// 화면 방송 확장. 사용자가 방송을 켠 동안 화면 프레임을 받아 기기 안에서 글자를 읽고,
/// 인스타그램을 보는 중일 때만 FeedAnalyzer 로 개수·거리를 센다.
/// 프레임과 읽은 글은 저장하거나 밖으로 보내지 않는다.
final class SampleHandler: RPBroadcastSampleHandler {
  private let store = StatsStore()
  private lazy var analyzer = FeedAnalyzer(store: store)
  private let log = Logger(subsystem: "com.eugenally.scrollReceipt", category: "ScrollBroadcast")
  private var lastFrameAt: CFTimeInterval = 0

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

    // 인스타그램이 열려 있는지는 단축어 자동화(2단계)가 남긴 세션으로 안다
    guard store.sessionOpen() else { return analyzer.reset() }
    guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    store.touch()

    let lines = recognize(pixels, orientation: orientation(of: sampleBuffer))
    // InstaOCRRules 조정용: Mac 의 Console 앱에서 "ScrollBroadcast" 로 걸러 본다 (디버그 로그라 기기에 남지 않음)
    let dump = lines.map { "\(String(format: "%.3f,%.3f", $0.minX, $0.minY)) \($0.text)" }.joined(separator: " | ")
    log.debug("\(dump, privacy: .public)")
    analyzer.analyze(lines, screenMeters: screenMeters)
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
