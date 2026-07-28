import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'constants.dart';
import 'theme.dart';

/// ============================================================
/// EDITORIAL COMPONENT LAYER  (v17 "Free Editorial" 정렬)
///
/// jigeum 은 이미 6토큰 잉크 시스템(paper/ink/line/mark …)과 편집 타이포
/// (AppText)를 갖고 있다. 이 파일은 그 위에 얹는 **공통 화면 컴포넌트**로,
/// 화면마다 제각각이던 헤더·섹션·행·탭·모달을 하나의 규칙으로 통일한다.
///
/// 원칙(디자인 레퍼런스 v17):
///   · hairline(0.75~1px) 규칙선, 그림자 없음, 각진 모서리
///   · 좌우 gutter·섹션 시작선·본문 시작선·체크박스 열·액션 열을 전 화면 공통
///   · 색 면적은 넓히지 않고, 포인트(mark)는 짧은 선/작은 강조에만
///   · 라벨·시간·간지·수치는 모노(AppText.meta)
///
/// 기존 위젯과의 충돌을 피하려 모두 `Ed` 접두어를 쓴다.
/// ============================================================

/// 편집 간격 토큰. 레퍼런스 spacing scale 을 앱 리듬에 맞춰 노출.
/// (기존 AppSpace 를 그대로 재노출 — 새 값을 만들지 않는다.)
class Ed {
  Ed._();

  // spacing
  static const double x2 = 2;
  static const double x4 = AppSpace.s1; // 4
  static const double x6 = 6;
  static const double x8 = AppSpace.s2; // 8
  static const double x10 = 10;
  static const double x12 = AppSpace.s3; // 12
  static const double x16 = AppSpace.s4; // 16
  static const double x20 = 20;
  static const double x24 = AppSpace.s5; // 24
  static const double x32 = AppSpace.s6; // 32

  /// 화면 좌우 여백 — 전 화면 공통 gutter.
  static const double gutter = AppSpace.gutter; // 22

  /// hairline 두께.
  static const double hair = 1;

  /// 체크박스 열 폭 · 우측 액션 열 폭 (task grid 정렬 기준).
  static const double checkCol = 22;
  static const double actionCol = 30;
}

/// 얇은 규칙선(hairline). 색은 토큰 line, 굵기 1px.
class EdHairline extends StatelessWidget {
  const EdHairline({super.key, this.color, this.height = 1, this.indent = 0});
  final Color? color;
  final double height;
  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: indent),
        child: Divider(
            height: height,
            thickness: 1,
            color: color ?? t(context).line),
      );
}

/// 화면 상단 헤더 — eyebrow(모노 소문자) + 큰 타이틀 + 우측 액션 슬롯.
/// 모든 화면이 동일한 좌측 시작선/상단 여백을 갖게 한다.
class EdPageHeader extends StatelessWidget {
  const EdPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.index,
    this.trailing,
    this.onBack,
  });

  final String title;
  final String? eyebrow;

  /// 우상단 인덱스 번호(예: "01") — 편집 시그니처. 없으면 미표시.
  final String? index;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null)
            Padding(
              padding: const EdgeInsets.only(right: Ed.x8),
              child: _EdIconBox(icon: Icons.arrow_back, onTap: onBack!),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!.toUpperCase(),
                      style: AppText.meta(tk.inkSoft, size: 9)
                          .copyWith(letterSpacing: 1.6)),
                  const SizedBox(height: 3),
                ],
                Text(title,
                    style: AppText.hTitle(tk.ink)
                        .copyWith(fontSize: 27, letterSpacing: -0.6)),
              ],
            ),
          ),
          if (index != null)
            Padding(
              padding: const EdgeInsets.only(left: Ed.x8, top: 2),
              child: Text(index!,
                  style: AppText.meta(tk.inkSoft, size: 10)
                      .copyWith(letterSpacing: 0.8)),
            ),
          if (trailing != null) ...[
            const SizedBox(width: Ed.x8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// 섹션 헤더 — § 기호(포인트색) + 제목 + 하단 규칙선(잉크).
/// 우측에 텍스트 액션(예: "전체 →")을 둘 수 있다.
class EdSectionHeader extends StatelessWidget {
  const EdSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('§ ',
                    style: AppText.meta(tk.mark, size: 10)),
                Expanded(
                  child: Text(title,
                      style: AppText.hTitle(tk.ink).copyWith(
                          fontSize: 14, height: 1.1, letterSpacing: -0.2)),
                ),
                if (action != null)
                  EdTextAction(label: action!, onTap: onAction),
              ],
            ),
          ),
          Container(height: 1, color: tk.ink),
        ],
      ),
    );
  }
}

