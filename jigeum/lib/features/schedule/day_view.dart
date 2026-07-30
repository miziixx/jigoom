import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/almanac.dart';
import '../../core/constants.dart';
import '../../core/editorial.dart';
import '../../core/journal.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import 'schedule_edit_sheet.dart';

/// 데이 — 하루 전체를 한 화면에. 날짜 이동(‹ ›) + 그날의 모든 기록을
/// 분류(한글 태그 + 배경색 칩)해서 보여준다.
/// 두 가지 보기: 통합(시간 흐름 하나로) / 섹션(종류별 묶음). 기본 통합.
/// (기존 plan·day·schedule 을 하나로 합침.)
class DayView extends ConsumerStatefulWidget {
  const DayView({super.key});

  @override
  ConsumerState<DayView> createState() => _DayViewState();
}

/// 기록 분류. 각 분류는 한글 태그(풀 네임) + 색으로 구분.
enum _Cat { done, habit, routine, memo, sched, log }

String _label(_Cat c) => switch (c) {
      _Cat.done => '한 일',
      _Cat.habit => '습관',
      _Cat.routine => '루틴',
      _Cat.memo => '메모',
      _Cat.sched => '일정',
      _Cat.log => '기록',
    };

String _labelEng(_Cat c) => switch (c) {
      _Cat.done => 'DONE',
      _Cat.habit => 'HABIT',
      _Cat.routine => 'ROUTINE',
      _Cat.memo => 'MEMO',
      _Cat.sched => 'SCHEDULE',
      _Cat.log => 'LOG',
    };

Color _catColor(_Cat c, AppTokens tk) => switch (c) {
      _Cat.done => AppState.success,
      _Cat.habit => tk.mark,
      _Cat.routine => AppState.warning,
      _Cat.memo => tk.inkSoft,
      _Cat.sched => Color.lerp(tk.inkSoft, tk.ink, 0.45)!,
      _Cat.log => tk.ink,
    };

/// 한 줄 기록(칩) 하나의 데이터.
class _Rec {
  const _Rec(
    this.cat,
    this.title, {
    this.minute,
    this.completedAt,
    this.done = false,
    this.onToggle,
    this.checkable = false,
    this.bullets = const [],
    this.range,
    this.written,
    this.duration,
  });
  final _Cat cat;
  final String title;
  final int? minute; // 0~1439, null=시간 없음(정렬 뒤로)
  final DateTime? completedAt;
  final bool done;
  final VoidCallback? onToggle; // null=토글 불가(읽기전용/오늘 아님)
  final bool checkable; // 체크박스 표시 여부
  // 트래커 기록(펼침)용 — 레퍼런스 .time-row.tracker-row.
  final List<String> bullets; // 작업 여러 줄('—' 불릿)
  final String? range; // "12:30–13:00"
  final String? written; // "작성 13:02 · 수정 13:11"
  final String? duration; // 우측 소요("30분")

  bool get isRecord => range != null;
}

class _DayViewState extends ConsumerState<DayView> {
  DateTime _date = todayDate();
  int _view = 0; // 0 통합 · 1 섹션

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final isToday = _date == todayDate();

    // ── 데이터 (선택한 날 기준) ──
    final schedules =
        ref.watch(schedulesForDateProvider(_date)).valueOrNull ?? const [];
    final wins = ref.watch(winsForDateProvider(_date)).valueOrNull ?? const [];
    final ticks =
        ref.watch(habitTicksOnDateProvider(_date)).valueOrNull ?? const [];
    final habits = ref.watch(habitsProvider).valueOrNull ?? const [];
    final habitName = {for (final h in habits) h.id: h.title};
    final openNodes =
        ref.watch(openNodesForDateProvider(_date)).valueOrNull ?? const [];
    final groups = ref.watch(routineGroupsProvider).valueOrNull ?? const [];
    final steps = ref.watch(routineStepsProvider).valueOrNull ?? const [];
    final blocks =
        ref.watch(timeBlocksForDateProvider(_date)).valueOrNull ?? const [];

