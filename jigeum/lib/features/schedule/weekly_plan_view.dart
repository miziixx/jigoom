import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/almanac.dart';
import '../../core/constants.dart';
import '../../core/editorial.dart';
import '../../core/journal.dart';
import '../../core/settings_controller.dart';
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

    // 습관·기록 인디케이터 (그날 완료 습관 수 / 기록 블록 수).
    final ticks = ref
            .watch(habitTicksInRangeProvider((start: _weekStart, end: weekEnd)))
            .valueOrNull ??
        const [];
    final blocks = ref
            .watch(timeBlocksInRangeProvider((start: _weekStart, end: weekEnd)))
            .valueOrNull ??
        const [];
    final habitCount = <DateTime, int>{};
    for (final tick in ticks) {
      final d = dateOnly(tick.date);
      habitCount[d] = (habitCount[d] ?? 0) + 1;
    }
    final recordCount = <DateTime, int>{};
    for (final b in blocks) {
      final d = dateOnly(b.date);
      recordCount[d] = (recordCount[d] ?? 0) + 1;
    }

    final settings = ref.watch(settingsProvider);
    return Container(
      color: tk.paper,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // 주 이동 헤더 (레퍼런스 .date-nav — ‹ / 가운데 제목+부제 / ›)
          _dateNav(
            tk,
            title:
                '${DateFormat('M.d').format(_weekStart)} – ${DateFormat('M.d').format(weekEnd)}',
            subtitle: '이번 주 일정과 기록',
            onPrev: () => _shiftWeek(-1),
            onNext: () => _shiftWeek(1),
            onCenter: () => setState(() => _weekStart =
                today.subtract(Duration(days: today.weekday % 7))),
          ),
          // 레퍼런스 .week-list — 상단 잉크선, 각 행 하단 hairline.
          Container(
            margin: const EdgeInsets.symmetric(horizontal: kGutter),
            decoration:
                BoxDecoration(border: Border(top: BorderSide(color: tk.ink))),
            child: Column(
              children: [
                for (var i = 0; i < 7; i++)
                  _dayRow(
                    tk,
                    _weekStart.add(Duration(days: i)),
                    today,
                    byDate[_weekStart.add(Duration(days: i))] ?? const [],
                    settings,
                    habitCount[_weekStart.add(Duration(days: i))] ?? 0,
                    recordCount[_weekStart.add(Duration(days: i))] ?? 0,
                  ),
              ],
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

  Widget _dayRow(AppTokens tk, DateTime day, DateTime today, List items,
      AppSettings settings, int habitDone, int records) {
    final isToday = day == today;
    final sunday = day.weekday % 7 == 0;
    final sorted = [...items]..sort((a, b) => a.startMin.compareTo(b.startMin));
    final first = sorted.isEmpty ? null : sorted.first;

    // 정보 강조줄: 오늘이면 '오늘', 아니면 첫 일정 제목 / 없으면 '일정 없음'.
    final infoStrong =
        isToday ? '오늘' : (first != null ? first.title : '일정 없음');
    // 메타줄: [첫 일정 시각] · 기록 N개 · [간지/음력].
    final meta = <String>[
      if (first != null && !first.allDay) minToShort(first.startMin),
      '기록 $records개',
      if (habitDone > 0) '습관 $habitDone개',
      if (settings.showSaju) iljinLabel(day) else lunarLabel(day),
    ];

    return Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 오늘 좌측 강조 바.
          Container(width: 2, height: 42, color: isToday ? tk.mark : Colors.transparent),
          const SizedBox(width: 9),
          // 날짜 열 — 세리프 큰 숫자 + 요일.
          SizedBox(
            width: 46,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${day.day}',
                    style: AppText.serif(isToday ? tk.mark : tk.ink,
                        size: 17, height: 1.0)),
                const SizedBox(width: 3),
                Text(DateFormat('E', 'ko').format(day),
                    style: AppText.metaSans(
                        sunday ? tk.mark : tk.inkSoft, size: 8)),
              ],
            ),
          ),
          const SizedBox(width: 9),
          // 정보 열.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: first != null
                  ? () => showScheduleEditSheet(context, existing: first)
                  : () => showScheduleEditSheet(context, date: day),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isToday)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('TODAY',
                            style: AppText.meta(tk.mark, size: 7)
                                .copyWith(letterSpacing: 1.2)),
                      ),
                    Text(infoStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(tk.ink).copyWith(fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(meta.join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.metaSans(tk.inkSoft, size: 8)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 원형 + 버튼 (레퍼런스 .mini-plus).
          GestureDetector(
            onTap: () => showScheduleEditSheet(context, date: day),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tk.line, width: 1),
              ),
              child: Text('＋',
                  style: AppText.glyph(tk.inkSoft, size: 12)),
            ),
          ),
        ],
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
