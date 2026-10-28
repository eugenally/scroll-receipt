/// 하루치 스크롤 기록.
///
/// 안드로이드는 모든 값을 측정하지만, 나중에 붙일 아이폰 버전은
/// 이용 시간만 알 수 있으므로 나머지 항목은 null 이 될 수 있다.
/// null 인 항목은 영수증에서 드립 문구로 대체된다.
class ReceiptData {
  final DateTime date;

  /// 오늘 하루 이용 시간 (매일 0시에 새로 시작)
  final Duration usage;

  /// 첫날부터 지금까지 쌓인 이용 시간 ("총 소비한 인생"). 모르면 null → 오늘 이용 시간으로 대신
  final Duration? totalUsage;
  final double? scrollMeters;
  final int? friendPosts;
  final int? suggestedPosts;
  final int? ads;
  final int? reels;
  final int? likes;

  const ReceiptData({
    required this.date,
    required this.usage,
    this.totalUsage,
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
      totalUsage: m['totalUsageMs'] == null
          ? null
          : Duration(milliseconds: (m['totalUsageMs'] as num).toInt()),
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
        totalUsage: const Duration(days: 3, hours: 7, minutes: 40),
        scrollMeters: 347.2,
        friendPosts: 4,
        suggestedPosts: 61,
        ads: 23,
        reels: 38,
        likes: 9,
      );
}
