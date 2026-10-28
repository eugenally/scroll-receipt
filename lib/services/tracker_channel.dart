import 'package:flutter/services.dart';

import '../models/receipt_data.dart';
import '../models/scrap.dart';

/// 네이티브와 통신하는 채널. 안드로이드는 MainActivity.kt(접근성 서비스),
/// 아이폰은 ios/Runner/TrackerChannel.swift 가 같은 메서드 이름으로 답한다.
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

  /// (아이폰) 화면 방송 확장이 지금 프레임을 받고 있는지
  static Future<bool> isBroadcasting() async =>
      await _ch.invokeMethod<bool>('isBroadcasting') ?? false;

  /// (아이폰) 화면 방송 시작 창 띄우기
  static Future<void> startBroadcast() => _ch.invokeMethod('startBroadcast');

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

  /// (아이폰) 🧾 Live Activity 로 열렸으면 'receipt' 또는 'scrap', 아니면 null
  static Future<String?> launchTarget() => _ch.invokeMethod<String>('launchTarget');

  /// (아이폰) 화면 방송 확장이 넘겨준 스크랩 후보.
  /// 아직 안 왔으면 pieces 가 null 이고, broadcasting 으로 방송이 켜져 있는지 알려 준다
  static Future<Map<dynamic, dynamic>> scrapCandidates() async =>
      await _ch.invokeMethod<Map<dynamic, dynamic>>('getScrapCandidates') ?? const {};

  /// (아이폰) 고른 문장 저장. 안드로이드는 스크랩 창(ScrapSheet.kt)이 직접 저장한다
  static Future<void> addScrap(String text, String? author) =>
      _ch.invokeMethod('addScrap', {'text': text, 'author': author});

  /// 네이티브 쪽에서 "영수증 열어줘" / (아이폰) "스크랩 문장 고르기 열어줘" 신호를 보낼 때 (앱이 이미 켜져 있을 때)
  static void onShowReceipt(void Function() handler, {void Function()? onShowScrapPicker}) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'showReceipt') handler();
      if (call.method == 'showScrapPicker') onShowScrapPicker?.call();
    });
  }
}
