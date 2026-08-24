import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/constants.dart';
import '../../core/editorial.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import 'schedule_edit_sheet.dart';

/// 주간 플랜 — 이번 주(일~토) 7일을 한눈에. 각 날짜에 일정 담기·완료 토글.
/// 기존 일정 repo 를 재활용한다.
class WeeklyPlanBody extends ConsumerStatefulWidget {
  const WeeklyPlanBody({super.key});

  @override
  ConsumerState<WeeklyPlanBody> createState() => _WeeklyPlanBodyState();
}

class _WeeklyPlanBodyState extends ConsumerState<WeeklyPlanBody> {
  late DateTime _weekStart; // 그 주의 일요일

  @override
  void initState() {
    super.initState();
    final now = todayDate();
    _weekStart = now.subtract(Duration(days: now.weekday % 7)); // 일=0
  }

  void _shiftWeek(int delta) =>
      setState(() => _weekStart = _weekStart.add(Duration(days: 7 * delta)));

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final today = todayDate();
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final ranged = ref
            .watch(schedulesInRangeProvider((start: _weekStart, end: weekEnd)))
            .valueOrNull ??
        const [];
    final byDate = <DateTime, List>{};
    for (final s in ranged) {
      final d = dateOnly(s.date);
      (byDate[d] ??= []).add(s);
    }

    return Container(
      color: tk.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 주 이동 헤더 (레퍼런스 .date-nav — ‹ / 가운데 제목+부제 / ›)
          _dateNav(
            tk,
            title:
                '${DateFormat('M.d').format(_weekStart)} – ${DateFormat('M.d').format(weekEnd)}',
            subtitle: '이번 주 일정',
            onPrev: () => _shiftWeek(-1),
            onNext: () => _shiftWeek(1),
            onCenter: () => setState(() => _weekStart =
                today.subtract(Duration(days: today.weekday % 7))),
          ),
          // 기준 HTML .week-schedule-scroll — 요일 컬럼 + 카드 가로 스크롤.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < 7; i++)
                    _dayColumn(
                      tk,
                      _weekStart.add(Duration(days: i)),
                      today,
                      byDate[_weekStart.add(Duration(days: i))] ?? const [],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateNav(
    AppTokens tk, {
    required String title,
    required String subtitle,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    VoidCallback? onCenter,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 12),
        child: Row(
          children: [
            _arrow(tk, '‹', onPrev),
            Expanded(
              child: GestureDetector(
                onTap: onCenter,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Text(title,
                        textAlign: TextAlign.center,
                        style: AppText.hTitle(tk.ink).copyWith(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        textAlign: TextAlign.center,
                        style: AppText.meta(tk.inkSoft, size: 10)),
                  ],
                ),
              ),
            ),
            _arrow(tk, '›', onNext),
          ],
        ),
      );

  // 기준 HTML .week-card 색 팔레트 (sage/blue/ochre/violet/rose).
  static const _weekCardColors = [
    Color(0xFF728D78),
    Color(0xFF6F86A7),
    Color(0xFFAA8B57),
    Color(0xFF8F6F86),
    Color(0xFFB77568),
  ];

  Widget _dayColumn(AppTokens tk, DateTime day, DateTime today, List items) {
    final isToday = day == today;
    final sunday = day.weekday % 7 == 0;
    final sorted = [...items]..sort((a, b) => a.startMin.compareTo(b.startMin));

    return Container(
      width: 128,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isToday ? tk.paper2 : Colors.transparent,
        border: Border.all(color: isToday ? tk.ink : tk.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 컬럼 헤더 — 요일 + 큰 날짜.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(DateFormat('E', 'ko').format(day),
                  style: AppText.metaSans(
                      sunday ? tk.mark : tk.inkSoft, size: 10)),
              Text('${day.day}',
                  style: AppText.serif(isToday ? tk.mark : tk.ink,
                      size: 16, height: 1.0)),
            ],
          ),
          const SizedBox(height: 8),
          for (var j = 0; j < sorted.length; j++)
            _weekCard(tk, sorted[j],
                _weekCardColors[j % _weekCardColors.length]),
          // 담기 (+)
          GestureDetector(
            onTap: () => showScheduleEditSheet(context, date: day),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('＋', style: AppText.glyph(tk.inkSoft, size: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekCard(AppTokens tk, dynamic s, Color color) {
    final time = (s.allDay as bool) ? '종일' : minToShort(s.startMin as int);
    return GestureDetector(
      onTap: () => showScheduleEditSheet(context, existing: s),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
        decoration: BoxDecoration(
          color: tk.paper2,
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(time, style: AppText.metaSans(tk.inkSoft, size: 9)),
            const SizedBox(height: 2),
            Text(s.title as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(tk.ink).copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _arrow(AppTokens tk, String g, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Text(g, style: AppText.glyph(tk.inkSoft, size: 20)),
        ),
      );
}
