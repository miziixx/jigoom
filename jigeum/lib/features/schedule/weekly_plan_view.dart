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

    return Container(
      color: tk.paper,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // 주 이동 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 6),
            child: Row(
              children: [
                _arrow(tk, '‹', () => _shiftWeek(-1)),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _weekStart =
                        today.subtract(Duration(days: today.weekday % 7))),
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      '${DateFormat('M.d').format(_weekStart)} – ${DateFormat('M.d').format(weekEnd)}',
                      textAlign: TextAlign.center,
                      style: AppText.hTitle(tk.ink),
                    ),
                  ),
                ),
                _arrow(tk, '›', () => _shiftWeek(1)),
              ],
            ),
          ),
          for (var i = 0; i < 7; i++)
            _dayRow(
              tk,
              _weekStart.add(Duration(days: i)),
              today,
              byDate[_weekStart.add(Duration(days: i))] ?? const [],
              ref.watch(settingsProvider),
              habitCount[_weekStart.add(Duration(days: i))] ?? 0,
              recordCount[_weekStart.add(Duration(days: i))] ?? 0,
            ),
        ],
      ),
    );
  }

  Widget _dayRow(AppTokens tk, DateTime day, DateTime today, List items,
      AppSettings settings, int habitDone, int records) {
    final isToday = day == today;
    final sunday = day.weekday % 7 == 0;
    final dowColor = sunday ? tk.mark : tk.inkSoft;
    final sorted = [...items]..sort((a, b) => a.startMin.compareTo(b.startMin));

    return Container(
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: tk.line))),
      padding: const EdgeInsets.symmetric(horizontal: kGutter, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 열
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(DateFormat('E', 'ko').format(day),
                        style: AppText.meta(dowColor, size: 11)),
                    const SizedBox(width: 6),
                    Text('${day.day}',
                        style: AppText.hTitle(isToday ? tk.mark : tk.ink)
                            .copyWith(fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    EdMoonPhase(
                        phase: moonPhaseFraction(day),
                        size: 9,
                        color: tk.inkSoft,
                        bg: tk.paper),
                    const SizedBox(width: 4),
                    Text(lunarShort(day),
                        style: AppText.metaSans(tk.inkSoft, size: 9)),
                  ],
                ),
                if (settings.showSaju)
                  Text(iljinLabel(day),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: AppText.metaSans(tk.inkSoft, size: 9)),
                if (settings.showZodiac)
                  Text(byeoljariLabel(day),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.metaSans(tk.inkSoft, size: 9)),
                if (isSonEomneunNal(day))
                  Text('손없는날', style: AppText.chip(tk.mark)),
                if (habitDone > 0 || records > 0) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (habitDone > 0) ...[
                        Text('✓', style: AppText.glyph(tk.mark, size: 11)),
                        Text('$habitDone',
                            style: AppText.metaSans(tk.inkSoft, size: 9)),
                      ],
                      if (habitDone > 0 && records > 0)
                        const SizedBox(width: 6),
                      if (records > 0) ...[
                        Text('■', style: AppText.glyph(tk.inkSoft, size: 9)),
                        const SizedBox(width: 2),
                        Text('$records',
                            style: AppText.metaSans(tk.inkSoft, size: 9)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 일정 열
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sorted.isEmpty)
                  Text('—', style: AppText.meta(tk.inkSoft))
                else
                  for (final s in sorted)
                    InkWell(
                      onTap: () => showScheduleEditSheet(context, existing: s),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(minToShort(s.startMin),
                                style: AppText.meta(tk.inkSoft, size: 10)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      // v17: 완료는 취소선이 아니라 흐림으로 통일.
                                      style: AppText.body(s.done
                                          ? tk.ink.withValues(alpha: 0.5)
                                          : tk.ink)),
                                  if (s.done && s.doneAt != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                          '${DateFormat('HH:mm').format(s.doneAt!)} 완료',
                                          style:
                                              AppText.meta(tk.mark, size: 10)),
                                    ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => ref
                                  .read(scheduleRepoProvider)
                                  .toggleDone(s.id, !s.done),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Text(s.done ? '✓' : '○',
                                    style: AppText.glyph(
                                        s.done ? tk.mark : tk.inkSoft,
                                        size: 13)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
          // 추가
          GestureDetector(
            onTap: () => showScheduleEditSheet(context, date: day),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('+', style: AppText.glyph(tk.mark, size: 18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrow(AppTokens tk, String g, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(g, style: AppText.glyph(tk.inkSoft, size: 20)),
        ),
      );
}
