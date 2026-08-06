import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/dialogs.dart';
import '../../data/db.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import 'habit_stats.dart';

const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

/// 빠른 시작 — 흔한 습관을 한 번 탭으로 추가(레퍼런스 습관 화면의 빠른 시작).
const _quickStartPresets = <String>[
  '물 마시기',
  '산책하기',
  '스트레칭',
  '독서',
  '명상',
  '일기 쓰기',
  '영양제',
  '정리정돈',
];

// ---------------------------------------------------------------- 분석 헬퍼
// 스칼라 계산(현재/최장 연속·복귀·최근 실행일)은 habit_stats.dart 로 분리
// (Flutter 비의존 → 유닛테스트). 여기엔 UI 결합된 요일/주별 집계만 둔다.

/// 요일별(월~일) 완료 수/등장 수.
(List<int> done, List<int> total) _weekday(
    Set<DateTime> ticks, DateTime start, DateTime end) {
  final done = List.filled(7, 0);
  final total = List.filled(7, 0);
  var d = start;
  while (!d.isAfter(end)) {
    final wi = d.weekday - 1;
    total[wi]++;
    if (ticks.contains(d)) done[wi]++;
    d = d.add(const Duration(days: 1));
  }
  return (done, total);
}

/// 7일 버킷 주별 완료 수(최근 maxWeeks개).
List<({DateTime start, int done})> _weekly(
    Set<DateTime> ticks, DateTime start, DateTime end,
    {int maxWeeks = 12}) {
  final buckets = <({DateTime start, int done})>[];
  var bs = start;
  while (!bs.isAfter(end)) {
    var done = 0;
    var d = bs;
    final be = bs.add(const Duration(days: 6));
    while (!d.isAfter(be) && !d.isAfter(end)) {
      if (ticks.contains(d)) done++;
      d = d.add(const Duration(days: 1));
    }
    buckets.add((start: bs, done: done));
    bs = bs.add(const Duration(days: 7));
  }
  return buckets.length > maxWeeks
      ? buckets.sublist(buckets.length - maxWeeks)
      : buckets;
}

// ------------------------------------------------------------------- 탭 뷰
/// 습관 탭 — 상단 오늘 요약 + 카테고리→습관 모노 트리. 습관 탭 → 상세 대시보드.
class HabitView extends ConsumerWidget {
  const HabitView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final habits = ref.watch(habitsProvider).valueOrNull ?? const [];

    if (habits.isEmpty) {
      return Container(
        color: tk.paper,
        child: ListView(
          padding: const EdgeInsets.only(top: 22, bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 2),
              child: Text('오른쪽 위 +로 직접 만들거나, 아래에서 바로 시작해요',
                  style: AppText.meta(tk.inkSoft, size: 13)),
            ),
            const _QuickStartHabits(existingTitles: {}),
          ],
        ),
      );
    }

    // § 오늘의 습관 + 인덱스(01/02…) 카드행.
    final rows = <Widget>[
      _habitSectionHead(tk),
      for (var i = 0; i < habits.length; i++)
        _HabitRow(
          habit: habits[i],
          prefix: (i + 1).toString().padLeft(2, '0'),
        ),
    ];

    rows.add(const SizedBox(height: 20));
    rows.add(_QuickStartHabits(
        existingTitles: {for (final h in habits) h.title}));
    rows.add(const SizedBox(height: 16));

    return Container(
      color: tk.paper,
      child: ListView(padding: EdgeInsets.zero, children: rows),
    );
  }

  /// § 오늘의 습관 — 세리프 섹션 헤더 + 규칙선.
  Widget _habitSectionHead(AppTokens tk) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('§ ', style: AppText.hTitle(tk.mark).copyWith(fontSize: 15)),
              Text('오늘의 습관',
                  style: AppText.hTitle(tk.ink).copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: tk.line),
        ],
      ),
    );
  }
}

