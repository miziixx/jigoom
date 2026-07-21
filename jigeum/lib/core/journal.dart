import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';
import 'theme.dart';

/// 메타·숫자·시간·배지용 모노 스타일 (DESIGN_SYSTEM §3 두 벌 시스템).
TextStyle metaStyle(BuildContext context, {Color? color, double size = 11}) {
  return TextStyle(
    fontFamily: kMonoFamily, // 숫자/기호 모노 (한글은 산세리프 폴백)
    fontSize: size,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: color ?? Theme.of(context).textTheme.bodySmall?.color,
  );
}

/// 알약 배지 (DESIGN_SYSTEM §5).
/// filled=채움형(배경 bg색, 글자 fg), 아니면 테두리형.
Widget metaBadge(
  BuildContext context,
  String label, {
  bool filled = false,
  Color? bg,
  Color? fg,
}) {
  final theme = Theme.of(context);
  final border = theme.dividerTheme.color ?? Colors.black12;
  final fillBg = bg ?? (theme.textTheme.bodyLarge?.color ?? Colors.black);
  return Container(
    padding: const EdgeInsets.fromLTRB(7, 2, 7, 2),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: filled ? fillBg : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.full),
      border: filled ? null : Border.all(color: border, width: 1),
    ),
    child: Text(
      label,
      style: metaStyle(context,
          size: 9,
          color: filled
              ? (fg ?? theme.scaffoldBackgroundColor)
              : theme.textTheme.bodySmall?.color),
    ),
  );
}

/// 일정·루틴 색 팔레트 (index 로 저장). 스샷처럼 부드러운 톤.
const kScheduleColors = <Color>[
  Color(0xFFE7B44C), // 노랑(재택근무)
  Color(0xFF6FA8DC), // 파랑
  Color(0xFF7FBf7F), // 초록
  Color(0xFFE28E8E), // 빨강
  Color(0xFFE0A15E), // 주황
  Color(0xFFB18FD6), // 보라
  Color(0xFF7FC7C0), // 청록
  Color(0xFFB0B4BA), // 회색
];

Color scheduleColor(int i) =>
    kScheduleColors[i % kScheduleColors.length];

/// 분(0~1439) → "오전 9:30" 표기.
String minToLabel(int m) {
  final h = m ~/ 60;
  final mm = m % 60;
  final ampm = h < 12 ? '오전' : '오후';
  var h12 = h % 12;
  if (h12 == 0) h12 = 12;
  return '$ampm $h12:${mm.toString().padLeft(2, '0')}';
}

/// 분 → "9:30" (짧게).
String minToShort(int m) {
  final h = m ~/ 60;
  final mm = m % 60;
  return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}

/// 타임트래커 블록(0~47) → "09:30" 시작 시각.
String blockLabel(int block) => minToShort(block * 30);

/// 저널형 타임라인 디자인 공용 요소.
/// 오프화이트 페이지 배경 + 라운드 카드 + 세로 레일 + 알약 배지 + pill.
class Journal {
  static const double railX = 27; // 세로선 x
  static const double rowLeft = 52; // 행 들여쓰기

  static Color pageBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.bgSubtleDark
          : AppColors.bgSubtleLight;

  static Color _hairline(BuildContext context) =>
      Theme.of(context).dividerTheme.color ?? Colors.black12;

  /// 라운드 카드 래퍼.
  static Widget card(BuildContext context, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _hairline(context), width: 0.5),
      ),
      child: child,
    );
  }

  /// 세로 레일 + 스크롤 rows.
  static Widget timeline(BuildContext context, List<Widget> rows) {
    return Stack(
      children: [
        Positioned(
          left: railX,
          top: 0,
          bottom: 0,
          child: Container(width: 1, color: _hairline(context)),
        ),
        ListView(
          padding: const EdgeInsets.fromLTRB(0, 14, 12, 20),
          children: rows,
        ),
      ],
    );
  }

  /// 섹션 라벨 — 배경/테두리 없이 텍스트만. (DESIGN_SYSTEM §5)
  /// "라벨 · 3" 형태면 뒤 카운트만 text 색으로 진하게.
  static Widget pill(BuildContext context, String label,
      {VoidCallback? onTap, VoidCallback? onLong, Widget? trailing}) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color;
    final strong = theme.textTheme.bodyLarge?.color;

    // "라벨 · 숫자" 분해해 숫자만 진하게.
    final parts = label.split(' · ');
    final Widget text;
    if (parts.length == 2) {
      text = RichText(
        text: TextSpan(
          style: metaStyle(context, color: muted),
          children: [
            TextSpan(text: '${parts[0]} · '),
            TextSpan(
                text: parts[1],
                style: metaStyle(context, color: strong)),
          ],
        ),
      );
    } else {
      text = Text(label, style: metaStyle(context, color: muted));
    }

    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 12, bottom: 4),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLong,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            text,
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  /// 구분선 없음 (DESIGN_SYSTEM §5): 여백만. 기존 호출부 호환용.
  static Widget divider(BuildContext context) => const SizedBox(height: 2);
}

/// 둥근 사각 체크박스 (완료 = 초록 채움 + ✓).
class SquareCheck extends StatelessWidget {
  const SquareCheck(
      {super.key, required this.done, required this.onTap, this.size = 17});

  final bool done;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDark ? AppColors.checkBorderDark : AppColors.checkBorderLight;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 10, top: 1),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            color: done ? AppColors.accent : Colors.transparent,
            border: done
                ? null
                : Border.all(color: borderColor, width: 1.5),
          ),
          child: done
              ? Icon(Icons.check, size: size - 5, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

/// 마감 배지 (DESIGN_SYSTEM §5): 임박(오늘·내일)=alert 채움, 이후=테두리 'M/d'.
Widget deadlinePill(BuildContext context, DateTime date) {
  final d = dateOnly(date);
  final diff = d.difference(todayDate()).inDays;

  final String label;
  if (diff <= 0) {
    label = '오늘';
  } else if (diff == 1) {
    label = '내일';
  } else {
    label = DateFormat('M/d').format(d);
  }

  final imminent = diff <= 1;
  return metaBadge(context, label,
      filled: imminent, bg: AppColors.alert, fg: Colors.white);
}
