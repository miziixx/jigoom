import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/almanac.dart';
import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import 'schedule_edit_sheet.dart';

/// 하루 플랜 — 선택한 날의 핵심 할 일 + 시간표를 한 화면에서 계획.
/// 데이터는 기존 매트릭스(할 일)·일정 repo 를 재활용한다.
class DailyPlanBody extends ConsumerStatefulWidget {
  const DailyPlanBody({super.key});

  @override
  ConsumerState<DailyPlanBody> createState() => _DailyPlanBodyState();
}

class _DailyPlanBodyState extends ConsumerState<DailyPlanBody> {
  DateTime _date = todayDate();

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final schedules =
        ref.watch(schedulesForDateProvider(_date)).valueOrNull ?? const [];
    final sorted = [...schedules]..sort((a, b) => a.startMin.compareTo(b.startMin));
    final q1 = ref
            .watch(quadrantProvider((important: true, urgent: true)))
            .valueOrNull ??
        const [];
    final q2 = ref
            .watch(quadrantProvider((important: true, urgent: false)))
            .valueOrNull ??
        const [];
    final focus = [...q1, ...q2].take(5).toList();

    return Container(
      color: tk.paper,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _dateHeader(tk),
          // 핵심 (중요/긴급 할 일)
          SectionLabel('FOCUS', count: focus.length),
          if (focus.isEmpty)
            emptyNote(context, '중요·긴급 할 일이 없어요')
          else
            for (final n in focus)
              Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
                child: Row(
                  children: [
                    Text('·', style: AppText.glyph(tk.mark, size: 15)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(tk.ink))),
                  ],
                ),
              ),
          // 시간표 (일정)
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 20, kGutter, 0),
            child: Row(
              children: [
                Expanded(child: SectionLabel('TIMELINE', count: sorted.length)),
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
          if (sorted.isEmpty)
            emptyNote(context, '이 날 계획한 일정이 없어요')
          else
            for (final s in sorted)
              InkWell(
                onTap: () => showScheduleEditSheet(context, existing: s),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 46,
                          child: Text(minToShort(s.startMin),
                              style: AppText.meta(tk.inkSoft))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.title,
                            style: AppText.body(s.done ? tk.inkSoft : tk.ink)
                                .copyWith(
                                    decoration: s.done
                                        ? TextDecoration.lineThrough
                                        : null)),
                      ),
                      GestureDetector(
                        onTap: () => ref
                            .read(scheduleRepoProvider)
                            .toggleDone(s.id, !s.done),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(s.done ? '✓' : '○',
                              style: AppText.glyph(
                                  s.done ? tk.mark : tk.inkSoft,
                                  size: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

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
                    '${moonEmoji(_date)} ${moonName(_date)}',
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

  Widget _arrow(AppTokens tk, String g, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(g, style: AppText.glyph(tk.inkSoft, size: 20)),
        ),
      );
}
