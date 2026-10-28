import 'dart:io';

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/receipt_screen.dart';
import 'screens/scrap_pick_screen.dart';
import 'services/tracker_channel.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 아이폰은 🧾 Live Activity 에서 영수증 또는 스크랩으로 열린다
  String? target;
  try {
    target = Platform.isIOS
        ? await TrackerChannel.launchTarget()
        : (await TrackerChannel.launchedFromBubble() ? 'receipt' : null);
  } catch (_) {}

  // 앱이 이미 켜져 있는 상태에서 플로팅 버튼을 누른 경우
  TrackerChannel.onShowReceipt(
    () => navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const ReceiptScreen()),
    ),
    onShowScrapPicker: () => navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const ScrapPickScreen()),
    ),
  );

  runApp(ScrollReceiptApp(startWith: target));
}

class ScrollReceiptApp extends StatelessWidget {
  /// 'receipt' / 'scrap' 이면 홈 대신 그 화면부터
  final String? startWith;
  const ScrollReceiptApp({super.key, this.startWith});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '스크롤 영수증',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFE1306C),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: switch (startWith) {
        'receipt' => const ReceiptScreen(),
        'scrap' => const ScrapPickScreen(),
        _ => const HomeScreen(),
      },
    );
  }
}
