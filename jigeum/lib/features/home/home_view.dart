import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/fortune.dart';
import '../../core/saju.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';

/// 대시보드 홈 — 오늘 할 일·일정·습관·시간·운세를 카드로 요약한다.
/// 카드를 길게 눌러 드래그하면 순서가 바뀌고, 순서는 Settings kv 에 저장된다.
/// 카드를 탭하면 해당 화면(탭/달력/운세)으로 이동한다.
/// 디자인: 지금 앱 토큰(paper/ink/mark). 카드형은 사용자 요청.
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
  static const _orderKey = 'dashboard_card_order_v1';
  static const _defaultOrder = ['todo', 'schedule', 'habit', 'time', 'fortune'];

  List<String> _order = List.of(_defaultOrder);

  static String _hhmm(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final db = ref.read(dbProvider);
    final row =
        await (db.select(db.settings)..where((s) => s.key.equals(_orderKey)))
            .getSingleOrNull();
    final saved = row?.value;
    if (!mounted) return;
    if (saved == null || saved.isEmpty) return;
    final ids = saved.split(',').where(_defaultOrder.contains).toList();
    for (final d in _defaultOrder) {
      if (!ids.contains(d)) ids.add(d); // 새 카드가 생기면 끝에 편입
    }
    setState(() => _order = ids);
  }

  Future<void> _saveOrder() async {
    final db = ref.read(dbProvider);
    await db.into(db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: _orderKey, value: _order.join(',')));
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = _order.removeAt(oldIndex);
      _order.insert(newIndex, moved);
    });
    _saveOrder();
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final today = todayDate();

    final todos = (ref.watch(todayNodesProvider).valueOrNull ?? const <Node>[])
        .where((n) => n.type != 'memo')
        .toList();
    final schedules = [
      ...(ref.watch(schedulesForDateProvider(today)).valueOrNull ??
          const <Schedule>[])
    ]..sort((a, b) => a.startMin.compareTo(b.startMin));
    final habits = ref.watch(habitsProvider).valueOrNull ?? const <Habit>[];
    final ticks = ref.watch(habitTicksOnDateProvider(today)).valueOrNull ??
        const <HabitTick>[];
    final blocks = ref.watch(timeBlocksForDateProvider(today)).valueOrNull ??
        const <TimeBlock>[];
    final settings = ref.watch(settingsProvider);

    final cards = <String, Widget>{
      'todo': _card(tk,
          label: '오늘 할 일',
          count: '${todos.length}',
          onTap: () => widget.onOpenTab(0),
          child: _todoBody(tk, todos)),
      'schedule': _card(tk,
          label: '오늘 일정',
          count: '${schedules.length}',
          onTap: widget.onOpenCalendar,
          child: _scheduleBody(tk, schedules)),
      'habit': _card(tk,
          label: '습관',
          count:
              '${ticks.map((e) => e.habitId).toSet().length} / ${habits.length}',
          onTap: () => widget.onOpenTab(4),
          child: _habitBody(tk, habits, ticks)),
      'time': _card(tk,
          label: '오늘 시간 기록',
          count: _timeCount(blocks),
          onTap: () => widget.onOpenTab(3),
          child: _timeBody(tk, blocks)),
      'fortune': _card(tk,
          label: '오늘의 운세',
          count: '',
          onTap: widget.onOpenFortune,
          child: _fortuneBody(tk, settings)),
    };

    return ReorderableListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      onReorder: _onReorder,
      proxyDecorator: (child, i, a) =>
          Material(color: Colors.transparent, child: child),
      children: [
        for (final id in _order)
          Padding(
            key: ValueKey(id),
            padding: const EdgeInsets.only(bottom: 13),
            child: cards[id] ?? const SizedBox.shrink(),
          ),
      ],
    );
  }

  // ── 카드 셸 ──────────────────────────────────────────────
  Widget _card(
    AppTokens tk, {
    required String label,
    required String count,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tk.paper2,
          border: Border.all(color: tk.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(13, 11, 12, 11),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tk.line)),
              ),
              child: Row(
                children: [
                  Container(width: 3, height: 13, color: tk.mark),
                  const SizedBox(width: 9),
                  Expanded(child: Text(label, style: AppText.sec(tk.ink))),
                  if (count.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(count, style: AppText.meta(tk.inkSoft)),
                    ),
                  Text('›', style: AppText.glyph(tk.inkSoft, size: 16)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(AppTokens tk, String text) =>
      Text(text, style: AppText.body(tk.inkSoft));

  // ── 할 일 ───────────────────────────────────────────────
  Widget _todoBody(AppTokens tk, List<Node> todos) {
    if (todos.isEmpty) return _empty(tk, '오늘 할 일이 없어요');
    final shown = todos.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 9),
          Row(
            children: [
              Text('□', style: AppText.glyph(tk.ink, size: 15)),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  shown[i].title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(tk.ink),
                ),
              ),
              if (shown[i].urgent)
                Text('URGENT', style: AppText.meta(tk.mark, size: 10))
              else if (shown[i].important)
                Text('IMPORTANT', style: AppText.meta(tk.inkSoft, size: 10)),
            ],
          ),
        ],
        if (todos.length > shown.length) ...[
          const SizedBox(height: 9),
          Text('+${todos.length - shown.length}개 더',
              style: AppText.meta(tk.inkSoft)),
        ],
      ],
    );
  }

  // ── 일정 ────────────────────────────────────────────────
  Widget _scheduleBody(AppTokens tk, List<Schedule> schedules) {
    if (schedules.isEmpty) return _empty(tk, '오늘 일정이 없어요');
    final shown = schedules.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 9),
          Row(
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  shown[i].allDay ? '종일' : _hhmm(shown[i].startMin),
                  style: AppText.meta(tk.ink, size: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  shown[i].title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(tk.ink),
                ),
              ),
            ],
          ),
        ],
        if (schedules.length > shown.length) ...[
          const SizedBox(height: 9),
          Text('+${schedules.length - shown.length}건 더',
              style: AppText.meta(tk.inkSoft)),
        ],
      ],
    );
  }

  // ── 습관 ────────────────────────────────────────────────
  Widget _habitBody(AppTokens tk, List<Habit> habits, List<HabitTick> ticks) {
    if (habits.isEmpty) return _empty(tk, '습관을 추가해 보세요');
    final doneIds = ticks.map((e) => e.habitId).toSet();
    final shown = habits.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 9),
          Row(
            children: [
              Text(
                doneIds.contains(shown[i].id) ? '■' : '□',
                style: AppText.glyph(
                    doneIds.contains(shown[i].id) ? tk.ink : tk.inkSoft,
                    size: 15),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  shown[i].title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(tk.ink),
                ),
              ),
            ],
          ),
        ],
        if (habits.length > shown.length) ...[
          const SizedBox(height: 9),
          Text('+${habits.length - shown.length}개 더',
              style: AppText.meta(tk.inkSoft)),
        ],
      ],
    );
  }

  // ── 시간 ────────────────────────────────────────────────
  String _timeCount(List<TimeBlock> blocks) {
    final filled = blocks.where((b) => b.content.trim().isNotEmpty).length;
    final h = filled * 0.5;
    return '${h.toStringAsFixed(h.truncateToDouble() == h ? 0 : 1)}h';
  }

  Widget _timeBody(AppTokens tk, List<TimeBlock> blocks) {
    final filledHours = <int>{};
    for (final b in blocks) {
      if (b.content.trim().isNotEmpty) filledHours.add(b.block ~/ 2);
    }
    if (filledHours.isEmpty) return _empty(tk, '아직 기록이 없어요');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 22,
          child: Row(
            children: [
              for (var hr = 0; hr < 24; hr++) ...[
                if (hr > 0) const SizedBox(width: 2),
                Expanded(
                  child: Container(
                    height: 22,
                    color: filledHours.contains(hr) ? tk.ink : tk.line,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('0시 – 24시 · 기록된 시간대', style: AppText.meta(tk.inkSoft)),
      ],
    );
  }

  // ── 운세 ────────────────────────────────────────────────
  Widget _fortuneBody(AppTokens tk, AppSettings settings) {
    if (!settings.hasBirth) {
      return _empty(tk, '생년월일을 입력하면 오늘의 운세가 보여요');
    }
    final chart = computeSaju(
      settings.birth!,
      hasHour: settings.birthHasTime,
      longitude: settings.birthLongitude,
      male: settings.birthMale,
    );
    final f = computeDailyFortune(chart, DateTime.now());
    final cats = f.categories.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('오늘 ${f.overall}점 · ${f.overallGrade}',
            style: AppText.body(tk.ink)),
        const SizedBox(height: 9),
        for (var i = 0; i < cats.length; i++) ...[
          if (i > 0) const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text('${cats[i].glyph} ${cats[i].title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(tk.ink)),
              ),
              const SizedBox(width: 8),
              Text('${cats[i].score}', style: AppText.meta(tk.inkSoft, size: 12)),
            ],
          ),
        ],
      ],
    );
  }
}
