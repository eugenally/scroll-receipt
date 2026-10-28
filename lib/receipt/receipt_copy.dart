import 'dart:math';

/// 영수증에 들어가는 드립 문구 모음. 여기만 고치면 문구가 바뀐다.
class ReceiptCopy {
  static const storeName = '★ SCROLL MART ★';
  static const branch = '인스타그램 지점';

  /// 스크롤 거리를 랜드마크로 환산 (높이/길이, m)
  static const _landmarks = <String, double>{
    '남산서울타워': 236.7,
    '롯데월드타워': 555.0,
    '63빌딩': 249.6,
    '에펠탑': 330.0,
    '축구장 길이': 105.0,
  };

  static String distanceComparison(double meters) {
    if (meters < 50) return '(≈ 아직 몸풀기)';
    final keys = _landmarks.keys.toList();
    // 날짜마다 다른 랜드마크가 나오도록
    final key = keys[DateTime.now().day % keys.length];
    final n = meters / _landmarks[key]!;
    return '(≈ $key ${n.toStringAsFixed(1)}개)';
  }

  /// 이용 시간으로 할 수 있었던 일
  static String couldHaveDone(Duration d) {
    final m = d.inMinutes;
    final options = <String>[
      '라면 ${(m / 4).floor()}개 끓이기',
      '5km 러닝 ${(m / 30).toStringAsFixed(1)}회',
      '책 ${(m * 1.5).round()}쪽 읽기',
      '낮잠 ${(m / 20).floor()}번',
      '노래 ${(m / 3.5).floor()}곡 듣기',
    ];
    return options[Random(DateTime.now().day).nextInt(options.length)];
  }

  static const footers = [
    '엄지손가락에게 휴식을 주세요',
    '내일 또 오실 거 다 압니다',
    '포인트는 적립되지 않습니다',
    '교환·환불 불가 (시간은 돌아오지 않음)',
    '알고리즘이 당신을 기억합니다',
  ];

  static String footer() => footers[DateTime.now().day % footers.length];

  // 아이폰 등에서 측정 못 한 항목에 들어갈 문구
  static const unknownAds = 'OS가 비밀로 함 🤫';
  static const unknownDistance = '측정 불가 (아마 많음)';
}
