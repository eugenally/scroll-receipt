import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/receipt_screen.dart';
import 'services/tracker_channel.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool fromBubble = false;
  try {
    fromBubble = await TrackerChannel.launchedFromBubble();
  } catch (_) {}

  // 앱이 이미 켜져 있는 상태에서 플로팅 버튼을 누른 경우
  TrackerChannel.onShowReceipt(() {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const ReceiptScreen()),
    );
  });

  runApp(ScrollReceiptApp(startWithReceipt: fromBubble));
}

class ScrollReceiptApp extends StatelessWidget {
  final bool startWithReceipt;
  const ScrollReceiptApp({super.key, required this.startWithReceipt});

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
      home: startWithReceipt ? const ReceiptScreen() : const HomeScreen(),
    );
  }
}
