import 'package:flutter/material.dart';

/// 곰곰이 — 아기 갈색곰 마스코트. 외부 이미지 없이 [CustomPainter] 로 그린다.
/// 색은 브랜드 상수(테마와 무관하게 항상 같은 갈색곰). 리디자인 시안 v4의 SVG 이식.
///
/// 사용: `const GomgomBear(size: 44)`.
class GomgomBear extends StatelessWidget {
  const GomgomBear({super.key, this.size = 44});

  final double size;

  // 브랜드색 — 어느 테마에서도 동일한 곰곰이.
  static const Color fur = Color(0xFFB67E4C);
  static const Color furDark = Color(0xFF8A5A31);
  static const Color cream = Color(0xFFF1E4CA);
  static const Color nose = Color(0xFF3A2A1D);
  static const Color blush = Color(0xFFE8987C);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _BearPainter()),
      );
}

class _BearPainter extends CustomPainter {
  // 좌표는 시안 SVG viewBox(0~100) 기준. 위젯 크기에 맞춰 배율.
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    final p = Paint()..isAntiAlias = true;

    void circle(double cx, double cy, double r, Color c, [double? opacity]) {
      p
        ..style = PaintingStyle.fill
        ..color = opacity == null ? c : c.withValues(alpha: opacity);
      canvas.drawCircle(Offset(cx * s, cy * s), r * s, p);
    }

    void oval(double cx, double cy, double rx, double ry, Color c) {
      p
        ..style = PaintingStyle.fill
        ..color = c;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx * s, cy * s), width: 2 * rx * s, height: 2 * ry * s),
        p,
      );
    }

    // 귀 (머리 뒤로)
    circle(27, 25, 15.5, GomgomBear.furDark);
    circle(73, 25, 15.5, GomgomBear.furDark);
    circle(27, 26, 8, GomgomBear.cream);
    circle(73, 26, 8, GomgomBear.cream);
    // 머리
    circle(50, 58, 37, GomgomBear.fur);
    // 발그레한 볼
    circle(28, 66, 9.5, GomgomBear.blush, 0.55);
    circle(72, 66, 9.5, GomgomBear.blush, 0.55);
    // 주둥이
    oval(50, 68, 14.5, 10.5, GomgomBear.cream);
    oval(50, 63, 5, 3.6, GomgomBear.nose);
    // 입 — 작은 'w' 미소
    final mouth = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = GomgomBear.nose;
    final path = Path()
      ..moveTo(50 * s, 66 * s)
      ..lineTo(50 * s, 69.5 * s)
      ..moveTo(50 * s, 69.5 * s)
      ..quadraticBezierTo(46 * s, 72.9 * s, 43 * s, 70.3 * s)
      ..moveTo(50 * s, 69.5 * s)
      ..quadraticBezierTo(54 * s, 72.9 * s, 57 * s, 70.3 * s);
    canvas.drawPath(path, mouth);
    // 큰 아기 눈 + 반짝임
    circle(35, 55, 4.6, GomgomBear.nose);
    circle(65, 55, 4.6, GomgomBear.nose);
    circle(36.6, 53.2, 1.5, Colors.white);
    circle(66.6, 53.2, 1.5, Colors.white);
  }

  @override
  bool shouldRepaint(covariant _BearPainter oldDelegate) => false;
}
