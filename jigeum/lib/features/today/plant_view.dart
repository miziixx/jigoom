import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import 'garden_page.dart';

/// 오늘의 식물 — 완료·시작이 쌓일수록 자라는 잔잔한 선화(에디토리얼) 보상.
/// 경쟁·점수·시들기 없음. "물"은 오늘 완료(승리) + 오늘 시작 횟수.
class PlantBand extends ConsumerWidget {
  const PlantBand({super.key});

  /// 물 → 성장 단계(0..5). 문구 분기에 쓴다.
  static int stageOf(int water) {
    if (water <= 0) return 0; // 씨앗
    if (water == 1) return 1; // 새싹
    if (water <= 3) return 2; // 잎 몇 장
    if (water <= 5) return 3; // 자라는 중
    if (water <= 8) return 4; // 꽃봉오리
    return 5; // 활짝
  }

  static String label(int stage) {
    switch (stage) {
      case 0:
        return '씨앗';
      case 1:
        return '새싹';
      case 2:
        return '잎이 났어요';
      case 3:
        return '자라는 중';
      case 4:
        return '꽃봉오리';
      default:
        return '활짝 폈어요';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final reduceMotion =
        ref.watch(settingsProvider.select((s) => s.reduceMotion));
    final wins = ref.watch(todayWinsProvider).valueOrNull ?? const [];
    final started = ref.watch(startedTodayProvider).valueOrNull ?? 0;
    final water = wins.length + started;
    final stage = stageOf(water);

    final caption = water <= 0
        ? '뭔가 하나 시작하면 싹이 나요'
        : '오늘 $water번 물 줬어요 · ${label(stage)}';

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const GardenPage()),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PlantGlyph(water: water, height: 116, animate: !reduceMotion),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(caption, style: AppText.meta(tk.inkSoft, size: 11)),
                const SizedBox(width: 8),
                Text('정원 ›', style: AppText.meta(tk.mark, size: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 재사용 가능한 식물 그림 — [water] 만큼 자란 선화. 크기에 맞춰 자동 스케일.
class PlantGlyph extends StatelessWidget {
  const PlantGlyph({
    super.key,
    required this.water,
    this.height = 116,
    this.animate = false,
  });

  final int water;
  final double height;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final grow = (water / 9).clamp(0.0, 1.0).toDouble();
    final leaves = math.min(water, 6);
    final flower = water >= 9;
    final bud = water >= 6 && water < 9;

    _PlantPainter make(double f) => _PlantPainter(
          grow: grow * f,
          leaves: (leaves * f).round(),
          flower: flower && f > 0.9,
          bud: bud && f > 0.8,
          ink: tk.ink,
          mark: tk.mark,
          soft: tk.inkSoft,
          line: tk.line,
        );

    if (!animate) {
      return CustomPaint(
          painter: make(1), size: Size(double.infinity, height));
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) =>
          CustomPaint(painter: make(v), size: Size(double.infinity, height)),
    );
  }
}

class _PlantPainter extends CustomPainter {
  _PlantPainter({
    required this.grow,
    required this.leaves,
    required this.flower,
    required this.bud,
    required this.ink,
    required this.mark,
    required this.soft,
    required this.line,
  });

  final double grow; // 0..1
  final int leaves;
  final bool flower;
  final bool bud;
  final Color ink;
  final Color mark;
  final Color soft;
  final Color line;

  static const double _unitH = 116; // 설계 기준 높이

  @override
  void paint(Canvas canvas, Size size) {
    // 설계 기준(116)에 맞춰 그리고 실제 크기로 스케일 — 미니 식물도 비율 유지.
    final scale = size.height / _unitH;
    canvas.save();
    canvas.scale(scale);
    _paintUnit(canvas, Size(size.width / scale, _unitH));
    canvas.restore();
  }

  void _paintUnit(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final baseY = size.height - 14;
    final soilHalf = math.min(size.width * 0.42, 46.0);

    // 땅(잔잔한 지평선) + 흙 점.
    canvas.drawLine(Offset(cx - soilHalf, baseY), Offset(cx + soilHalf, baseY),
        Paint()
          ..color = line
          ..strokeWidth = 1);
    final dotPaint = Paint()..color = soft;
    for (final dx in [-30.0, -12.0, 10.0, 28.0]) {
      if (dx.abs() < soilHalf) {
        canvas.drawCircle(Offset(cx + dx, baseY + 5), 0.8, dotPaint);
      }
    }

    // 씨앗(성장 0).
    if (grow <= 0.001) {
      canvas.drawCircle(Offset(cx, baseY - 3), 3, Paint()..color = mark);
      return;
    }

    // 줄기.
    final stemH = 22 + grow * (size.height - 46);
    final topY = baseY - stemH;
    final sway = 8.0 * grow;
    final stem = Path()
      ..moveTo(cx, baseY)
      ..quadraticBezierTo(cx - sway, baseY - stemH * 0.55, cx, topY);
    canvas.drawPath(
        stem,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);

    // 잎.
    final leafPaint = Paint()..color = mark.withValues(alpha: 0.85);
    for (var i = 0; i < leaves; i++) {
      final f = (i + 1) / (leaves + 1);
      final ly = baseY - stemH * f;
      final lx = cx - sway * (1 - f);
      _drawLeaf(canvas, Offset(lx, ly), i.isEven, 14 + 4 * grow, leafPaint);
    }

    // 꽃 / 봉오리 / 끝눈.
    if (flower) {
      _drawFlower(canvas, Offset(cx, topY), mark, ink);
    } else if (bud) {
      canvas.drawCircle(Offset(cx, topY), 4.5, Paint()..color = mark);
    } else {
      canvas.drawCircle(Offset(cx, topY), 2.2, Paint()..color = soft);
    }
  }

  void _drawLeaf(
      Canvas canvas, Offset base, bool left, double len, Paint paint) {
    final dir = left ? -1.0 : 1.0;
    final tip = Offset(base.dx + dir * len, base.dy - len * 0.5);
    final path = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(
          base.dx + dir * len * 0.5, base.dy - len * 0.7, tip.dx, tip.dy)
      ..quadraticBezierTo(
          base.dx + dir * len * 0.6, base.dy - len * 0.1, base.dx, base.dy);
    canvas.drawPath(path, paint);
  }

  void _drawFlower(Canvas canvas, Offset c, Color petal, Color core) {
    final p = Paint()..color = petal.withValues(alpha: 0.9);
    const n = 5;
    for (var i = 0; i < n; i++) {
      final a = (i / n) * 2 * math.pi;
      final pc = Offset(c.dx + math.cos(a) * 6, c.dy + math.sin(a) * 6);
      canvas.drawCircle(pc, 4.2, p);
    }
    canvas.drawCircle(c, 3.4, Paint()..color = core);
  }

  @override
  bool shouldRepaint(covariant _PlantPainter old) =>
      old.grow != grow ||
      old.leaves != leaves ||
      old.flower != flower ||
      old.bud != bud ||
      old.ink != ink ||
      old.mark != mark;
}
