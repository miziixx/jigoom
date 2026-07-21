import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/journal.dart';
import '../../data/db.dart';
import '../../providers.dart';

/// 일정 추가/수정 시트. date=새 일정 / existing=수정.
Future<void> showScheduleEditSheet(BuildContext context,
    {DateTime? date, Schedule? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => _Sheet(date: date, existing: existing),
  );
}

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({this.date, this.existing});
  final DateTime? date;
  final Schedule? existing;

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late int _color;
  late int _start;
  late int _end;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _color = e?.color ?? 0;
    _start = e?.startMin ?? 9 * 60;
    _end = e?.endMin ?? 10 * 60;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
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
    if (title.isEmpty) return;
    final repo = ref.read(scheduleRepoProvider);
    final e = widget.existing;
    if (e == null) {
      await repo.addSchedule(
        date: widget.date ?? DateTime.now(),
        title: title,
        note: _note.text.trim(),
        color: _color,
        startMin: _start,
        endMin: _end,
      );
    } else {
      await repo.updateSchedule(e.copyWith(
        title: title,
        note: _note.text.trim(),
        color: _color,
        startMin: _start,
        endMin: _end,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Text(widget.existing == null ? '새 일정' : '일정 수정',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            autofocus: widget.existing == null,
            decoration: const InputDecoration(
                hintText: '무엇을 하나요?', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          // 시간
          Row(
            children: [
              Expanded(child: _timeBtn(theme, '시작', _start, true)),
              const SizedBox(width: 10),
              Expanded(child: _timeBtn(theme, '끝', _end, false)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                hintText: '메모 (선택)', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.existing != null)
                TextButton.icon(
                  onPressed: () async {
                    await ref
                        .read(scheduleRepoProvider)
                        .deleteSchedule(widget.existing!.id);
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