/// 텍스트 액션 — 박스 없는 "라벨 →" 형태의 얇은 버튼(모노).
class EdTextAction extends StatelessWidget {
  const EdTextAction(
      {super.key, required this.label, this.onTap, this.danger = false});
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Text(label,
            style: AppText.meta(danger ? AppState.error : tk.ink, size: 9)
                .copyWith(letterSpacing: 0.6)),
      ),
    );
  }
}

/// 사각 아이콘 버튼(헤더/네비 액션) — 1px 규칙선, 각진 모서리.
class _EdIconBox extends StatelessWidget {
  const _EdIconBox({required this.icon, required this.onTap, this.size = 36});
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: tk.line, width: 1)),
        child: Icon(icon, size: 18, color: tk.ink),
      ),
    );
  }
}

/// 에디토리얼 탭 — 알약/박스 없는 텍스트 탭. 활성은 포인트색 + 얇은 밑줄.
/// (오늘 필터·주간/월간 전환 등에서 공통 사용)
class EdTabs extends StatelessWidget {
  const EdTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tk.line, width: 1)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            _EdTab(
              label: labels[i],
              active: i == index,
              onTap: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}

class _EdTab extends StatelessWidget {
  const _EdTab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? tk.mark : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppText.meta(active ? tk.ink : tk.inkSoft, size: 11)
              .copyWith(letterSpacing: 0.4),
        ),
      ),
    );
  }
}

/// 할 일 행 — [체크박스 | 본문(+메타) | 우측 액션] 3열 그리드.
/// 체크박스 열·본문 시작선·액션 열을 전 화면 공통으로 맞춘다.
class EdTaskRow extends StatelessWidget {
  const EdTaskRow({
    super.key,
    required this.title,
    this.done = false,
    this.onToggle,
    this.onTap,
    this.tags = const [],
    this.trailing,
    this.divider = true,
  });

  final String title;
  final bool done;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;
  final List<EdTag> tags;
  final Widget? trailing;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: divider
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: tk.line, width: 1)))
            : null,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: Ed.checkCol,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: EdCheck(done: done),
              ),
            ),
            const SizedBox(width: Ed.x10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppText.body(done ? tk.inkSoft : tk.ink).copyWith(
                      fontSize: 14,
                      decoration:
                          done ? TextDecoration.lineThrough : null,
                      decorationColor: tk.inkSoft,
                    ),
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: tags,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              SizedBox(
                  width: Ed.actionCol,
                  child: Align(
                      alignment: Alignment.topRight, child: trailing)),
          ],
        ),
      ),
    );
  }
}

/// 체크박스 — 각진 1px, 완료 시 잉크 채움 + 체크.
class EdCheck extends StatelessWidget {
  const EdCheck({super.key, required this.done, this.size = 18});
  final bool done;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: done ? tk.ink : tk.paper,
        border: Border.all(color: done ? tk.ink : tk.inkSoft, width: 1.4),
      ),
      child: done
          ? Icon(Icons.check, size: size * 0.7, color: tk.paper)
          : null,
    );
  }
}

/// 태그/칩 — hairline 박스, 색 면적 없이. today/urgent 는 포인트색 테두리.
class EdTag extends StatelessWidget {
  const EdTag(this.label, {super.key, this.kind = EdTagKind.normal});
  final String label;
  final EdTagKind kind;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final Color c = switch (kind) {
      EdTagKind.normal => tk.inkSoft,
      EdTagKind.today => tk.mark,
      EdTagKind.urgent => AppState.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: c, width: 1)),
      child: Text(label, style: AppText.chip(c).copyWith(fontSize: 9)),
    );
  }
}

enum EdTagKind { normal, today, urgent }

/// 메타 행 — 모노 라벨들을 가운뎃점(·)으로 잇는 한 줄. 시간/수치/날짜용.
class EdMetaRow extends StatelessWidget {
  const EdMetaRow(this.parts, {super.key, this.color, this.size = 10});
  final List<String> parts;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Text(
      parts.where((e) => e.trim().isNotEmpty).join('  ·  '),
      style: AppText.meta(color ?? tk.inkSoft, size: size),
    );
  }
}

