import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/almanac.dart';
import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import 'schedule_edit_sheet.dart';

/// 데이 — 하루 전체를 한 화면에. 날짜 이동(‹ ›) + 모든 기록을 분류(글리프·색)해
/// 보여주고, 아래에 일정(리스트·타임라인·클락 3보기)을 붙인다.
/// (기존 plan·day·schedule 을 하나로 합침.)
class DayView extends ConsumerStatefulWidget {
  const DayView({super.key});

  @override
  ConsumerState<DayView> createState() => _DayViewState();
}

/// 기록 분류 — 글리프 + 색으로 구분. 색은 6토큰 + 소량 기능색으로 절제.
/// (일정 ○ 회색 · 한 일 ● 초록 · 습관 ◆ 포인트색 · 메모 ◇ 연회색 · 루틴 ✦ 호박색)
enum _Cat { schedule, done, habit, memo, routine }

String _glyph(_Cat c) => switch (c) {
      _Cat.schedule => '○',
      _Cat.done => '●',
      _Cat.habit => '◆',
      _Cat.memo => '◇',
      _Cat.routine => '✦',
    };

Color _color(_Cat c, AppTokens tk) => switch (c) {
      _Cat.schedule => tk.inkSoft,
      _Cat.done => AppState.success,
      _Cat.habit => tk.mark,
      _Cat.memo => tk.inkSoft,
      _Cat.routine => AppState.warning,
    };

class _DayViewState extends ConsumerState<DayView> {
  DateTime _date = todayDate();
  int _schedView = 0; // 0 리스트 · 1 타임라인 · 2 클락

