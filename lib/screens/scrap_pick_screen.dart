import 'dart:async';

import 'package:flutter/material.dart';

import '../services/tracker_channel.dart';
import 'home_screen.dart';
import 'scraps_screen.dart';

/// (아이폰) 🧾 의 ✂️ 스크랩으로 열리는 문장 고르기 화면.
/// 안드로이드는 인스타그램 위에 스크랩 창(ScrapSheet.kt)을 띄우지만, 아이폰은 앱 화면으로 옮겨 와서
/// 화면 방송 확장이 읽어 둔 직전 인스타그램 화면의 문장을 고른다.
class ScrapPickScreen extends StatefulWidget {
  const ScrapPickScreen({super.key});

  @override
  State<ScrapPickScreen> createState() => _ScrapPickScreenState();
}

class _ScrapPickScreenState extends State<ScrapPickScreen> {
  /// 확장은 0.5초에 한 번 요청을 확인한다. 이만큼 기다려도 답이 없으면 포기한다
  static const _timeout = Duration(seconds: 4);

  final _edit = TextEditingController();
  Timer? _poll;
  List<String>? _pieces;
  List<bool> _picked = const [];
  String? _author;

  /// 답을 못 받았을 때 보여 줄 이유
  String? _error;

  @override
  void initState() {
    super.initState();
    final started = DateTime.now();
    _poll = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      Map<dynamic, dynamic> m = const {};
      try {
        m = await TrackerChannel.scrapCandidates();
      } catch (_) {}
      if (!mounted) return;
      final pieces = (m['pieces'] as List<dynamic>?)?.cast<String>();
      if (pieces != null) {
        _poll?.cancel();
        setState(() {
          _pieces = pieces;
          _picked = List.filled(pieces.length, false);
          _author = m['author'] as String?;
          if (pieces.isEmpty) _error = '방금 본 화면에서 읽은 글이 없어요.\n인스타그램 게시물을 보던 중에 눌러 주세요.';
        });
      } else if (m['broadcasting'] == false || DateTime.now().difference(started) > _timeout) {
        _poll?.cancel();
        setState(() => _error = '화면 방송을 켠 상태에서만 스크랩할 수 있어요.\n'
            '홈 화면의 "화면 방송 시작"을 누른 뒤 다시 해 주세요.');
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _edit.dispose();
    super.dispose();
  }

  void _toggle(int i) {
    setState(() => _picked[i] = !_picked[i]);
    _edit.text = [for (var j = 0; j < _pieces!.length; j++) if (_picked[j]) _pieces![j]].join('\n');
  }

  /// 🧾 로 바로 열렸으면 돌아갈 화면이 없으니 [next] 로 바꾼다
  void _close({Widget next = const HomeScreen()}) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacement(MaterialPageRoute(builder: (_) => next));
    }
  }

  Future<void> _save() async {
    final s = _edit.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (s.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('저장할 문장을 골라 주세요')));
      return;
    }
    await TrackerChannel.addScrap(s, _author);
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('스크랩했어요 ✂️')));
    _close(next: const ScrapsScreen());
  }

  @override
  Widget build(BuildContext context) {
    final pieces = _pieces;
    final faded = Theme.of(context).textTheme.bodySmall;
    return Scaffold(
      appBar: AppBar(
        title: const Text('✂️ 마음에 드는 문장을 고르세요'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _close),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : pieces == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_author != null) Text('@$_author', style: faded),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: pieces.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, i) => FilterChip(
                            label: Text(pieces[i], softWrap: true),
                            selected: _picked[i],
                            showCheckmark: false,
                            onSelected: (_) => _toggle(i),
                          ),
                        ),
                      ),
                      TextField(
                        controller: _edit,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: '고른 문장이 여기에 모여요. 직접 고쳐도 돼요',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(onPressed: _close, child: const Text('취소')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(onPressed: _save, child: const Text('스크랩 저장')),
                        ),
                      ]),
                    ],
                  ),
                ),
    );
  }
}
