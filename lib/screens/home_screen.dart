import 'package:flutter/material.dart';

import '../services/tracker_channel.dart';
import 'receipt_screen.dart';

/// 처음 앱을 열었을 때: 접근성 권한 안내 + 영수증 미리보기.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 설정 화면에서 돌아오면 다시 확인
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    bool on = false;
    try {
      on = await TrackerChannel.isServiceEnabled();
    } catch (_) {}
    if (mounted) setState(() => _enabled = on);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🧾 스크롤 영수증')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(_enabled ? Icons.check_circle : Icons.error_outline,
                        color: _enabled ? Colors.greenAccent : Colors.orangeAccent),
                    const SizedBox(width: 8),
                    Text(_enabled ? '측정 중이에요' : '측정이 꺼져 있어요',
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 10),
                  const Text(
                    '인스타그램을 볼 때 화면 가장자리에 🧾 버튼이 떠요. '
                    '누르면 그때까지의 영수증이 바로 나옵니다.\n\n'
                    '이를 위해 접근성 권한이 필요해요. 화면에 보이는 '
                    '"광고"·"추천" 같은 표시와 스크롤 양만 세고, '
                    '모든 기록은 이 폰 안에만 저장되며 어디로도 전송되지 않습니다.',
                  ),
                  const SizedBox(height: 14),
                  if (!_enabled)
                    FilledButton(
                      onPressed: TrackerChannel.openAccessibilitySettings,
                      child: const Text('접근성 설정 열기 → "스크롤 영수증" 켜기'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('오늘의 영수증 보기'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReceiptScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('샘플 영수증 (디자인 확인용)'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReceiptScreen(sample: true)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('오늘 기록 초기화'),
            onTap: () async {
              await TrackerChannel.resetToday();
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('초기화했어요')));
              }
            },
          ),
        ],
      ),
    );
  }
}