    final groupName = {for (final g in groups) g.id: g.title};
    final wd = _date.weekday;
    final dayGroupIds = {
      for (final g in groups)
        if (g.active && g.weekdays.split(',').contains('$wd')) g.id
    };
    bool routineDone(RoutineStep s) =>
        s.lastDone != null && dateOnly(s.lastDone!) == _date;

    // ── 기록 목록 만들기 ──
    final recs = <_Rec>[
      for (final s in schedules)
        _Rec(_Cat.sched, s.title,
            minute: s.startMin,
            completedAt: s.doneAt,
            done: s.done,
            checkable: true,
            onToggle: () =>
                ref.read(scheduleRepoProvider).toggleDone(s.id, !s.done)),
      for (final n in wins)
        _Rec(_Cat.done, n.title,
            minute: n.doneAt == null
                ? null
                : n.doneAt!.hour * 60 + n.doneAt!.minute,
            completedAt: n.doneAt),
      for (final tk2 in ticks)
        if ((habitName[tk2.habitId] ?? '').isNotEmpty)
          _Rec(_Cat.habit, habitName[tk2.habitId]!,
              minute: tk2.completedAt == null
                  ? null
                  : tk2.completedAt!.hour * 60 + tk2.completedAt!.minute,
              completedAt: tk2.completedAt,
              done: true,
              checkable: true),
      for (final s in steps)
        if (dayGroupIds.contains(s.groupId))
          _Rec(
            _Cat.routine,
            groupName[s.groupId] == null
                ? s.title
                : '${groupName[s.groupId]} · ${s.title}',
            minute: !routineDone(s) || s.lastDoneAt == null
                ? null
                : s.lastDoneAt!.hour * 60 + s.lastDoneAt!.minute,
            completedAt: routineDone(s) ? s.lastDoneAt : null,
            done: routineDone(s),
            checkable: true,
            onToggle: isToday
                ? () => ref.read(routineBuilderRepoProvider).toggleStepDone(s)
                : null,
          ),
      for (final n in openNodes)
        if (n.type == NodeType.memo) _Rec(_Cat.memo, n.title),
      for (final b in blocks)
        if (b.content.trim().isNotEmpty) _logRec(b),
    ];

