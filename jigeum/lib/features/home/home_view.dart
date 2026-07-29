import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../today/goal_editor.dart';

/// 대시보드 홈 — v17 레퍼런스(에디토리얼): hero → "오늘 한눈에" 2×2 요약
/// → "오늘의 목표" 진행바 → 오늘 할 일 미리보기. 세리프 제목 + 세이지 포인트.
class HomeView extends ConsumerStatefulWidget {
  /// AppShell 탭 이동 (0=오늘, 2=쏟아내기, 3=일과/시간, 4=습관 …).
  final void Function(int index) onOpenTab;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenFortune;

  const HomeView({
    super.key,
    required this.onOpenTab,
    required this.onOpenCalendar,
    required this.onOpenFortune,
  });

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  String _goal = '';

  @override
  void initState() {
    super.initState();
    ref.read(scheduleRepoProvider).getDayGoal(todayDate()).then((v) {
      if (mounted) setState(() => _goal = v ?? '');
    });
  }

  static String _hhmm(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final today = todayDate();
    final now = DateTime.now();

    final open = (ref.watch(todayNodesProvider).valueOrNull ?? const <Node>[])
        .where((n) => n.type != 'memo')
        .toList();
    final wins = ref.watch(todayWinsProvider).valueOrNull ?? const <Node>[];
    final doneCount = wins.length;
    final totalTasks = open.length + doneCount;

    final schedules = [
      ...(ref.watch(schedulesForDateProvider(today)).valueOrNull ??
          const <Schedule>[])
    ]..sort((a, b) => a.startMin.compareTo(b.startMin));
    final nowMin = now.hour * 60 + now.minute;
    Schedule? next;
    for (final s in schedules) {
      if (!s.done && !s.allDay && s.startMin >= nowMin) {
        next = s;
        break;
      }
    }
    next ??= schedules.isNotEmpty ? schedules.first : null;

    final habits = ref.watch(habitsProvider).valueOrNull ?? const <Habit>[];
    final ticks = ref.watch(habitTicksOnDateProvider(today)).valueOrNull ??
        const <HabitTick>[];
    final habitDone = ticks.map((e) => e.habitId).toSet().length;

    final blocks = ref.watch(timeBlocksForDateProvider(today)).valueOrNull ??
        const <TimeBlock>[];
    final filled = blocks.where((b) => b.content.trim().isNotEmpty).length;
    final hours = filled * 0.5;
    final hoursStr =
        '${hours.toStringAsFixed(hours.truncateToDouble() == hours ? 0 : 1)}h';

    final goalLine = _goal
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    final pct = totalTasks == 0 ? 0 : (doneCount / totalTasks * 100).round();

    return Container(
      color: tk.paper,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _hero(tk, now),
          _rule(tk, top: 16, bottom: 4),
          _sectionTitle(tk, '오늘 한눈에', '오늘 보기', () => widget.onOpenTab(0)),
          _summaryGrid(tk, open, doneCount, totalTasks, hoursStr, filled,
              habitDone, habits.length, next),
          _sectionTitle(tk, '오늘의 목표', '수정', _editGoal),
          _goalCard(tk, goalLine, doneCount, totalTasks, pct),
          _sectionTitle(tk, '오늘 할 일', '전체 보기', () => widget.onOpenTab(0)),
          _todoPreview(tk, open),
          _sectionTitle(tk, '다음 일정', '달력', widget.onOpenCalendar),
          _scheduleBlock(tk, schedules),
          _sectionTitle(tk, '오늘의 습관', '전체', () => widget.onOpenTab(4)),
          _habitListBlock(tk, habits, ticks),
          _sectionTitle(tk, '오늘의 운세', '자세히', widget.onOpenFortune),
          _fortuneBlock(tk),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── 다음 일정 ──────────────────────────────────────────
  Widget _scheduleBlock(AppTokens tk, List<Schedule> schedules) {
    final upcoming = schedules.where((s) => !s.done).toList();
    if (upcoming.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 0),
        child: Text('오늘 일정이 없어요', style: AppText.body(tk.inkSoft)),
      );
    }
    return Column(
      children: [
        for (final s in upcoming.take(3))
          GestureDetector(
            onTap: widget.onOpenCalendar,
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration:
                  BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
              padding:
                  const EdgeInsets.symmetric(horizontal: kGutter, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(s.allDay ? '종일' : _hhmm(s.startMin),
                        style: AppText.meta(tk.inkSoft)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(tk.ink)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── 오늘의 습관 ────────────────────────────────────────
  Widget _habitListBlock(
      AppTokens tk, List<Habit> habits, List<HabitTick> ticks) {
    if (habits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 0),
        child: Text('습관을 추가해 보세요', style: AppText.body(tk.inkSoft)),
      );
    }
    final done = {for (final t in ticks) t.habitId};
    return Column(
      children: [
        for (final h in habits.take(4))
          GestureDetector(
            onTap: () => widget.onOpenTab(4),
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration:
                  BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
              padding:
                  const EdgeInsets.symmetric(horizontal: kGutter, vertical: 12),
              child: Row(
                children: [
                  Text(done.contains(h.id) ? '✓' : '○',
                      style: AppText.glyph(
                          done.contains(h.id) ? tk.mark : tk.inkSoft,
                          size: 14)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(h.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(
                            done.contains(h.id)
                                ? tk.ink.withValues(alpha: 0.5)
                                : tk.ink)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── 오늘의 운세 ────────────────────────────────────────
  Widget _fortuneBlock(AppTokens tk) {
    final hasBirth = ref.watch(settingsProvider).birth != null;
    return GestureDetector(
      onTap: widget.onOpenFortune,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 0),
        child: Text(
          hasBirth ? '오늘의 흐름 · 사주·점성 분석 보기 ›' : '생년월일을 입력하면 오늘의 운세가 보여요',
          style: AppText.body(hasBirth ? tk.ink : tk.inkSoft),
        ),
      ),
    );
  }

  Future<void> _editGoal() async {
    final g = await showGoalEditor(context, ref);
    if (g == null) return;
    if (mounted) setState(() => _goal = g);
  }

  // ── HERO ────────────────────────────────────────────────
  Widget _hero(AppTokens tk, DateTime now) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 18, kGutter, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 좌측 날짜 (모노, 세로 여백)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(DateFormat('MM / dd').format(now),
                style: AppText.meta(tk.inkSoft, size: 11)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('● 지금 여기서 시작해요',
                    style: AppText.meta(tk.mark, size: 11)),
                const SizedBox(height: 10),
                Text('오늘은 한 번에\n하나만 해도 충분해요.',
                    style: AppText.hTitle(tk.ink)
                        .copyWith(fontSize: 25, height: 1.28)),
                const SizedBox(height: 8),
                Text('해야 할 건 앱에 맡겨두고, 지금 가장 가까운 일 하나부터 시작해요.',
                    style: AppText.body(tk.inkSoft)
                        .copyWith(fontSize: 12, height: 1.55)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _fillBtn(tk, '집중 시작', () => widget.onOpenTab(0)),
                    const SizedBox(width: 10),
                    _outlineBtn(tk, '목표 수정', _editGoal),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fillBtn(AppTokens tk, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          color: tk.mark,
          child: Text(label, style: AppText.body(tk.paper).copyWith(fontSize: 12)),
        ),
      );

  Widget _outlineBtn(AppTokens tk, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(border: Border.all(color: tk.line)),
          child: Text(label, style: AppText.body(tk.ink).copyWith(fontSize: 12)),
        ),
      );

  // ── 섹션 제목 (§ 세리프 + 우측 링크 + 하단 헤어라인) ──────────
  Widget _sectionTitle(
      AppTokens tk, String title, String action, VoidCallback onAction) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 24, kGutter, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('§ ',
                  style: AppText.hTitle(tk.mark).copyWith(fontSize: 15)),
              Text(title,
                  style: AppText.hTitle(tk.ink).copyWith(fontSize: 18)),
              const Spacer(),
              GestureDetector(
                onTap: onAction,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 2),
                  child: Text(action, style: AppText.meta(tk.inkSoft, size: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: tk.line),
        ],
      ),
    );
  }

  Widget _rule(AppTokens tk, {double top = 8, double bottom = 8}) => Padding(
        padding: EdgeInsets.fromLTRB(kGutter, top, kGutter, bottom),
        child: Container(height: 1, color: tk.line),
      );

  // ── 오늘 한눈에 2×2 ──────────────────────────────────────
  Widget _summaryGrid(
    AppTokens tk,
    List<Node> open,
    int doneCount,
    int totalTasks,
    String hoursStr,
    int filledBlocks,
    int habitDone,
    int habitTotal,
    Schedule? next,
  ) {
    final tintA = tk.paper2; // 대각 체커보드(짙은 톤)
    final tintB = tk.paper2.withValues(alpha: 0.4); // 옅은 톤
    final cells = <Widget>[
      _summaryCell(tk, '01', '오늘 할 일', '$doneCount / $totalTasks',
          '${open.length}개 남음', () => widget.onOpenTab(0),
          tint: tintA),
      _summaryCell(tk, '02', '기록 시간', hoursStr,
          filledBlocks == 0 ? '아직 없음' : '$filledBlocks칸 기록',
          () => widget.onOpenTab(3),
          tint: tintB),
      _summaryCell(tk, '03', '습관', '$habitDone / $habitTotal',
          habitTotal == 0 ? '추가해 보세요' : '오늘 완료', () => widget.onOpenTab(4),
          tint: tintB),
      _summaryCell(
          tk,
          '04',
          '다음 일정',
          next == null ? '없음' : next.title,
          next == null
              ? '오늘 일정 없음'
              : (next.allDay ? '종일' : _hhmm(next.startMin)),
          widget.onOpenCalendar,
          big: next != null,
          tint: tintA),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: cells[0]),
            const SizedBox(width: 10),
            Expanded(child: cells[1]),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: cells[2]),
            const SizedBox(width: 10),
            Expanded(child: cells[3]),
          ]),
        ],
      ),
    );
  }

  Widget _summaryCell(AppTokens tk, String idx, String label, String value,
      String sub, VoidCallback onTap,
      {bool big = true, required Color tint}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta(tk.inkSoft, size: 11))),
                Text(idx, style: AppText.meta(tk.inkSoft, size: 10)),
              ],
            ),
            const Spacer(),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.hTitle(tk.ink)
                    .copyWith(fontSize: big ? 22 : 18)),
            const SizedBox(height: 4),
            Text(sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.meta(tk.inkSoft, size: 10)),
          ],
        ),
      ),
    );
  }

  // ── 오늘의 목표 ──────────────────────────────────────────
  Widget _goalCard(
      AppTokens tk, String goalLine, int done, int total, int pct) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 0),
      child: GestureDetector(
        onTap: _editGoal,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 40, height: 3, color: tk.mark),
            const SizedBox(height: 12),
            Text('MAIN GOAL', style: AppText.meta(tk.mark, size: 10)),
            const SizedBox(height: 8),
            Text(goalLine.isEmpty ? '탭해서 오늘의 목표를 적어요' : goalLine,
                style: AppText.hTitle(
                        goalLine.isEmpty ? tk.inkSoft : tk.ink)
                    .copyWith(fontSize: 19, height: 1.3)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Container(height: 6, color: tk.paper2),
                      FractionallySizedBox(
                        widthFactor: (pct / 100).clamp(0.0, 1.0),
                        child: Container(height: 6, color: tk.mark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text('$pct%', style: AppText.meta(tk.inkSoft, size: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 오늘 할 일 미리보기 ──────────────────────────────────
  Widget _todoPreview(AppTokens tk, List<Node> open) {
    if (open.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 0),
        child: Text('오늘 할 일이 없어요', style: AppText.body(tk.inkSoft)),
      );
    }
    final shown = open.take(4).toList();
    return Column(
      children: [
        for (var i = 0; i < shown.length; i++)
          GestureDetector(
            onTap: () => widget.onOpenTab(0),
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tk.line)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: kGutter, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                        border: Border.all(color: tk.inkSoft, width: 1.4)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(shown[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(tk.ink)),
                  ),
                  if (shown[i].urgent)
                    Text('긴급', style: AppText.meta(tk.mark, size: 10))
                  else if (shown[i].important)
                    Text('중요', style: AppText.meta(tk.inkSoft, size: 10)),
                ],
              ),
            ),
          ),
        if (open.length > shown.length)
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('+${open.length - shown.length}개 더',
                  style: AppText.meta(tk.inkSoft)),
            ),
          ),
      ],
    );
  }
}
