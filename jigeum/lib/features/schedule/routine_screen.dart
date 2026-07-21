import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';

const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

/// 루틴 관리: 매일/요일 반복 일정 템플릿. 앱 열 때 오늘 일정으로 자동 생성.
class RoutineScreen extends ConsumerWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final routines = ref.watch(routinesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('루틴'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '새 루틴',
            onPressed: () => _edit(context, ref),
          ),
        ],
      ),
      body: Container(
        color: t(context).paper,
        child: routines.isEmpty
            ? Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: emptyNote(context, '반복되는 일정을 루틴으로 만들어요'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                children: [
                  for (final r in routines) _card(context, ref, theme, r),
                ],
              ),
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, ThemeData theme,
      Routine r) {
    final tk = t(context);
    final days = r.weekdays.split(',').where((s) => s.isNotEmpty).toList();
    final dayLabel = days.length == 7
        ? '매일'
        : days.map((d) => _weekdayNames[int.parse(d) - 1]).join('·');

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tk.line, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title,
                    style: AppText.body(r.active ? tk.ink : tk.inkSoft)),
                const SizedBox(height: 3),
                Text(
                    '$dayLabel · ${minToShort(r.startMin)}–${minToShort(r.endMin)}',
                    style: AppText.meta(tk.inkSoft)),
              ],
            ),
          ),
          // 켜기/끄기
          Switch(
            value: r.active,
            onChanged: (v) =>
                ref.read(scheduleRepoProvider).setRoutineActive(r.id, v),
          ),
          GestureDetector(
            onTap: () => _edit(context, ref, existing: r),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.edit_outlined, size: 18, color: tk.inkSoft),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref,
      {Routine? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _RoutineEditSheet(existing: existing),
    );
  }
}

class _RoutineEditSheet extends ConsumerStatefulWidget {
  const _RoutineEditSheet({this.existing});
  final Routine? existing;

  @override
  ConsumerState<_RoutineEditSheet> createState() => _RoutineEditSheetState();
}

class _RoutineEditSheetState extends ConsumerState<_RoutineEditSheet> {
  late final TextEditingController _title;
  late int _color;
  late int _start;
  late int _end;
  late Set<int> _days; // 1~7

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _color = e?.color ?? 1;
    _start = e?.startMin ?? 7 * 60;
    _end = e?.endMin ?? 8 * 60;
    _days = e == null
        ? {1, 2, 3, 4, 5, 6, 7}
        : e.weekdays
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toSet();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final init = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: init ~/ 60, minute: init % 60),
      cancelText: '취소',
      confirmText: '선택',
    );
    if (picked != null) {
      setState(() {
        final m = picked.hour * 60 + picked.minute;
        if (isStart) {
          _start = m;
          if (_end <= _start) _end = (_start + 60).clamp(0, 1439);
        } else {
          _end = m;
        }
      });
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _days.isEmpty) return;
    final repo = ref.read(scheduleRepoProvider);
    final weekdays = (_days.toList()..sort()).join(',');
    final e = widget.existing;
    if (e == null) {
      await repo.addRoutine(
        title: title,
        color: _color,
        startMin: _start,
        endMin: _end,
        weekdays: weekdays,
      );
    } else {
      await repo.db.update(repo.db.routines).replace(e.copyWith(
            title: title,
            color: _color,
            startMin: _start,
            endMin: _end,
            weekdays: weekdays,
          ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairline = theme.dividerTheme.color ?? Colors.black12;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing == null ? '새 루틴' : '루틴 수정',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            autofocus: widget.existing == null,
            decoration: const InputDecoration(
                hintText: '예: 아침 기상, 운동', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          // 요일 선택
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var d = 1; d <= 7; d++)
                GestureDetector(
                  onTap: () => setState(() {
                    _days.contains(d) ? _days.remove(d) : _days.add(d);
                  }),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _days.contains(d)
                          ? (theme.textTheme.bodyLarge?.color ?? Colors.black)
                          : Colors.transparent,
                      border: Border.all(color: hairline, width: 1),
                    ),
                    child: Text(
                      _weekdayNames[d - 1],
                      style: TextStyle(
                        fontSize: 13,
                        color: _days.contains(d)
                            ? theme.scaffoldBackgroundColor
                            : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _timeBtn(theme, '시작', _start, true)),
              const SizedBox(width: 10),
              Expanded(child: _timeBtn(theme, '끝', _end, false)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.existing != null)
                TextButton.icon(
                  onPressed: () async {
                    await ref
                        .read(scheduleRepoProvider)
                        .deleteRoutine(widget.existing!.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: theme.textTheme.bodySmall?.color),
                  label: Text('삭제', style: theme.textTheme.bodySmall),
                ),
              const Spacer(),
              FilledButton(onPressed: _save, child: const Text('저장')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeBtn(ThemeData theme, String label, int min, bool isStart) {
    final hairline = theme.dividerTheme.color ?? Colors.black12;
    return GestureDetector(
      onTap: () => _pickTime(isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          border: Border.all(color: hairline, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            Text(minToLabel(min), style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
