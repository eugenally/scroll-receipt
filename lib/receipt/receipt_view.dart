import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/receipt_data.dart';
import 'receipt_copy.dart';

/// 영수증 한 장. 순수하게 그리기만 한다 (이미지 캡처 대상).
class ReceiptView extends StatelessWidget {
  final ReceiptData data;
  const ReceiptView({super.key, required this.data});

  static const _ink = Color(0xFF222222);
  static const _paper = Color(0xFFFDFCF7);
  static const _mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 14,
    height: 1.45,
    color: _ink,
  );

  @override
  Widget build(BuildContext context) {
    final d = data;
    final won = NumberFormat('#,###');
    String price(int? n) => n == null ? '' : '₩${won.format(n * 100)}';

    return ClipPath(
      clipper: _ZigzagClipper(),
      child: Container(
        width: 340,
        color: _paper,
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 34),
        child: DefaultTextStyle(
          style: _mono,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ReceiptCopy.storeName,
                  textAlign: TextAlign.center,
                  style: _mono.copyWith(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(
                '${ReceiptCopy.branch} · ${DateFormat('yyyy.MM.dd HH:mm').format(d.date)}',
                textAlign: TextAlign.center,
                style: _mono.copyWith(fontSize: 12),
              ),
              _dash(),
              _row('1일 이용시간', _fmtDuration(d.usage)),
              _row(
                '스크롤 거리',
                d.scrollMeters == null
                    ? ReceiptCopy.unknownDistance
                    : '${d.scrollMeters!.toStringAsFixed(1)}m',
              ),
              if (d.scrollMeters != null)
                Text('  ${ReceiptCopy.distanceComparison(d.scrollMeters!)}',
                    style: _mono.copyWith(fontSize: 12)),
              _dash(),
              _item('친구 게시물', d.friendPosts, price(d.friendPosts)),
              _item('모르는 사람 추천', d.suggestedPosts, price(d.suggestedPosts)),
              d.ads == null
                  ? _row('광고', ReceiptCopy.unknownAds)
                  : _item('광고', d.ads, price(d.ads)),
              _item('릴스', d.reels, price(d.reels)),
              _dash(),
              if (d.likes != null) _row('좋아요 누름', '${d.likes}회'),
              _row('그 시간에', ''),
              Text('  ${ReceiptCopy.couldHaveDone(d.usage)} 가능',
                  style: _mono.copyWith(fontSize: 12)),
              _dash(),
              if (d.friendRatio != null)
                _row('친구 비율 할인', '-${d.friendRatio!.toStringAsFixed(1)}%'),
              if (d.algorithmTax != null)
                _row('알고리즘 부가세', '+${d.algorithmTax!.toStringAsFixed(0)}%'),
              _double(),
              _row('총 소비한 인생', _fmtDuration(d.totalUsage ?? d.usage), bold: true),
              _double(),
              const SizedBox(height: 10),
              _Barcode(seed: d.date.day * 31 + d.usage.inMinutes),
              const SizedBox(height: 10),
              const Text('오늘도 이용해 주셔서 감사합니다', textAlign: TextAlign.center),
              Text(ReceiptCopy.footer(), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String l, String r, {bool bold = false}) {
    final s = bold ? _mono.copyWith(fontWeight: FontWeight.bold, fontSize: 15) : _mono;
    return Row(children: [
      Expanded(child: Text(l, style: s)),
      Text(r, style: s),
    ]);
  }

  Widget _item(String label, int? count, String price) => Row(children: [
        Expanded(child: Text(label)),
        SizedBox(width: 48, child: Text(count == null ? '-' : '$count개', textAlign: TextAlign.right)),
        SizedBox(width: 72, child: Text(price, textAlign: TextAlign.right)),
      ]);

  Widget _dash() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text('- - - - - - - - - - - - - - - - - - - -',
            maxLines: 1, overflow: TextOverflow.clip, softWrap: false),
      );

  Widget _double() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Text('════════════════════════════════',
            maxLines: 1, overflow: TextOverflow.clip, softWrap: false),
      );

  static String _fmtDuration(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60;
    if (h >= 24) return '${h ~/ 24}일 ${h % 24}시간 $m분';
    return h > 0 ? '$h시간 $m분' : '$m분';
  }
}

class _Barcode extends StatelessWidget {
  final int seed;
  const _Barcode({required this.seed});

  @override
  Widget build(BuildContext context) {
    final r = Random(seed);
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(46, (_) {
          final w = (r.nextInt(3) + 1).toDouble();
          return Container(
            width: w,
            margin: EdgeInsets.only(right: (r.nextInt(2) + 1).toDouble()),
            color: r.nextBool() ? ReceiptView._ink : Colors.transparent,
          );
        }),
      ),
    );
  }
}

/// 영수증 위아래를 톱니 모양으로 자른다.
class _ZigzagClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    const t = 8.0;
    final p = Path()..moveTo(0, t);
    for (double x = 0; x < s.width; x += t * 2) {
      p.lineTo(x + t, 0);
      p.lineTo(min(x + t * 2, s.width), t);
    }
    p.lineTo(s.width, s.height - t);
    for (double x = s.width; x > 0; x -= t * 2) {
      p.lineTo(x - t, s.height);
      p.lineTo(max(x - t * 2, 0), s.height - t);
    }
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}
