import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../data/db.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../providers.dart';

/// 습관 탭 — 모노 트리(├─ └─ │)로 카테고리 → 습관.
/// 각 습관 leaf 에서 오늘 체크(□/■). 습관을 탭하면 기간별 상세 화면.
class HabitView extends ConsumerWidget {
  const HabitView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final habits = ref.watch(habitsProvider).valueOrNull ?? const [];

    if (habits.isEmpty) {
      return Container(
        color: tk.paper,
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.only(top: 26),
        child: emptyNote(context, '오른쪽 위 + 로 습관을 만들어보세요'),
      );
    }

    final byCat = <String, List<Habit>>{};
    for (final h in habits) {
      byCat.putIfAbsent(h.category, () => []).add(h);
    }
    final cats = byCat.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty) return -1;
        if (b.isEmpty) return 1;
        return a.compareTo(b);
      });

    final rows = <Widget>[];
    rows.add(Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 6),
      child: Text('HABITS', style: AppText.sec(tk.ink)),
    ));

    for (var ci = 0; ci < cats.length; ci++) {
      final lastCat = ci == cats.length - 1;
      final catCont = lastCat ? '    ' : '│   ';
      final list = byCat[cats[ci]]!;

      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 4),
        child: Row(
          children: [
            Text(lastCat ? '└─ ' : '├─ ',
                style: AppText.glyph(tk.inkSoft, size: 13)),
            Text(cats[ci].isEmpty ? 'GENERAL' : cats[ci].toUpperCase(),
                style: AppText.sec(tk.ink)),
            const SizedBox(width: 8),
            Text('${list.length}', style: AppText.meta(tk.inkSoft, size: 10)),
          ],
        ),
      ));

      for (var hi = 0; hi < list.length; hi++) {
        final lastH = hi == list.length - 1;
        rows.add(_HabitRow(
          habit: list[hi],
          prefix: '$catCont${lastH ? '└─ ' : '├─ '}',
        ));
      }
    }

    rows.add(const SizedBox(height: 16));

    return Container(
      color: tk.paper,
      child: ListView(padding: EdgeInsets.zero, children: rows),
    );
  }
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
    final total = today.difference(dateOnly(habit.createdAt)).inDays + 1;
    final percent = total == 0 ? 0 : (tickSet.length * 100 / total).round();

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HabitDetailScreen(habit: habit),
      )),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 7, kGutter, 7),
        child: Row(
          children: [
            Text(prefix, style: AppText.glyph(tk.inkSoft, size: 13)),
            GestureDetector(
              onTap: () =>
                  ref.read(habitRepoProvider).toggleTick(habit.id, today),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(todayDone ? '■' : '□',
                    style: AppText.glyph(tk.ink, size: 15)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(habit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(todayDone ? tk.inkSoft : tk.ink)),
            ),
            const SizedBox(width: 8),
            Text('$percent%', style: AppText.meta(tk.inkSoft, size: 10)),
            const SizedBox(width: 6),
            Text('›', style: AppText.glyph(tk.inkSoft, size: 13)),
          ],
        ),
      ),
    );
  }
}

/// 습관 상세 — 기간을 골라 그 기간의 통계 + ●/○ 기록을 본다.
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
    _start = dateOnly(widget.habit.createdAt); // 기본 = 전체(시작일~오늘)
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
    final ticks =
        ref.watch(habitTicksProvider(widget.habit.id)).valueOrNull ?? const [];
    final tickSet = {for (final t in ticks) dateOnly(t.date)};

    // 기간 내 일수/완료/퍼센트.
    final rangeDays = _end.difference(_start).inDays + 1;
    var doneInRange = 0;
    for (var i = 0; i < rangeDays; i++) {
      if (tickSet.contains(_start.add(Duration(days: i)))) doneInRange++;
    }
    final percent =
        rangeDays == 0 ? 0 : (doneInRange * 100 / rangeDays).round();
    final gridDays = rangeDays.clamp(1, 372);

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
            const SectionLabel('RANGE'),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _rangeChip('7일', () => _setQuick('7일', 7),
                      _label == '7일'),
                  _rangeChip('30일', () => _setQuick('30일', 30),
                      _label == '30일'),
                  _rangeChip('전체', () => _setQuick('전체', null),
                      _label == '전체'),
                  _rangeChip(
                      _label.contains('~') ? _label : '기간 선택',
                      _pickRange,
                      _label.contains('~')),
                ],
              ),
            ),

            const SectionLabel('STATS'),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stat(tk, '$doneInRange', '일 완료'),
                  _stat(tk, '$rangeDays', '일 중'),
                  _stat(tk, '$percent%', '만큼 해냈어요'),
                ],
              ),
            ),

            const SectionLabel('LOG'),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < gridDays; i++)
                    _dot(
                      tk,
                      day: _start.add(Duration(days: i)),
                      filled:
                          tickSet.contains(_start.add(Duration(days: i))),
                    ),
                ],
              ),
            ),
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
    final controller = TextEditingController(text: widget.habit.category);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카테고리'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: '예: 건강, 공부 (비우면 기본)'),
          onSubmitted: (s) => Navigator.of(ctx).pop(s),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('저장')),
        ],
      ),
    );
    if (v == null) return;
    await ref.read(habitRepoProvider).setCategory(widget.habit.id, v.trim());
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${widget.habit.title}" 삭제할까요?'),
        content: const Text('기록도 함께 지워져요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(habitRepoProvider).deleteHabit(widget.habit.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}
