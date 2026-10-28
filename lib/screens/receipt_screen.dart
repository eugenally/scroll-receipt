import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/receipt_data.dart';
import '../receipt/receipt_view.dart';
import '../services/tracker_channel.dart';
import 'home_screen.dart';

/// 플로팅 버튼을 누르면 올라오는 영수증 화면.
class ReceiptScreen extends StatefulWidget {
  /// true 면 실제 기록 대신 샘플 데이터 (디자인 확인용)
  final bool sample;
  const ReceiptScreen({super.key, this.sample = false});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen>
    with SingleTickerProviderStateMixin {
  final _captureKey = GlobalKey();
  late final AnimationController _print = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  ReceiptData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    ReceiptData d;
    try {
      d = widget.sample ? ReceiptData.sample() : await TrackerChannel.today();
    } catch (_) {
      d = ReceiptData.sample(); // 에뮬레이터/데스크톱에서 채널이 없을 때
    }
    if (!mounted) return;
    setState(() => _data = d);
    _print.forward(from: 0);
  }

  Future<void> _share() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/scroll_receipt_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    await Share.shareXFiles([XFile(file.path)], text: '오늘의 스크롤 영수증 🧾');
  }

  @override
  void dispose() {
    _print.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1F),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).maybePop().then((popped) {
                  if (popped || !context.mounted) return;
                  // 아이폰은 앱이 스스로 인스타그램으로 돌아갈 수 없다. 🧾 로 열렸으면 홈 화면으로
                  if (Platform.isIOS) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  } else {
                    // 플로팅 버튼으로 열렸으면 앱을 내려서 인스타그램으로 복귀
                    TrackerChannel.backToPreviousApp();
                  }
                }),
              ),
            ),
            Expanded(
              child: _data == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        // 영수증이 프린터에서 나오듯 위에서부터 내려오는 효과
                        child: AnimatedBuilder(
                          animation: _print,
                          builder: (context, child) => ClipRect(
                            child: Align(
                              alignment: Alignment.topCenter,
                              heightFactor: Curves.easeOutCubic.transform(_print.value),
                              child: child,
                            ),
                          ),
                          child: RepaintBoundary(
                            key: _captureKey,
                            child: ReceiptView(data: _data!),
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('다시 출력'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _data == null ? null : _share,
                      icon: const Icon(Icons.ios_share),
                      label: const Text('공유하기'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