    return Container(
      color: tk.paper,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _dateHeader(tk),
          _viewBar(tk),
          if (recs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: emptyNote(context, '이 날 기록이 없어요'),
            )
          else if (_view == 0)
            ..._feed(tk, recs)
          else
            ..._sections(tk, recs),
        ],
      ),
    );
  }

  // ── 통합 피드: 시간 있는 건 시간순, 없는 건 뒤로 ──
  List<Widget> _feed(AppTokens tk, List<_Rec> recs) {
    final timed = [...recs.where((r) => r.minute != null)]
      ..sort((a, b) => a.minute!.compareTo(b.minute!));
    final untimed = recs.where((r) => r.minute == null).toList();
    final feed = [...timed, ...untimed];
    return [
      // 레퍼런스 .timeline — 상단 잉크선, 각 행에 시간·노드점·본문(플랫).
      Container(
        margin: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
        decoration:
            BoxDecoration(border: Border(top: BorderSide(color: tk.ink))),
        child: Column(children: [
          for (var i = 0; i < feed.length; i++)
            _timelineRow(tk, feed[i], isLast: i == feed.length - 1),
        ]),
      ),
      const SizedBox(height: 4),
    ];
  }

  // ── 섹션: 종류별 묶음(빈 종류 숨김) ──
  List<Widget> _sections(AppTokens tk, List<_Rec> recs) {
    const order = [
      _Cat.done,
      _Cat.habit,
      _Cat.routine,
      _Cat.memo,
      _Cat.log,
      _Cat.sched
    ];
    final out = <Widget>[];
    for (final c in order) {
      final rows = recs.where((r) => r.cat == c).toList();
      if (c == _Cat.sched && rows.isNotEmpty) {
        rows.sort((a, b) => (a.minute ?? 0).compareTo(b.minute ?? 0));
      }
      if (rows.isEmpty) continue;
      out.add(SectionLabel(_labelEng(c), count: rows.length));
      out.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: kGutter),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++)
            _timelineRow(tk, rows[i], isLast: i == rows.length - 1),
        ]),
      ));
    }
    return out;
  }

  // 타임트래커 블록 → 펼침 기록 _Rec (제목 + 불릿 + 범위 + 작성/수정).
  _Rec _logRec(TimeBlock b) {
    final lines = b.content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final start = blockLabel(b.block);
    final end = blockLabel((b.block + 1) % 48 == 0 ? 48 : b.block + 1);
    return _Rec(
      _Cat.log,
      lines.isEmpty ? '기록' : lines.first,
      minute: b.block * 30,
      bullets: lines.length > 1 ? lines.sublist(1) : const [],
      range: '$start–$end',
      written: b.updatedAt != null
          ? '작성 ${DateFormat('HH:mm').format(b.updatedAt!)}'
          : null,
      duration: '30분',
    );
  }

  // 소스/상태 메타 — 예: "일정 · 완료", "습관 · 완료".
  String _metaFor(_Rec r) {
    final base = _label(r.cat);
    if (r.completedAt != null) {
      return '$base · 완료 ${DateFormat('HH:mm').format(r.completedAt!)}';
    }
    if (r.done) return '$base · 완료';
    return base;
  }

  // ── 타임라인 한 줄 (레퍼런스 .time-row: 시간 | □체크박스+연결선 | 본문 | 우측 소요) ──
  Widget _timelineRow(AppTokens tk, _Rec r, {required bool isLast}) {
    final titleStyle = AppText.body(
            r.done ? tk.ink.withValues(alpha: 0.5) : tk.ink)
        .copyWith(fontSize: 13, fontWeight: FontWeight.w600);
    return IntrinsicHeight(
      child: Container(
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 시간 라벨(모노).
            Padding(
              padding: const EdgeInsets.only(top: 13),
              child: SizedBox(
                width: 43,
                child: Text(r.minute != null ? minToShort(r.minute!) : '·',
                    style: AppText.meta(tk.inkSoft, size: 9)),
              ),
            ),
            const SizedBox(width: 6),
            // 체크박스(왼쪽) + 아래 연결선(마지막 행은 선 없음).
            SizedBox(
              width: 18,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: r.checkable ? r.onToggle : null,
                    child: EdCheck(done: r.done, size: 17),
                  ),
                  if (!isLast)
                    Expanded(
                        child: Center(
                            child: Container(width: 1, color: tk.line))),
                ],
              ),
            ),
            const SizedBox(width: 11),
            // 본문.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(r.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle),
                    if (r.isRecord) ...[
                      for (final line in r.bullets)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('— ',
                                  style: AppText.body(tk.inkSoft)
                                      .copyWith(fontSize: 12)),
                              Expanded(
                                child: Text(line,
                                    style: AppText.body(tk.ink)
                                        .copyWith(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 5),
                      Text(r.range!,
                          style: AppText.metaSans(tk.inkSoft, size: 8)),
                      if (r.written != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(r.written!,
                              style: AppText.metaSans(
                                  tk.inkSoft.withValues(alpha: 0.7),
                                  size: 8)),
                        ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(_metaFor(r),
                          style: AppText.metaSans(tk.inkSoft, size: 8)),
                    ],
                  ],
                ),
              ),
            ),
            // 우측 소요(기록만) — 레퍼런스 30분.
            if (r.duration != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 13),
                child:
                    Text(r.duration!, style: AppText.meta(tk.inkSoft, size: 9)),
              ),
          ],
        ),
      ),
    );
  }

  // ── 보기 전환 바 (통합 / 섹션) + 일정 추가 ──
  Widget _viewBar(AppTokens tk) {
    Widget tab(int i, String label) {
      final sel = _view == i;
      return GestureDetector(
        onTap: () => setState(() => _view = i),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            padding: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: sel ? tk.ink : Colors.transparent, width: 1.5),
              ),
            ),
            child: Text(label,
                style: AppText.nav(sel ? tk.ink : tk.inkSoft, active: sel)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 2),
      child: Row(
        children: [
          tab(0, '통합'),
          tab(1, '섹션'),
          const Spacer(),
          GestureDetector(
            onTap: () => showScheduleEditSheet(context, date: _date),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('+ 일정', style: AppText.meta(tk.ink, size: 12)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 날짜 헤더 (‹ M월 d일 › + 음력·일진·별자리·달·손없는날) ──
  Widget _dateHeader(AppTokens tk) {
    final today = todayDate();
    final settings = ref.watch(settingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
          child: Row(
            children: [
              _arrow(
                  tk,
                  '‹',
                  () => setState(
                      () => _date = _date.subtract(const Duration(days: 1)))),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _date = today),
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    DateFormat('M월 d일 (E)', 'ko').format(_date) +
                        (_date == today ? ' · 오늘' : ''),
                    textAlign: TextAlign.center,
                    style: AppText.hTitle(tk.ink),
                  ),
                ),
              ),
              _arrow(
                  tk,
                  '›',
                  () => setState(
                      () => _date = _date.add(const Duration(days: 1)))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 3, kGutter, 0),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 5,
            runSpacing: 2,
            children: [
              Text(
                '${[
                  lunarLabel(_date),
                  if (settings.showSaju) iljinLabel(_date),
                  if (settings.showZodiac) byeoljariLabel(_date),
                ].join(' · ')} ·',
                style: AppText.metaSans(tk.inkSoft),
              ),
              MoonPhaseGlyph(date: _date, size: 13),
              Text(moonName(_date), style: AppText.metaSans(tk.inkSoft)),
              if (isSonEomneunNal(_date))
                Text('손없는날', style: AppText.chip(tk.mark)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _arrow(AppTokens tk, String g, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: tk.line),
          ),
          child: Text(g, style: AppText.glyph(tk.inkSoft, size: 16)),
        ),
      );
}

