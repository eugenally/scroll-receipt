import 'package:flutter/services.dart';

import '../models/receipt_data.dart';
import '../models/scrap.dart';

/// 안드로이드 네이티브(접근성 서비스)와 통신하는 채널.
class TrackerChannel {
  static const _ch = MethodChannel('scroll_receipt/tracker');

  /// 오늘 기록을 가져온다.
  static Future<ReceiptData> today() async {
    final m = await _ch.invokeMethod<Map<dynamic, dynamic>>('getToday');
    if (m == null) return ReceiptData(date: DateTime.now(), usage: Duration.zero);
    return ReceiptData.fromMap(m);
  }

  /// 접근성 서비스가 켜져 있는지
  static Future<bool> isServiceEnabled() async =>
      await _ch.invokeMethod<bool>('isServiceEnabled') ?? false;

  /// 접근성 설정 화면 열기
  static Future<void> openAccessibilitySettings() =>
      _ch.invokeMethod('openAccessibilitySettings');

  /// 저장한 스크랩 (최근 것부터)
  static Future<List<Scrap>> scraps() async {
    final list = await _ch.invokeMethod<List<dynamic>>('getScraps') ?? const [];
    return list.map((m) => Scrap.fromMap(m as Map<dynamic, dynamic>)).toList();
  }

  /// 스크랩 하나 지우기
  static Future<void> deleteScrap(int id) =>
      _ch.invokeMethod('deleteScrap', {'id': id});

  /// 오늘 기록 초기화 (테스트용)
  static Future<void> resetToday() => _ch.invokeMethod('resetToday');

  /// 앱을 뒤로 보내 직전 앱(인스타그램)이 다시 보이게 한다.
  static Future<void> backToPreviousApp() async {
    try {
      await _ch.invokeMethod('moveTaskToBack');
    } catch (_) {}
  }

  /// 앱이 플로팅 버튼을 눌러서 열렸는지 (true 면 바로 영수증 화면)
  static Future<bool> launchedFromBubble() async =>
      await _ch.invokeMethod<bool>('launchedFromBubble') ?? false;

  /// 네이티브 쪽에서 "영수증 열어줘" 신호를 보낼 때 (앱이 이미 켜져 있을 때)
  static void onShowReceipt(void Function() handler) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'showReceipt') handler();
    });
  }
}
