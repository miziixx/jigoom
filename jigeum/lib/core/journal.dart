import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';
import 'theme.dart';

/// 편집(에디토리얼) 공용 요소 — DESIGN_SYSTEM 준수.
/// 카드·박스·그림자·둥근 모서리를 쓰지 않는다. 구분은 라벨 + 규칙선으로.

/// 메타·숫자·시간용 모노 스타일 (DESIGN_SYSTEM §3).
TextStyle metaStyle(BuildContext context, {Color? color, double size = 11}) =>
    AppText.meta(color ?? t(context).inkSoft, size: size);

/// 화면 좌우 여백 — 잡지 마진의 시그니처. (22px)
const double kGutter = AppSpace.gutter;

/// 마스트헤드 아래 강한 규칙선 (1px ink, 좌우 gutter 인셋).
class Masthead extends StatelessWidget {
  const Masthead(
      {super.key,
      required this.title,
      this.actions,
      this.eyebrow,
      this.onBack,
      this.showMenu = false});
  final String title;
  final List<Widget>? actions;

  /// 제목 위 모노 eyebrow (예: MY DAY / TODAY / DUMP). v17 레퍼런스 헤더.
  final String? eyebrow;

  /// 지정 시 제목 왼쪽에 원형 ← 뒤로가기 (푸시 화면용).
  final VoidCallback? onBack;

  /// 지정 시 우측에 원형 ≡ 메뉴(사이드바) 버튼 — 이 화면을 감싼 Scaffold 의
  /// endDrawer 를 연다. 푸시 화면(아웃라인·달력·운세·보류함 등)에서 사용.
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 20, kGutter, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onBack != null) ...[
                GestureDetector(
                  onTap: onBack,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: tk.line),
                    ),
                    child: Text('←', style: AppText.glyph(tk.ink, size: 18)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(eyebrow!,
                            style: AppText.meta(tk.mark, size: 10)
                                .copyWith(letterSpacing: 1.4)),
                      ),
                    Text(title,
                        style: AppText.hTitle(tk.ink).copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w400,
                            height: 1.12,
                            letterSpacing: -1.0)),
                  ],
                ),
              ),
              if (actions != null) ...actions!,
              if (showMenu)
                Builder(
                  // Scaffold 컨텍스트(마스트헤드를 감싼 화면의 Scaffold)에서 열어야 함.
                  builder: (ctx) => GestureDetector(
                    onTap: () => Scaffold.of(ctx).openEndDrawer(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      margin: const EdgeInsets.only(left: 10),
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: tk.line),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 15, height: 1.4, color: tk.ink),
                          const SizedBox(height: 4),
                          Container(width: 15, height: 1.4, color: tk.ink),
                          const SizedBox(height: 4),
                          Container(width: 15, height: 1.4, color: tk.ink),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: kGutter),
          height: 1,
          color: tk.ink,
        ),
      ],
    );
  }
}

/// 섹션 라벨 (잡지 목차) — 대문자 모노 라벨 + `/ n` 카운트 + fill 규칙선.
/// 카드로 감싸지 않는다. 라벨 + 규칙선이 곧 구분. (DESIGN_SYSTEM §5)
class SectionLabel extends StatelessWidget {
  const SectionLabel(
      this.label, {
    super.key,
    this.count,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.topRule = true,
  });

  final String label;
  final int? count;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  /// 상단 규칙선. 화면 첫 섹션이면 마스트헤드 규칙선과 겹쳐 "줄 두 개"로
  /// 보이므로 false 로 꺼서 마스트헤드 선 하나만 남긴다.
  final bool topRule;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    // v17: 섹션 상단에 얇은 규칙선, 그 아래 라벨 + 카운트 + trailing.
    final block = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (topRule) Container(height: 1, color: tk.line),
        if (topRule) const SizedBox(height: 7),
        Row(
          children: [
            Text(label, style: AppText.sec(tk.ink)),
            if (count != null) ...[
              const SizedBox(width: 8),
              Text('/ $count', style: AppText.meta(tk.inkSoft)),
            ],
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 18, kGutter, 8),
      child: (onTap == null && onLongPress == null)
          ? block
          : GestureDetector(
              onTap: onTap,
              onLongPress: onLongPress,
              behavior: HitTestBehavior.opaque,
              child: block),
    );
  }
}