/// 달 위상 글리프 — 그날 음력 일(1~30) 기준 달 모양을 직관적으로 그린다.
/// 밝은 면은 종이/잉크 밝은색, 그림자 면은 어두운색으로 위상(초승·상현·보름…)을 표현.
class MoonPhaseGlyph extends StatelessWidget {
  const MoonPhaseGlyph({super.key, required this.date, this.size = 13});
  final DateTime date;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return CustomPaint(
      size: Size.square(size),
      painter: _MoonPainter(
        day: lunarOf(date).day,
        shadow: tk.isDark ? tk.paper2 : tk.inkSoft,
        lit: tk.isDark ? tk.ink : tk.paper,
        outline: tk.inkSoft,
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  _MoonPainter({
    required this.day,
    required this.shadow,
    required this.lit,
    required this.outline,
  });
  final int day; // 음력 일 1~30
  final Color shadow;
  final Color lit;
  final Color outline;

  static const double _period = 29.53;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final phase = ((day - 1) % _period) / _period; // 0=삭 · 0.5=보름
    final waxing = phase < 0.5; // 차오르는 중이면 오른쪽이 밝음
    // 명암 경계(터미네이터) 타원의 가로 반지름(부호 포함).
    final xr = math.cos(phase * 2 * math.pi) * r;
    final exr = xr.abs().clamp(0.5, r).toDouble();

    // 전체 원을 그림자(어두운 면)로 채운다.
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = shadow
          ..isAntiAlias = true);

    // 밝은(빛 받는) 반쪽을 얹는다.
    final lp = Path()..moveTo(c.dx, c.dy - r);
    if (waxing) {
      lp.arcToPoint(Offset(c.dx, c.dy + r),
          radius: Radius.circular(r), clockwise: true);
      lp.arcToPoint(Offset(c.dx, c.dy - r),
          radius: Radius.elliptical(exr, r), clockwise: xr < 0);
    } else {
      lp.arcToPoint(Offset(c.dx, c.dy + r),
          radius: Radius.circular(r), clockwise: false);
      lp.arcToPoint(Offset(c.dx, c.dy - r),
          radius: Radius.elliptical(exr, r), clockwise: xr >= 0);
    }
    lp.close();
    canvas.drawPath(
        lp,
        Paint()
          ..color = lit
          ..isAntiAlias = true);

    // 테두리.
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant _MoonPainter old) =>
      old.day != day ||
      old.shadow != shadow ||
      old.lit != lit ||
      old.outline != outline;
}
