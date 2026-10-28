/// 인스타그램 게시물에서 직접 골라 저장한 문장.
class Scrap {
  final int id;
  final String text;

  /// 게시물 작성자. 화면에서 못 찾았으면 null
  final String? author;
  final DateTime savedAt;

  const Scrap({
    required this.id,
    required this.text,
    this.author,
    required this.savedAt,
  });

  factory Scrap.fromMap(Map<dynamic, dynamic> m) => Scrap(
        id: (m['id'] as num).toInt(),
        text: m['text'] as String,
        author: m['author'] as String?,
        savedAt: DateTime.fromMillisecondsSinceEpoch((m['savedAt'] as num).toInt()),
      );
}