/// 체크박스 = 글리프 □(미완료) / ■(완료). 원형·색채움 쓰지 않는다.
class GlyphCheck extends StatelessWidget {
  const GlyphCheck(
      {super.key, required this.done, required this.onTap, this.size = 16});

  final bool done;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 12, top: 1),
        child: SizedBox(
          width: size,
          child: Text(done ? '■' : '□',
              style: AppText.glyph(tk.ink, size: size),
              textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

/// 우선순위 라벨 (배지 아님). URGENT = mark+Bold(유일 포인트), IMPORTANT = inkSoft.
/// 없으면 null (우측 비움).
Widget? priorityLabel(BuildContext context,
    {required bool urgent, required bool important}) {
  final tk = t(context);
  if (urgent) return Text('URGENT', style: AppText.pri(tk.mark, bold: true));
  if (important) return Text('IMPORTANT', style: AppText.pri(tk.inkSoft));
  return null;
}

/// 빈 상태 — em-dash 접두 한 줄, 담백하게. 느낌표·이모지 금지. (DESIGN_SYSTEM §5)
Widget emptyNote(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 6),
    child: Text('— $text', style: AppText.meta(t(context).inkSoft)),
  );
}

/// 알약(pill) 칩 — 배경색 있는 작은 텍스트 아이콘. 추천/기간 선택처럼
/// "탭해서 고르는 짧은 텍스트"에만 쓴다. (선택됨 = 잉크 채움, 아니면 line 채움)
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        // v17: 알약 금지 — 각진(살짝 둥근) 칩.
        decoration: BoxDecoration(
          color: selected ? tk.ink : Colors.transparent,
          border: Border.all(color: selected ? tk.ink : tk.line, width: 1),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: AppText.chip(selected ? tk.paper : tk.inkSoft)),
      ),
    );
  }
}

/// 마감 라벨 (우측 메타). 임박(오늘/내일) = ink, 그 외 = inkSoft. 채움 배지 아님.
Widget deadlineLabel(BuildContext context, DateTime date) {
  final tk = t(context);
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
  return Text(label,
      style: AppText.meta(imminent ? tk.ink : tk.inkSoft, size: 10));
}

/// 분(0~1439) → "오전 9:30" 표기.
String minToLabel(int m) {
  final h = m ~/ 60;
  final mm = m % 60;
  final ampm = h < 12 ? '오전' : '오후';
  var h12 = h % 12;
  if (h12 == 0) h12 = 12;
  return '$ampm $h12:${mm.toString().padLeft(2, '0')}';
}

/// 분 → "09:30" (짧게).
String minToShort(int m) {
  final h = m ~/ 60;
  final mm = m % 60;
  return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}

/// 타임트래커 블록(0~47) → "09:30" 시작 시각.
String blockLabel(int block) => minToShort(block * 30);

/// 한글이 어절(공백 단위) 중간에서 줄바꿈되지 않게, 인접한 두 한글 글자
/// 사이에 WORD JOINER(U+2060)를 넣는다. 공백에서만 줄이 바뀐다.
/// (Flutter 기본은 한글을 아무 글자 사이에서나 끊어 보기 흉하다.)
String koWrap(String s) {
  bool isHangul(int u) =>
      (u >= 0xAC00 && u <= 0xD7A3) || // 완성형 음절
      (u >= 0x1100 && u <= 0x11FF) || // 자모
      (u >= 0x3130 && u <= 0x318F); // 호환 자모
  if (s.length < 2) return s;
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    buf.write(s[i]);
    if (i + 1 < s.length &&
        isHangul(s.codeUnitAt(i)) &&
        isHangul(s.codeUnitAt(i + 1))) {
      buf.writeCharCode(0x2060); // WORD JOINER
    }
  }
  return buf.toString();
}