/// 빠른 시작 프리셋 — 박스 없는 한 줄 텍스트 액션(하단 hairline). 탭하면 바로 추가.
class _QuickStartHabits extends ConsumerWidget {
  const _QuickStartHabits({required this.existingTitles});
  final Set<String> existingTitles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final presets =
        _quickStartPresets.where((p) => !existingTitles.contains(p)).toList();
    if (presets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // § 빠른 시작 + 템플릿 (레퍼런스 section-title).
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('§ ',
                      style: AppText.hTitle(tk.mark).copyWith(fontSize: 15)),
                  Text('빠른 시작',
                      style: AppText.hTitle(tk.ink).copyWith(fontSize: 16)),
                  const Spacer(),
                  Text('템플릿', style: AppText.meta(tk.inkSoft, size: 11)),
                ],
              ),
              const SizedBox(height: 8),
              Container(height: 1, color: tk.line),
            ],
          ),
        ),
        // 가로 이모지 칩 (레퍼런스 .filter-row).
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: kGutter),
          child: Row(
            children: [
              for (var i = 0; i < presets.length; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                PillChip(
                  label: '${_presetEmoji(presets[i])} ${presets[i]}',
                  onTap: () async {
                    await ref.read(habitRepoProvider).addHabit(presets[i]);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(SnackBar(
                          content: Text("'${presets[i]}' 습관을 추가했어요"),
                          duration: const Duration(milliseconds: 1200),
                        ));
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 빠른 시작 프리셋 이모지 (레퍼런스 칩의 앞 이모지에 대응).
  String _presetEmoji(String p) => switch (p) {
        '물 마시기' => '💧',
        '산책하기' => '🚶',
        '스트레칭' => '🤸',
        '독서' => '📖',
        '명상' => '🧘',
        '일기 쓰기' => '📔',
        '영양제' => '💊',
        '정리정돈' => '🧹',
        _ => '·',
      };
}

class _HabitRow extends ConsumerWidget {
  const _HabitRow({required this.habit, required this.prefix});

  final Habit habit;
  final String prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final ticks =
        ref.watch(habitTicksProvider(habit.id)).valueOrNull ?? const [];
    final tickSet = {for (final t in ticks) dateOnly(t.date)};
    final today = todayDate();
    final todayDone = tickSet.contains(today);
    DateTime? completedAt;
    for (final tick in ticks) {
      if (dateOnly(tick.date) == today) {
        completedAt = tick.completedAt;
        break;
      }
    }
    final streak = currentStreak(tickSet, today);
    final total = today.difference(dateOnly(habit.createdAt)).inDays + 1;
    final percent = total == 0 ? 0 : (tickSet.length * 100 / total).round();
    final returns = returnCount(tickSet, dateOnly(habit.createdAt), today);

    // 레퍼런스 메타: "매일 · N일 연속" (+ 복귀·완료시각). 시간대 데이터는 없어 생략.
    final metaBits = <String>['매일', '$streak일 연속'];
    if (percent > 0) metaBits.add('$percent%');
    if (returns > 0) metaBits.add('복귀 $returns회');
    if (completedAt != null) {
      metaBits.add('${DateFormat('HH:mm').format(completedAt)} 완료');
    }

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HabitDetailScreen(habit: habit),
      )),
      child: Container(
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
        padding: const EdgeInsets.fromLTRB(kGutter, 11, kGutter, 11),
        child: Row(
          children: [
            // 번호 박스 (레퍼런스 .habit-icon: 29px, 테두리, 투명 배경).
            Container(
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: tk.line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(prefix, style: AppText.meta(tk.inkSoft, size: 10)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(todayDone ? tk.inkSoft : tk.ink)),
                  const SizedBox(height: 3),
                  Text(metaBits.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta(tk.inkSoft, size: 9)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 우측 체크박스 (레퍼런스 .check) — 탭하면 오늘 완료 토글.
            GestureDetector(
              onTap: () =>
                  ref.read(habitRepoProvider).toggleTick(habit.id, today),
              behavior: HitTestBehavior.opaque,
              child: Text(todayDone ? '■' : '□',
                  style: AppText.glyph(tk.ink, size: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- 상세 대시보드
/// 습관 상세 — 기간별 통계 + 요일/주별 그래프 + 분석.
class HabitDetailScreen extends ConsumerStatefulWidget {
  const HabitDetailScreen({super.key, required this.habit});
  final Habit habit;

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  late DateTime _start;
  late DateTime _end;
  String _label = '전체';

  @override
  void initState() {
    super.initState();
    _end = todayDate();
    _start = dateOnly(widget.habit.createdAt);
  }

  void _setQuick(String label, int? days) {
    setState(() {
      _label = label;
      _end = todayDate();
      _start = days == null
          ? dateOnly(widget.habit.createdAt)
          : _end.subtract(Duration(days: days - 1));
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: dateOnly(widget.habit.createdAt),
      lastDate: todayDate(),
      initialDateRange: DateTimeRange(start: _start, end: _end),
      helpText: '기간을 선택하세요',
      cancelText: '취소',
      confirmText: '보기',
    );
    if (picked == null) return;
    final fmt = DateFormat('M/d');
    setState(() {
      _start = dateOnly(picked.start);
      _end = dateOnly(picked.end);
      _label = '${fmt.format(_start)}~${fmt.format(_end)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final today = todayDate();
    final ticks =
        ref.watch(habitTicksProvider(widget.habit.id)).valueOrNull ?? const [];
    final tickSet = {for (final t in ticks) dateOnly(t.date)};
    final start = dateOnly(widget.habit.createdAt);

    final rangeDays = _end.difference(_start).inDays + 1;
    var doneInRange = 0;
    for (var i = 0; i < rangeDays; i++) {
      if (tickSet.contains(_start.add(Duration(days: i)))) doneInRange++;
    }
    final percent =
        rangeDays == 0 ? 0 : (doneInRange * 100 / rangeDays).round();
    final gridDays = rangeDays.clamp(1, 372);

    final curStreak = currentStreak(tickSet, today);
    final longStreak = longestStreak(tickSet, start, today);
    final returns = returnCount(tickSet, start, today);
    final recent7 = recentActiveDays(tickSet, today);
    final (wDone, wTotal) = _weekday(tickSet, _start, _end);
    final weekly = _weekly(tickSet, _start, _end);

    // 가장 잘 지킨 요일 (등장 있는 요일 중 최고율).
    var bestWi = -1;
    var bestRate = -1.0;
    for (var i = 0; i < 7; i++) {
      if (wTotal[i] == 0) continue;
      final r = wDone[i] / wTotal[i];
      if (r > bestRate) {
        bestRate = r;
        bestWi = i;
      }
    }
    // 이번 주 / 지난 주 (오늘 기준 최근 7·그 이전 7).
    int lastNDone(int from, int to) {
      var c = 0;
      for (var i = from; i < to; i++) {
        if (tickSet.contains(today.subtract(Duration(days: i)))) c++;
      }
      return c;
    }

    final thisWeek = lastNDone(0, 7);
    final lastWeek = lastNDone(7, 14);

    // 습관 여정 마일스톤(틱에서 파생) + 다음 목표.
    final milestones = habitMilestones(tickSet, start, today);
    final next = milestones
        .where((m) => m.kind == HabitMilestoneKind.upcoming)
        .cast<HabitMilestone?>()
        .firstWhere((_) => true, orElse: () => null);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.habit.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: '카테고리',
            onPressed: _changeCategory,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '삭제',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: Container(
        color: tk.paper,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // RANGE
            const SectionLabel('RANGE'),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _rangeChip('7일', () => _setQuick('7일', 7), _label == '7일'),
                  _rangeChip(
                      '30일', () => _setQuick('30일', 30), _label == '30일'),
                  _rangeChip('전체', () => _setQuick('전체', null), _label == '전체'),
                  _rangeChip(_label.contains('~') ? _label : '기간 선택',
                      _pickRange, _label.contains('~')),
                ],
              ),
            ),

            // STATS
            const SectionLabel('STATS'),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stat(tk, '$doneInRange', '일 완료'),
                  _stat(tk, '$rangeDays', '일 중'),
                  _stat(tk, '$percent%', '만큼 해냈어요'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _miniStat(tk, '$curStreak', '현재 연속'),
                      const SizedBox(width: 24),
                      _miniStat(tk, '$longStreak', '최장 연속'),
                      const SizedBox(width: 24),
                      // 스트릭과 병행하는 지표 — 끊겨도 다시 온 횟수.
                      _miniStat(tk, '$returns', '복귀'),
                    ],
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 8),
                    Text('다음 마일스톤 · ${next.streak}일 연속',
                        style: AppText.meta(tk.inkSoft, size: 10)),
                  ],
                ],
              ),
            ),

            // JOURNEY — 여정 마일스톤 타임라인
            const SectionLabel('JOURNEY'),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
              child: _journey(tk, milestones),
            ),

            // CALENDAR — 최근 35일 히트맵(탭하면 그날 완료 토글, 과거 수정)
            const SectionLabel('CALENDAR'),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
              child: _calendarGrid(tk, tickSet, today),
            ),

            // WEEKDAY 그래프
            const SectionLabel('WEEKDAY'),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _bar(tk, wTotal[i] == 0 ? 0 : wDone[i] / wTotal[i],
                              highlight: i == bestWi),
                          const SizedBox(height: 4),
                          Text(_weekdayNames[i],
                              style: AppText.meta(
                                  i == bestWi ? tk.ink : tk.inkSoft,
                                  size: 10)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // TREND 그래프 (주별)
            const SectionLabel('TREND'),
            SizedBox(
              height: 84,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: kGutter),
                children: [
                  for (var wi = 0; wi < weekly.length; wi++)
                    SizedBox(
                      width: 22,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _bar(tk, weekly[wi].done / 7),
                          const SizedBox(height: 4),
                          Text(DateFormat('M/d').format(weekly[wi].start),
                              style: AppText.meta(tk.inkSoft, size: 8)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // LOG 격자
            const SectionLabel('LOG'),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < gridDays; i++)
                    _dot(tk,
                        day: _start.add(Duration(days: i)),
                        filled:
                            tickSet.contains(_start.add(Duration(days: i)))),
                ],
              ),
            ),

            // NOTES 분석
            const SectionLabel('NOTES'),
            emptyNote(context, '현재 $curStreak일 연속, 최장 $longStreak일'),
            if (returns > 0)
              emptyNote(context, '끊겨도 $returns번 다시 왔어요 · 최근 7일 중 $recent7일 실행')
            else
              emptyNote(context, '최근 7일 중 $recent7일 실행'),
            if (bestWi >= 0)
              emptyNote(context, '가장 잘 지킨 요일: ${_weekdayNames[bestWi]}'),
            emptyNote(context, '이번 주 $thisWeek/7 (지난주 $lastWeek/7)'),
          ],
        ),
      ),
    );
  }

  Widget _rangeChip(String label, VoidCallback onTap, bool selected) {
    final tk = t(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? tk.ink : Colors.transparent,
          border: Border.all(color: selected ? tk.ink : tk.line, width: 1),
        ),
        child:
            Text(label, style: AppText.chip(selected ? tk.paper : tk.inkSoft)),
      ),
    );
  }

  Widget _stat(AppTokens tk, String strong, String rest) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(strong, style: AppText.hTitle(tk.ink)),
          const SizedBox(width: 6),
          Text(rest, style: AppText.meta(tk.inkSoft)),
        ],
      ),
    );
  }

  Widget _miniStat(AppTokens tk, String strong, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(strong, style: AppText.body(tk.ink)),
        const SizedBox(width: 4),
        Text(label, style: AppText.meta(tk.inkSoft, size: 10)),
      ],
    );
  }

  // ── 여정 타임라인 ──────────────────────────────────────
  Widget _journey(AppTokens tk, List<HabitMilestone> ms) {
    final df = DateFormat('yyyy.M.d');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < ms.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 16,
                  child: Column(
                    children: [
                      const SizedBox(height: 3),
                      _node(tk, ms[i].kind),
                      if (i != ms.length - 1)
                        Expanded(child: Container(width: 1, color: tk.line)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ms[i].date != null ? df.format(ms[i].date!) : '예정',
                            style: AppText.meta(tk.inkSoft, size: 9)),
                        const SizedBox(height: 1),
                        Text(ms[i].label,
                            style: AppText.body(
                                    ms[i].kind == HabitMilestoneKind.upcoming
                                        ? tk.inkSoft
                                        : tk.ink)
                                .copyWith(
                                    fontSize: 12,
                                    fontWeight:
                                        ms[i].kind == HabitMilestoneKind.current
                                            ? FontWeight.w600
                                            : FontWeight.w400)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 여정 노드 — 완료=채운 원, 현재=포인트+링, 예정=빈 원. 색 외에 채움/크기로도 구분.
  Widget _node(AppTokens tk, HabitMilestoneKind kind) {
    switch (kind) {
      case HabitMilestoneKind.current:
        return Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tk.mark,
            border: Border.all(color: tk.mark.withValues(alpha: 0.28), width: 3),
          ),
        );
      case HabitMilestoneKind.upcoming:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: tk.line, width: 1.4),
          ),
        );
      case HabitMilestoneKind.start:
      case HabitMilestoneKind.reached:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: tk.ink),
        );
    }
  }

  // ── 최근 35일 캘린더 히트맵(과거 수정 가능) ──────────────
  Widget _calendarGrid(AppTokens tk, Set<DateTime> tickSet, DateTime today) {
    // 일요일 시작 열. 이번 주 토요일까지 5주(35칸).
    final daysToSat = (6 - today.weekday + 7) % 7; // Dart weekday 월1..일7
    final endOfWeek = today.add(Duration(days: daysToSat));
    final days = <DateTime>[
      for (var i = 34; i >= 0; i--) dateOnly(endOfWeek.subtract(Duration(days: i))),
    ];
    const wk = ['일', '월', '화', '수', '목', '금', '토'];
    return Column(
      children: [
        Row(
          children: [
            for (final w in wk)
              Expanded(
                  child: Center(
                      child: Text(w, style: AppText.meta(tk.inkSoft, size: 8)))),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < 5; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(child: _dayCell(tk, days[r * 7 + c], tickSet, today)),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(
      AppTokens tk, DateTime d, Set<DateTime> tickSet, DateTime today) {
    final done = tickSet.contains(d);
    final isToday = d == today;
    final isFuture = d.isAfter(today);
    return GestureDetector(
      onTap: isFuture
          ? null
          : () => ref.read(habitRepoProvider).toggleTick(widget.habit.id, d),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: done ? tk.mark : Colors.transparent,
              border: Border.all(
                  color: isToday ? tk.ink : (done ? tk.mark : tk.line),
                  width: isToday ? 1.4 : 1),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text('${d.day}',
                style: AppText.meta(
                    isFuture
                        ? tk.inkSoft.withValues(alpha: 0.4)
                        : (done ? tk.paper : tk.inkSoft),
                    size: 8)),
          ),
        ),
      ),
    );
  }

  /// 편집 톤 막대 — 고정 64 트랙 안에서 잉크 fill(높이 ∝ rate). 0은 얇은 line.
  Widget _bar(AppTokens tk, double rate, {bool highlight = false}) {
    final double h = rate <= 0
        ? 0.03
        : rate < 0.06
            ? 0.06
            : rate > 1.0
                ? 1.0
                : rate;
    return SizedBox(
      height: 64,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: h,
          widthFactor: 0.5,
          child: Container(
              color: rate <= 0 ? tk.line : (highlight ? tk.mark : tk.ink)),
        ),
      ),
    );
  }

  Widget _dot(AppTokens tk, {required DateTime day, required bool filled}) {
    final future = day.isAfter(todayDate());
    return GestureDetector(
      onTap: future
          ? null
          : () => ref.read(habitRepoProvider).toggleTick(widget.habit.id, day),
      child: Text(filled ? '●' : '○',
          style: AppText.glyph(
              filled ? tk.ink : tk.line.withValues(alpha: future ? 0.4 : 1),
              size: 14)),
    );
  }

  Future<void> _changeCategory() async {
    final v = await showInputDialog(context,
        kicker: 'EDIT',
        title: '카테고리',
        hint: '예: 건강, 공부 (비우면 기본)',
        initial: widget.habit.category);
    if (v == null) return;
    await ref.read(habitRepoProvider).setCategory(widget.habit.id, v.trim());
  }

  Future<void> _confirmDelete() async {
    final ok = await showConfirmDialog(context,
        title: '"${widget.habit.title}" 삭제할까요?',
        message: '기록도 함께 지워져요.',
        confirmLabel: '삭제',
        danger: true);
    if (ok) {
      await ref.read(habitRepoProvider).deleteHabit(widget.habit.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}
