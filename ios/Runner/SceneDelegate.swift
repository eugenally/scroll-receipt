import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// 앱이 꺼져 있을 때 🧾 Live Activity 를 눌러 켜진 경우
  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    connectionOptions.urlContexts.forEach { open($0.url) }
  }

  /// 앱이 이미 켜져 있을 때 🧾 Live Activity 를 누른 경우
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    URLContexts.forEach { open($0.url) }
  }

  /// scrollreceipt://receipt → 영수증, scrollreceipt://scrap → 스크랩 문장 고르기
  private func open(_ url: URL) {
    switch url {
    case ReceiptActivityAttributes.receiptURL: TrackerChannel.open(.receipt)
    case ReceiptActivityAttributes.scrapURL: TrackerChannel.open(.scrap)
    default: break
    }
  }
}
