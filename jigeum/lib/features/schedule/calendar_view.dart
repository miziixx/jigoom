import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/almanac.dart';
import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import 'schedule_edit_sheet.dart';

/// 달력 화면 — 드로어에서 바로 여는 독립 진입(Scaffold 래퍼).
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('달력')),
        body: const SafeArea(child: CalendarView()),
      );
}

/// 달력 뷰 — 월 그리드에 음력·24절기·일정 점, 아래에 선택일 상세(음력·일진·별자리·절기·일정).
class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late DateTime _month; // 보이는 달의 1일
  late DateTime _selected; // 선택된 날짜

  @override
  void initState() {
    super.initState();
    final now = todayDate();
    _month = DateTime(now.year, now.month, 1);
    _selected = now;
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final today = todayDate();

    // 그리드 시작 = 이달 1일이 속한 주의 일요일.
    final firstWeekday = _month.weekday % 7; // 일=0 … 토=6
    final gridStart = _month.subtract(Duration(days: firstWeekday));
    final gridEnd = gridStart.add(const Duration(days: 41));

    final ranged = ref
            .watch(schedulesInRangeProvider((start: gridStart, end: gridEnd)))
            .valueOrNull ??
        const [];
    final counts = <DateTime, int>{};
    for (final s in ranged) {
      final d = dateOnly(s.date);
      counts[d] = (counts[d] ?? 0) + 1;
    }

    return Container(
      color: tk.paper,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _monthHeader(tk, today),
          _weekdayRow(tk),
          Container(
            margin: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
            height: 1,
            color: tk.line,
          ),
          for (var w = 0; w < 6; w++)
            _weekRow(tk, gridStart, w, today, counts),
          _selectedDetail(tk),
        ],
      ),
    );
  }

  Widget _monthHeader(AppTokens tk, DateTime today) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _shiftMonth(-1),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
              child: Text('‹', style: AppText.glyph(tk.inkSoft, size: 20)),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _month = DateTime(today.year, today.month, 1);
                _selected = today;
              }),
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Text('${_month.year}년 ${_month.month}월',
                      textAlign: TextAlign.center,
                      style: AppText.hTitle(tk.ink)),
                  const SizedBox(height: 2),
                  Text('${yearLabel(_month)} ${monthLabel(_month)}',
                      textAlign: TextAlign.center,
                      style: AppText.metaSans(tk.inkSoft, size: 10)),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _shiftMonth(1),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
              child: Text('›', style: AppText.glyph(tk.inkSoft, size: 20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekdayRow(AppTokens tk) {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Text(labels[i],
                  textAlign: TextAlign.center,
                  style: AppText.meta(i == 0 ? tk.mark : tk.inkSoft, size: 11)),
            ),
        ],
      ),
    );
  }

  Widget _weekRow(AppTokens tk, DateTime gridStart, int week, DateTime today,
      Map<DateTime, int> counts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(child: _cell(tk, gridStart.add(Duration(days: week * 7 + i)),
                today, counts)),
        ],
      ),
    );
  }

  Widget _cell(
      AppTokens tk, DateTime day, DateTime today, Map<DateTime, int> counts) {
    final inMonth = day.month == _month.month;
    final isToday = day == today;
    final isSel = day == _selected;
    final term = solarTermName(day);
    final hasSched = (counts[day] ?? 0) > 0;
    final sunday = day.weekday % 7 == 0;

    final numColor = !inMonth
        ? tk.inkSoft.withValues(alpha: 0.4)
        : (sunday ? tk.mark : tk.ink);
    final subColor = !inMonth ? tk.inkSoft.withValues(alpha: 0.4) : tk.inkSoft;

    return GestureDetector(
      onTap: () => setState(() => _selected = day),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSel ? tk.ink : Colors.transparent,
            width: 1.2,
          ),
          color: isToday ? tk.ink.withValues(alpha: 0.06) : null,
        ),
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          children: [
            Text('${day.day}',
                style: AppText.meta(numColor, size: 12).copyWith(
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400)),
            const SizedBox(height: 2),
            Text(
              term ?? lunarShort(day),
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: AppText.metaSans(term != null ? tk.mark : subColor,
                  size: 8),
            ),
            const SizedBox(height: 2),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasSched ? tk.ink : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedDetail(AppTokens tk) {
    final d = _selected;
    final items = ref.watch(schedulesForDateProvider(d)).valueOrNull ?? const [];
    final term = solarTermName(d);
    final settings = ref.watch(settingsProvider);

    // 음력은 항상, 일진(사주)·별자리(점성학)는 설정 토글에 따라.
    final almanacParts = <String>[
      lunarLabel(d),
      if (settings.calSaju) iljinLabel(d),
      if (settings.calAstro) byeoljariLabel(d),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 0),
          height: 1,
          color: tk.ink,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(DateFormat('M월 d일 (E)', 'ko').format(d),
                  style: AppText.hTitle(tk.ink)),
              const Spacer(),
              GestureDetector(
                onTap: () => showScheduleEditSheet(context, date: d),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                  child: Text('+ 일정', style: AppText.meta(tk.ink, size: 12)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
          child: Text(almanacParts.join(' · '),
              style: AppText.metaSans(tk.inkSoft)),
        ),
        // 달모양 + 손없는날
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 0),
          child: Row(
            children: [
              Text('${moonEmoji(d)} ${moonName(d)}',
                  style: AppText.metaSans(tk.inkSoft)),
              if (isSonEomneunNal(d)) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: tk.mark)),
                  child: Text('손없는날', style: AppText.chip(tk.mark)),
                ),
              ],
            ],
          ),
        ),
        if (term != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 0),
            child: Text('절기 · $term', style: AppText.meta(tk.mark)),
          ),
        SectionLabel('SCHEDULE', count: items.length),
        if (items.isEmpty)
          emptyNote(context, '이 날 일정이 없어요')
        else
          for (final s in items)
            InkWell(
              onTap: () =>
                  showScheduleEditSheet(context, existing: s),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
                child: Row(
                  children: [
                    SizedBox(
                        width: 44,
                        child: Text(minToShort(s.startMin),
                            style: AppText.meta(tk.inkSoft))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(tk.ink))),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
