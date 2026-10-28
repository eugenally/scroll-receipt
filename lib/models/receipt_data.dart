/// 하루치 스크롤 기록.
///
/// 안드로이드는 모든 값을 측정하지만, 나중에 붙일 아이폰 버전은
/// 이용 시간만 알 수 있으므로 나머지 항목은 null 이 될 수 있다.
/// null 인 항목은 영수증에서 드립 문구로 대체된다.
class ReceiptData {
  final DateTime date;
  final Duration usage;
  final double? scrollMeters;
  final int? friendPosts;
  final int? suggestedPosts;
  final int? ads;
  final int? reels;
  final int? likes;

  const ReceiptData({
    required this.date,
    required this.usage,
    this.scrollMeters,
    this.friendPosts,
    this.suggestedPosts,
    this.ads,
    this.reels,
    this.likes,
  });

  int get totalPosts =>
      (friendPosts ?? 0) + (suggestedPosts ?? 0) + (ads ?? 0) + (reels ?? 0);

  /// 전체 콘텐츠 중 친구(팔로우) 게시물 비율 (0~100)
  double? get friendRatio {
    if (friendPosts == null || totalPosts == 0) return null;
    return friendPosts! / totalPosts * 100;
  }

  /// 친구 게시물이 아닌 것의 비율 = "알고리즘 부가세"
  double? get algorithmTax {
    final r = friendRatio;
    return r == null ? null : 100 - r;
  }

  factory ReceiptData.fromMap(Map<dynamic, dynamic> m) {
    return ReceiptData(
      date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
      usage: Duration(milliseconds: (m['usageMs'] as num?)?.toInt() ?? 0),
      scrollMeters: (m['scrollMeters'] as num?)?.toDouble(),
      friendPosts: (m['friendPosts'] as num?)?.toInt(),
      suggestedPosts: (m['suggestedPosts'] as num?)?.toInt(),
      ads: (m['ads'] as num?)?.toInt(),
      reels: (m['reels'] as num?)?.toInt(),
      likes: (m['likes'] as num?)?.toInt(),
    );
  }

  /// 디자인 확인용 가짜 데이터
  factory ReceiptData.sample() => ReceiptData(
        date: DateTime.now(),
        usage: const Duration(hours: 1, minutes: 12),
        scrollMeters: 347.2,
        friendPosts: 4,
        suggestedPosts: 61,
        ads: 23,
        reels: 38,
        likes: 9,
      );
}
