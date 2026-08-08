import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/almanac.dart';
import '../../core/constants.dart';
import '../../core/dialogs.dart';
import '../../core/editorial.dart';
import '../../core/journal.dart';
import '../../core/reference_tokens.dart';
import '../../data/db.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../data/repos/time_track_repository.dart';
import '../../providers.dart';
import '../shell/app_bottom_nav.dart';
import '../timetrack/time_track_screen.dart';
import 'schedule_edit_sheet.dart';

/// 달력 화면 — 드로어에서 바로 여는 독립 진입(Scaffold 래퍼).
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  // 달력의 담기 = 선택일 상세 탭에 맞는 추가(일정 / 기록 / 습관).
  void _add(BuildContext context, WidgetRef ref) {
    final d = ref.read(calendarSelectedProvider) ?? todayDate();
    switch (ref.read(calendarDetailTabProvider)) {
      case 1: // 기록 → 그날의 시간 기록(계속 담기)
        showTimeQuickAdd(context, ref,
            date: d, block: TimeTrackRepository.blockOfNow());
        break;
      case 2: // 습관 → 새 습관 추가
        _addHabit(context, ref);
        break;
      default: // 일정
        showScheduleEditSheet(context, date: d);
    }
  }

  Future<void> _addHabit(BuildContext context, WidgetRef ref) async {
    final name = await showInputDialog(context,
        title: '새 습관',
        subtitle: '매일 반복하고 싶은 작은 행동을 적어주세요.',
        fieldLabel: '습관 이름',
        hint: '예: 물 한 잔 마시기',
        saveLabel: '만들기');
    if (name == null || name.trim().isEmpty) return;
    await ref.read(habitRepoProvider).addHabit(name.trim());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Masthead(
                  eyebrow: 'CALENDAR',
                  title: '달력',
                  onBack: () => Navigator.of(context).pop(),),
              const Expanded(child: CalendarView()),
              AppBottomNav(onQuickAdd: () => _add(context, ref)),
            ],
          ),
        ),
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

  // 선택 날짜·상세 탭은 provider 로 관리(하단 담기가 세부 탭·선택일을 알 수 있게).
  DateTime get _selected =>
      ref.watch(calendarSelectedProvider) ?? todayDate();

  int _dayFilter = 0; // 0 전체·1 루틴·2 할일·3 일정·4 습관·5 메모·6 기록

  @override
  void initState() {
    super.initState();
    final now = todayDate();
    _month = DateTime(now.year, now.month, 1);
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
          for (var w = 0; w < 6; w++) _weekRow(tk, gridStart, w, today, counts),
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
              onTap: () {
                ref.read(calendarSelectedProvider.notifier).state = today;
                setState(() => _month = DateTime(today.year, today.month, 1));
              },
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
            Expanded(
                child: _cell(tk, gridStart.add(Duration(days: week * 7 + i)),
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
      onTap: () => ref.read(calendarSelectedProvider.notifier).state = day,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          // 레퍼런스 v17: 오늘=잉크 아웃라인, 선택=얇은 규칙선 아웃라인. 채움 없음.
          border: Border.all(
            color: isToday
                ? tk.ink
                : (isSel ? tk.inkSoft : Colors.transparent),
            width: isToday ? 1.4 : 1.0,
          ),
        ),
        padding: const EdgeInsets.only(top: 5),
        // 레퍼런스 셀: 양력 숫자 → 干支日(항상) → 달 모양(+일정 점).
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('${day.day}',
                style: AppText.body(numColor).copyWith(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w500 : FontWeight.w400)),
            const SizedBox(height: 2),
            // 干支日 — 항상 표시. 절기 날은 포인트색으로 강조.
            Text(iljinLabel(day),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style:
                    AppText.metaSans(term != null ? tk.mark : subColor, size: 7.5)),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EdMoonPhase(
                    phase: moonPhaseFraction(day),
                    size: 7,
                    color: subColor,
                    bg: tk.paper),
                if (hasSched) ...[
                  const SizedBox(width: 3),
                  Container(
                    width: 3.5,
                    height: 3.5,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: numColor),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedDetail(AppTokens tk) {
    final d = _selected;
    final items =
        ref.watch(schedulesForDateProvider(d)).valueOrNull ?? const [];
    final records =
        ref.watch(timeBlocksForDateProvider(d)).valueOrNull ?? const [];
    final ticks =
        ref.watch(habitTicksOnDateProvider(d)).valueOrNull ?? const [];
    final habits = ref.watch(habitsProvider).valueOrNull ?? const [];
    final habitName = {for (final h in habits) h.id: h.title};
    final doneHabits = ticks
        .map((t) => (name: habitName[t.habitId] ?? '', time: t.completedAt))
        .where((h) => h.name.isNotEmpty)
        .toList();
    final term = solarTermName(d);
    final settings = ref.watch(settingsProvider);

    // 음력은 항상, 일진(사주)·별자리(점성학)는 설정 토글에 따라.
    final almanacParts = <String>[
      lunarLabel(d),
      if (settings.showSaju) iljinLabel(d),
      if (settings.showZodiac) byeoljariLabel(d),
    ];

    // ── 통합 날짜 스트림(기준 HTML) — 루틴·할일·일정·습관·메모·기록 ──
    final open = ref.watch(openNodesForDateProvider(d)).valueOrNull ?? const [];
    final wins = ref.watch(winsForDateProvider(d)).valueOrNull ?? const [];
    final groups = ref.watch(routineGroupsProvider).valueOrNull ?? const [];
    final steps = ref.watch(routineStepsProvider).valueOrNull ?? const [];
    final rGroupName = {for (final g in groups) g.id: g.title};
    final rWd = d.weekday;
    final rDayIds = {
      for (final g in groups)
        if (g.active && g.weekdays.split(',').contains('$rWd')) g.id
    };
    bool rDone(RoutineStep s) =>
        s.lastDone != null && dateOnly(s.lastDone!) == d;
    final stream = <({String kind, String title, int? min, String meta})>[];
    for (final s in steps) {
      if (!rDayIds.contains(s.groupId)) continue;
      final dn = rDone(s);
      stream.add((
        kind: 'routine',
        title: rGroupName[s.groupId] == null
            ? s.title
            : '${rGroupName[s.groupId]} · ${s.title}',
        min: dn && s.lastDoneAt != null
            ? s.lastDoneAt!.hour * 60 + s.lastDoneAt!.minute
            : null,
        meta: dn ? '루틴 · 완료' : '루틴',
      ));
    }
    for (final s in items) {
      stream.add((
        kind: 'schedule',
        title: s.title,
        min: s.allDay ? null : s.startMin,
        meta: s.allDay ? '일정 · 종일' : '일정',
      ));
    }
    for (final n in open) {
      if (n.type == NodeType.task) {
        stream.add((kind: 'task', title: n.title, min: null, meta: '할 일'));
      } else if (n.type == NodeType.memo) {
        stream.add((kind: 'memo', title: n.title, min: null, meta: '메모'));
      }
    }
    for (final n in wins) {
      final m = n.doneAt == null ? null : n.doneAt!.hour * 60 + n.doneAt!.minute;
      stream.add((kind: 'task', title: n.title, min: m, meta: '완료'));
    }
    for (final h in doneHabits) {
      final m = h.time == null ? null : h.time!.hour * 60 + h.time!.minute;
      stream.add((kind: 'habit', title: h.name, min: m, meta: '습관 · 완료'));
    }
    for (final b in records) {
      if (b.content.trim().isEmpty) continue;
      stream.add((
        kind: 'record',
        title: b.content.split('\n').first.trim(),
        min: b.block * 30,
        meta: '기록',
      ));
    }
    const kindKeys = ['all', 'routine', 'task', 'schedule', 'habit', 'memo', 'record'];
    final fk = kindKeys[_dayFilter];
    final shown =
        fk == 'all' ? stream : stream.where((x) => x.kind == fk).toList();
    shown.sort((a, b) => (a.min ?? (1 << 30)).compareTo(b.min ?? (1 << 30)));
    final overAll = stream.length;
    final overDone =
        wins.length + items.where((s) => s.done).length + doneHabits.length;
    final overRec = records.where((b) => b.content.trim().isNotEmpty).length;
    final focusMin = overRec * 30;

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
              EdMoonPhase(
                  phase: moonPhaseFraction(d),
                  size: 12,
                  color: tk.inkSoft,
                  bg: tk.paper),
              const SizedBox(width: 6),
              Text(moonName(d), style: AppText.metaSans(tk.inkSoft)),
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
        // date-overview (기준 HTML)
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 12),
          child: Row(children: [
            _ovCell(tk, '$overAll', '전체'),
            _ovCell(tk, '$overDone', '완료'),
            _ovCell(tk, '$overRec', '기록'),
            _ovCell(tk, '${focusMin}분', '집중'),
          ]),
        ),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: kGutter),
            children: [
              _dayFilterChip(tk, 0, '전체'),
              _dayFilterChip(tk, 1, '루틴'),
              _dayFilterChip(tk, 2, '할 일'),
              _dayFilterChip(tk, 3, '일정'),
              _dayFilterChip(tk, 4, '습관'),
              _dayFilterChip(tk, 5, '메모'),
              _dayFilterChip(tk, 6, '기록'),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (shown.isEmpty)
          emptyNote(context, '이 날 이 종류의 기록이 없어요')
        else
          for (final x in shown) _streamRow(tk, x),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _ovCell(AppTokens tk, String value, String label) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: tk.paper2, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(value, style: AppText.metaSans(tk.ink, size: 12)),
            const SizedBox(height: 4),
            Text(label, style: AppText.meta(tk.inkSoft, size: 8)),
          ]),
        ),
      );

  Widget _dayFilterChip(AppTokens tk, int i, String label) {
    final sel = _dayFilter == i;
    return GestureDetector(
      onTap: () => setState(() => _dayFilter = i),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
            color: sel ? mixOver(tk.mark, 0.16, tk.paper) : tk.paper2,
            borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: AppText.meta(sel ? tk.ink : tk.inkSoft, size: 9)),
      ),
    );
  }

  Widget _streamRow(
      AppTokens tk, ({String kind, String title, int? min, String meta}) x) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter, vertical: 11),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 40,
            child: Text(x.min != null ? minToShort(x.min!) : '',
                style: AppText.meta(tk.inkSoft, size: 8))),
        const SizedBox(width: 8),
        Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: streamKindColor(x.kind))),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(x.meta, style: AppText.meta(tk.inkSoft, size: 7)),
            const SizedBox(height: 3),
            Text(x.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(tk.ink).copyWith(fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}