  @override
  Widget build(BuildContext context) {
    final tk = t(context);

    // 데이터 소스 — 전부 선택한 날(_date) 기준.
    final schedules =
        ref.watch(schedulesForDateProvider(_date)).valueOrNull ?? const [];
    final sortedSched = [...schedules]
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    final wins = ref.watch(winsForDateProvider(_date)).valueOrNull ?? const [];

    final ticks =
        ref.watch(habitTicksOnDateProvider(_date)).valueOrNull ?? const [];
    final habits = ref.watch(habitsProvider).valueOrNull ?? const [];
    final habitName = {for (final h in habits) h.id: h.title};
    final doneHabits = ticks
        .map((tk2) => habitName[tk2.habitId] ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final openNodes =
        ref.watch(openNodesForDateProvider(_date)).valueOrNull ?? const [];
    final memos =
        openNodes.where((n) => n.type == NodeType.memo).toList();

    final groups = ref.watch(routineGroupsProvider).valueOrNull ?? const [];
    final steps = ref.watch(routineStepsProvider).valueOrNull ?? const [];
    final wd = _date.weekday; // 1(월)~7(일)
    final dayGroupIds = {
      for (final g in groups)
        if (g.active && g.weekdays.split(',').contains('$wd')) g.id
    };
    final daySteps =
        steps.where((s) => dayGroupIds.contains(s.groupId)).toList();
    bool routineDone(RoutineStep s) =>
        s.lastDone != null && dateOnly(s.lastDone!) == _date;

    final blocks =
        ref.watch(timeBlocksForDateProvider(_date)).valueOrNull ?? const [];
    final logs = blocks.where((b) => b.content.isNotEmpty).toList()
      ..sort((a, b) => a.block.compareTo(b.block));

    final isToday = _date == todayDate();

    return Container(
      color: tk.paper,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _dateHeader(tk),
          _legend(tk),

          // ── 한 일 (완료 노드) ●
          SectionLabel('DONE', count: wins.length),
          if (wins.isEmpty)
            emptyNote(context, '이 날 완료한 일이 없어요')
          else
            for (final n in wins)
              _record(tk, cat: _Cat.done, title: n.title, strike: false),

          // ── 습관 (완료 틱) ◆
          SectionLabel('HABIT', count: doneHabits.length),
          if (doneHabits.isEmpty)
            emptyNote(context, '이 날 완료한 습관이 없어요')
          else
            for (final name in doneHabits)
              _record(tk, cat: _Cat.habit, title: name),

          // ── 루틴 (요일 루틴 스텝) ✦
          SectionLabel('ROUTINE', count: daySteps.length),
          if (daySteps.isEmpty)
            emptyNote(context, '이 요일 루틴이 없어요')
          else
            for (final s in daySteps)
              _record(
                tk,
                cat: _Cat.routine,
                title: s.title,
                lead: s.trigger.isEmpty ? null : s.trigger,
                strike: routineDone(s),
                trailing: _check(
                  tk,
                  done: routineDone(s),
                  onTap: isToday
                      ? () => ref
                          .read(routineBuilderRepoProvider)
                          .toggleStepDone(s)
                      : null,
                ),
              ),

          // ── 메모 ◇
          SectionLabel('MEMO', count: memos.length),
          if (memos.isEmpty)
            emptyNote(context, '이 날 메모가 없어요')
          else
            for (final n in memos)
              _record(tk, cat: _Cat.memo, title: n.title),

          // ── 로그 (타임트래커) — 데이의 기록
          SectionLabel('LOG', count: logs.length),
          if (logs.isEmpty)
            emptyNote(context, '이 날 기록이 없어요')
          else
            for (final b in logs)
              Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 44,
                        child: Text(blockLabel(b.block),
                            style: AppText.meta(tk.inkSoft))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(b.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(tk.ink))),
                  ],
                ),
              ),

          // ── 일정 (로그 아래) — 리스트 / 타임라인 / 클락 3보기 ○
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 20, kGutter, 0),
            child: Row(
              children: [
                Expanded(
                    child: SectionLabel('SCHEDULE',
                        count: sortedSched.length)),
                GestureDetector(
                  onTap: () => showScheduleEditSheet(context, date: _date),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text('+ 일정', style: AppText.meta(tk.ink, size: 12)),
                  ),
                ),
              ],
            ),
          ),
          _schedTabs(tk),
          if (sortedSched.isEmpty)
            emptyNote(context, '이 날 일정이 없어요')
          else
            _schedBody(tk, sortedSched),
        ],
      ),
    );
  }

  // ── 날짜 헤더 (‹ M월 d일 › + 음력·일진·별자리·달·손없는날)
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
              _arrow(tk, '‹',
                  () => setState(() => _date = _date.subtract(const Duration(days: 1)))),
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
              _arrow(tk, '›',
                  () => setState(() => _date = _date.add(const Duration(days: 1)))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  [
                    lunarLabel(_date),
                    if (settings.showSaju) iljinLabel(_date),
                    if (settings.showZodiac) byeoljariLabel(_date),
                    moonName(_date),
                  ].join(' · '),
                  textAlign: TextAlign.center,
                  style: AppText.metaSans(tk.inkSoft),
                ),
              ),
              if (isSonEomneunNal(_date)) ...[
                const SizedBox(width: 8),
                Text('손없는날', style: AppText.chip(tk.mark)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── 범례 — 글리프·색이 무엇을 뜻하는지 한 줄로.
  Widget _legend(AppTokens tk) {
    Widget item(_Cat c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_glyph(c), style: AppText.metaSans(_color(c, tk), size: 12)),
            const SizedBox(width: 4),
            Text(label, style: AppText.meta(tk.inkSoft, size: 10)),
          ],
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          item(_Cat.done, '한 일'),
          item(_Cat.habit, '습관'),
          item(_Cat.routine, '루틴'),
          item(_Cat.memo, '메모'),
          item(_Cat.schedule, '일정'),
        ],
      ),
    );
  }

  // ── 분류 기록 한 줄 (글리프 + 색).
  Widget _record(
    AppTokens tk, {
    required _Cat cat,
    required String title,
    String? lead,
    bool strike = false,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(_glyph(cat),
                style: AppText.metaSans(_color(cat, tk), size: 13)),
          ),
          const SizedBox(width: 8),
          if (lead != null) ...[
            Text(lead, style: AppText.meta(tk.inkSoft, size: 10)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(strike ? tk.inkSoft : tk.ink).copyWith(
                  decoration:
                      strike ? TextDecoration.lineThrough : null,
                  decorationColor: tk.inkSoft),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _check(AppTokens tk,
          {required bool done, VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Text(done ? '■' : '□',
            style: AppText.glyph(onTap == null ? tk.inkSoft : tk.ink)),
      );

  Widget _arrow(AppTokens tk, String g, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(g, style: AppText.glyph(tk.inkSoft, size: 20)),
        ),
      );

  // ── 일정 3보기 탭
  Widget _schedTabs(AppTokens tk) {
    Widget tab(int i, String label) {
      final sel = _schedView == i;
      return GestureDetector(
        onTap: () => setState(() => _schedView = i),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Container(
            padding: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: sel ? tk.ink : Colors.transparent, width: 1.5),
              ),
            ),
            child:
                Text(label, style: AppText.nav(sel ? tk.ink : tk.inkSoft, active: sel)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
      child: Row(children: [
        tab(0, 'list'),
        tab(1, 'timeline'),
        tab(2, 'clock'),
      ]),
    );
  }

  Widget _schedBody(AppTokens tk, List<Schedule> items) {
    return switch (_schedView) {
      1 => _ScheduleTimeline(items: items),
      2 => _ScheduleClock(items: items, date: _date),
      _ => Column(children: [for (final s in items) _schedRow(tk, s)]),
    };
  }

  Widget _schedRow(AppTokens tk, Schedule s) => InkWell(
        onTap: () => showScheduleEditSheet(context, existing: s),
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tk.line, width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(_glyph(_Cat.schedule),
                    style: AppText.metaSans(_color(_Cat.schedule, tk),
                        size: 12)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text(minToShort(s.startMin),
                    style: AppText.meta(tk.inkSoft)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.title,
                    style: AppText.body(s.done ? tk.inkSoft : tk.ink).copyWith(
                        decoration:
                            s.done ? TextDecoration.lineThrough : null,
                        decorationColor: tk.inkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              GestureDetector(
                onTap: () =>
                    ref.read(scheduleRepoProvider).toggleDone(s.id, !s.done),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child:
                      Text(s.done ? '■' : '□', style: AppText.glyph(tk.ink)),
                ),
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────── 일정 타임라인
class _ScheduleTimeline extends StatelessWidget {
  const _ScheduleTimeline({required this.items});
  final List<Schedule> items;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final startH =
        ((items.map((s) => s.startMin).reduce(math.min)) ~/ 60).clamp(0, 23);
    final endH = ((items.map((s) => s.endMin).reduce(math.max)) / 60)
        .ceil()
        .clamp(1, 24);
    const rowH = 44.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 8),
      child: SizedBox(
        height: (endH - startH) * rowH + 8,
        child: Stack(
          children: [
            for (var h = startH; h <= endH; h++)
              Positioned(
                left: 0,
                right: 0,
                top: (h - startH) * rowH,
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text('${h.toString().padLeft(2, '0')}:00',
                          style: AppText.meta(tk.inkSoft, size: 10)),
                    ),
                    Expanded(child: Container(height: 1, color: tk.line)),
                  ],
                ),
              ),
            for (final s in items)
              Positioned(
                left: 48,
                right: 0,
                top: (s.startMin - startH * 60) / 60 * rowH,
                height: ((s.endMin - s.startMin) / 60 * rowH).clamp(18, 1440),
                child: GestureDetector(
                  onTap: () => showScheduleEditSheet(context, existing: s),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tk.paper2,
                      border: Border(
                          left: BorderSide(color: tk.ink, width: 2),
                          top: BorderSide(color: tk.line, width: 1),
                          right: BorderSide(color: tk.line, width: 1),
                          bottom: BorderSide(color: tk.line, width: 1)),
                    ),
                    child: Text(s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(tk.ink)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── 일정 클락
class _ScheduleClock extends StatelessWidget {
  const _ScheduleClock({required this.items, required this.date});
  final List<Schedule> items;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 8),
      child: SizedBox(
        height: 280,
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: _ClockPainter(
                items: items,
                ink: tk.ink,
                ring: tk.line,
                tickColor: tk.inkSoft,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(DateFormat('M.d').format(date),
                        style: AppText.hTitle(tk.ink)),
                    Text('${items.length} events',
                        style: AppText.meta(tk.inkSoft)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(
      {required this.items,
      required this.ink,
      required this.ring,
      required this.tickColor});
  final List<Schedule> items;
  final Color ink;
  final Color ring;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final ringR = r * 0.72;
    final bandW = r * 0.14;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ring;
    canvas.drawCircle(c, ringR + bandW * 0.9, ringPaint);

    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1;
    for (var h = 0; h < 24; h++) {
      final a = (h / 24) * 2 * math.pi - math.pi / 2;
      final outer = ringR + bandW * 0.9;
      final inner = outer - (h % 3 == 0 ? 8 : 4);
      canvas.drawLine(
        c + Offset(math.cos(a) * outer, math.sin(a) * outer),
        c + Offset(math.cos(a) * inner, math.sin(a) * inner),
        tickPaint,
      );
      if (h % 3 == 0) {
        final tp = TextPainter(
          text: TextSpan(
              text: '$h',
              style: TextStyle(
                  color: tickColor, fontSize: 10, fontFamily: 'monospace')),
          textDirection: TextDirection.ltr,
        )..layout();
        final lr = outer + 10;
        tp.paint(
          canvas,
          c +
              Offset(math.cos(a) * lr, math.sin(a) * lr) -
              Offset(tp.width / 2, tp.height / 2),
        );
      }
    }

    for (final s in items) {
      final startA = (s.startMin / 1440) * 2 * math.pi - math.pi / 2;
      final sweep = ((s.endMin - s.startMin) / 1440) * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = bandW
        ..strokeCap = StrokeCap.butt
        ..color = ink;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: ringR),
        startA,
        sweep <= 0 ? 0.02 : sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ClockPainter old) => old.items != items;
}
