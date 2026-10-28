import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/scrap.dart';
import '../services/tracker_channel.dart';

/// 인스타그램에서 골라 모아 둔 문장들.
class ScrapsScreen extends StatefulWidget {
  const ScrapsScreen({super.key});

  @override
  State<ScrapsScreen> createState() => _ScrapsScreenState();
}

class _ScrapsScreenState extends State<ScrapsScreen> {
  List<Scrap>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Scrap> items;
    try {
      items = await TrackerChannel.scraps();
    } catch (_) {
      items = const []; // 에뮬레이터/데스크톱에서 채널이 없을 때
    }
    if (mounted) setState(() => _items = items);
  }

  Future<void> _delete(Scrap s) async {
    // 밀어서 지운 항목은 바로 목록에서 빼야 한다 (Dismissible 규칙)
    setState(() => _items = [..._items!]..remove(s));
    await TrackerChannel.deleteScrap(s.id);
  }

  String _withAuthor(Scrap s) => s.author == null ? s.text : '${s.text}\n— @${s.author}';

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('✂️ 내 스크랩')),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      '아직 스크랩이 없어요.\n\n'
                      '인스타그램에서 🧾 버튼 → "✂️ 보던 게시물에서 스크랩"을 누르면 '
                      '마음에 드는 문장을 골라 저장할 수 있어요.\n'
                      '긴 캡션은 "더 보기"로 펼친 뒤 누르세요.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _tile(context, items[i]),
                ),
    );
  }

  Widget _tile(BuildContext context, Scrap s) {
    final faded = Theme.of(context).textTheme.bodySmall;
    return Dismissible(
      key: ValueKey(s.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => _delete(s),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(s.text, style: const TextStyle(fontSize: 15, height: 1.45)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(
                    [
                      if (s.author != null) '@${s.author}',
                      DateFormat('yyyy.MM.dd HH:mm').format(s.savedAt),
                    ].join(' · '),
                    style: faded,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: '복사',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _withAuthor(s)));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('복사했어요')));
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share, size: 18),
                  tooltip: '공유',
                  onPressed: () => Share.share(_withAuthor(s)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
