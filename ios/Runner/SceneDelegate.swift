import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// 앱이 꺼져 있을 때 🧾 Live Activity 를 눌러 켜진 경우
  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if connectionOptions.urlContexts.contains(where: { isReceiptURL($0.url) }) {
      TrackerChannel.openReceipt()
    }
  }

  /// 앱이 이미 켜져 있을 때 🧾 Live Activity 를 누른 경우
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    if URLContexts.contains(where: { isReceiptURL($0.url) }) {
      TrackerChannel.openReceipt()
    }
  }

  private func isReceiptURL(_ url: URL) -> Bool {
    url.scheme == ReceiptActivityAttributes.receiptURL.scheme && url.host == ReceiptActivityAttributes.receiptURL.host
  }
}