/// 타임트래커 한 기록 — [시간 범위 · 소요] + 여러 줄 작업(— 불릿) +
/// 작성/수정 시각. 좁은 화면(compact)에서는 첫 줄 + "외 N개"로 접는다.
class EdTimeRecord extends StatelessWidget {
  const EdTimeRecord({
    super.key,
    required this.range,
    this.duration,
    required this.entries,
    this.written,
    this.edited,
    this.compact = false,
    this.divider = true,
  });

  final String range; // "12:30–13:00"
  final String? duration; // "30분"
  final List<String> entries; // 여러 줄 작업 내용
  final String? written; // "13:02"
  final String? edited; // "13:11"
  final bool compact;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final items = entries.where((e) => e.trim().isNotEmpty).toList();
    return Container(
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: tk.line, width: 1)))
          : null,
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 기록된 시간에는 포인트색 짧은 세로선.
          Container(
            width: 2,
            height: compact ? 16.0 : (14.0 + items.length * 18),
            margin: const EdgeInsets.only(top: 2, right: Ed.x10),
            color: tk.mark,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                EdMetaRow([range, if (duration != null) duration!]),
                const SizedBox(height: 5),
                if (compact)
                  Text(
                    items.isEmpty
                        ? '—'
                        : (items.length == 1
                            ? items.first
                            : '${items.first} 외 ${items.length - 1}개'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(tk.ink).copyWith(fontSize: 13),
                  )
                else
                  for (final e in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('— ',
                              style: AppText.body(tk.inkSoft)
                                  .copyWith(fontSize: 13)),
                          Expanded(
                            child: Text(e,
                                style: AppText.body(tk.ink)
                                    .copyWith(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                if (!compact && (written != null || edited != null)) ...[
                  const SizedBox(height: 3),
                  EdMetaRow([
                    if (written != null) '작성 $written',
                    if (edited != null) '수정 $edited',
                  ], color: tk.mark, size: 9),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 타임로그 빈 시간 행 — "09:00  기록 없음". 기록 없는 시간대도 표시한다.
class EdEmptyHour extends StatelessWidget {
  const EdEmptyHour({super.key, required this.label, this.divider = true});
  final String label; // "09:00"
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Container(
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: tk.line, width: 1)))
          : null,
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            child: Text(label, style: AppText.meta(tk.inkSoft, size: 10)),
          ),
          Text('기록 없음', style: AppText.meta(tk.inkSoft, size: 10)),
        ],
      ),
    );
  }
}

/// 간지 라벨(한자) — 예: "丙申日". 모노.
class EdGanjiLabel extends StatelessWidget {
  const EdGanjiLabel(this.date, {super.key, this.size = 11, this.color});
  final DateTime date;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        iljinLabel(date),
        style: AppText.meta(color ?? t(context).inkSoft, size: size),
      );
}

/// 달력 셀 — 양력 날짜 + 일진 한자 + 달 도형. today/선택 상태 지원.
class EdCalendarCell extends StatelessWidget {
  const EdCalendarCell({
    super.key,
    required this.date,
    this.today = false,
    this.selected = false,
    this.dim = false,
    this.showGanji = true,
    this.showMoon = true,
    this.onTap,
  });

  final DateTime date;
  final bool today;
  final bool selected;
  final bool dim;
  final bool showGanji;
  final bool showMoon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final fg = dim ? tk.inkSoft : tk.ink;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
        decoration: BoxDecoration(
          color: today ? tk.ink : Colors.transparent,
          border: selected && !today
              ? Border.all(color: tk.mark, width: 1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${date.day}',
                style: AppText.body(today ? tk.paper : fg)
                    .copyWith(fontSize: 13)),
            if (showGanji) ...[
              const SizedBox(height: 2),
              Text(iljinLabel(date),
                  style: AppText.meta(
                          today ? tk.paper : tk.inkSoft, size: 7.5)
                      .copyWith(letterSpacing: 0)),
            ],
            if (showMoon) ...[
              const SizedBox(height: 2),
              EdMoonPhase(
                phase: moonPhaseFraction(date),
                size: 9,
                color: today ? tk.paper : tk.mark,
                bg: today ? tk.ink : tk.paper,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 달 위상 도형 — 텍스트가 아니라 실제 도형으로 그린다.
/// [phase] 0=삭(신월) · 0.5=망(보름) · 1=삭. 0.25=상현, 0.75=하현.
class EdMoonPhase extends StatelessWidget {
  const EdMoonPhase({
    super.key,
    required this.phase,
    this.size = 12,
    this.color,
    this.bg,
  });

  final double phase;
  final double size;
  final Color? color;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return CustomPaint(
      size: Size(size, size),
      painter: _MoonPainter(
        phase: phase.clamp(0.0, 1.0),
        lit: color ?? tk.ink,
        dark: bg ?? tk.paper,
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  _MoonPainter({required this.phase, required this.lit, required this.dark});
  final double phase; // 0..1
  final Color lit;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final litPaint = Paint()..color = lit;
    final darkPaint = Paint()..color = dark;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, size.width * 0.08)
      ..color = lit;

    // 원판 테두리(항상).
    // 조명 비율: 0/1 → 0(삭, 빈 원), 0.5 → 1(보름, 꽉 참).
    final illum = 1 - (2 * phase - 1).abs(); // 0..1
    final waxing = phase < 0.5; // 차오름(오른쪽이 밝음)

    if (illum < 0.04) {
      // 삭 — 빈 원(테두리만).
      canvas.drawCircle(c, r - ring.strokeWidth / 2, ring);
      return;
    }
    if (illum > 0.96) {
      // 보름 — 꽉 찬 원.
      canvas.drawCircle(c, r, litPaint);
      return;
    }

    // 반달~초승/그믐: 밝은 반원 + 터미네이터(타원)로 표현.
    canvas.drawCircle(c, r, litPaint);
    // 어두운 쪽을 덮는다.
    canvas.save();
    final path = Path();
    if (waxing) {
      // 왼쪽 절반이 어둡다.
      path.addRect(Rect.fromLTWH(0, 0, r, size.height));
    } else {
      path.addRect(Rect.fromLTWH(r, 0, r, size.height));
    }
    canvas.clipPath(path);
    canvas.drawCircle(c, r, darkPaint);
    canvas.restore();

    // 터미네이터 타원(밝음↔어둠 경계) — illum 에 따라 폭이 변한다.
    final ex = r * (1 - illum); // 타원 반가로축(0=보름에 가까움)
    final ellipse = Rect.fromCenter(center: c, width: ex * 2, height: r * 2);
    // 초승/그믐(illum<0.5)일 땐 밝은 초승달, 볼록달(illum>0.5)일 땐 어두운 타원.
    if (illum < 0.5) {
      // 밝은 쪽에 얇은 초승 — 어두운 타원으로 다시 깎는다.
      canvas.drawOval(ellipse, darkPaint);
    } else {
      canvas.drawOval(ellipse, litPaint);
    }
  }

  @override
  bool shouldRepaint(_MoonPainter old) =>
      old.phase != phase || old.lit != lit || old.dark != dark;
}

/// 날짜 → 달 위상 비율(0..1). 삭망월(29.53059일) 근사.
/// 기준 삭(신월): 2000-01-06 18:14 UTC.
double moonPhaseFraction(DateTime d) {
  const synodic = 29.530588853;
  final ref = DateTime.utc(2000, 1, 6, 18, 14);
  final days = d.toUtc().difference(ref).inSeconds / 86400.0;
  final p = (days % synodic) / synodic;
  return p < 0 ? p + 1 : p;
}

/// 채움 버튼 — 잉크 반전(각짐). primary 액션용.
class EdButton extends StatelessWidget {
  const EdButton({
    super.key,
    required this.label,
    this.onTap,
    this.filled = true,
    this.danger = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool danger;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final Color bg = danger
        ? AppState.error
        : (filled ? tk.ink : Colors.transparent);
    final Color fg = filled || danger ? tk.paper : tk.ink;
    final child = Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: filled || danger
            ? null
            : Border.all(color: tk.ink, width: 1),
      ),
      child: Text(label,
          style: AppText.body(fg)
              .copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
    );
    final tappable = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: tappable) : tappable;
  }
}

/// 에디토리얼 바텀시트 표시 — 각진 상단, 핸들바, 공통 패딩.
/// (앱 전역 bottomSheetTheme 가 이미 각짐/무틴트를 강제하므로 얇게 감싼다.)
Future<T?> showEditorialSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t(context).paper,
    builder: (ctx) {
      final tk = t(ctx);
      final content = Padding(
        padding: EdgeInsets.only(
          left: Ed.gutter,
          right: Ed.gutter,
          top: Ed.x12,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + Ed.x24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 2,
                margin: const EdgeInsets.only(bottom: Ed.x16),
                color: tk.ink,
              ),
            ),
            Flexible(child: builder(ctx)),
          ],
        ),
      );
      return scrollable
          ? SingleChildScrollView(child: content)
          : content;
    },
  );
}
