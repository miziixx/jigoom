import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drift/drift.dart' show Value;

import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../gcal/gcal_controller.dart';

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
  late bool _allDay;
  String? _calId; // 저장할 구글 캘린더(종류)

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _color = e?.color ?? 0;
    _start = e?.startMin ?? 9 * 60;
    _end = e?.endMin ?? 10 * 60;
    _allDay = e?.allDay ?? false;
    _calId = e?.gcalCalendarId;
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
        allDay: _allDay,
        gcalCalendarId: _calId,
      );
    } else {
      await repo.updateSchedule(e.copyWith(
        title: title,
        note: _note.text.trim(),
        color: _color,
        startMin: _start,
        endMin: _end,
        allDay: _allDay,
        gcalCalendarId: Value(_calId),
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final editing = widget.existing != null;
    return Container(
      color: tk.paper,
      padding: EdgeInsets.only(
        left: kGutter,
        right: kGutter,
        top: 18,
        bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 마스트헤드
          Row(
            children: [
              Text(editing ? '일정 수정' : '새 일정',
                  style: AppText.meta(tk.inkSoft, size: 10)
                      .copyWith(letterSpacing: 1.4)),
              const Spacer(),
              if (editing)
                GestureDetector(
                  onTap: () async {
                    await ref
                        .read(scheduleRepoProvider)
                        .deleteSchedule(widget.existing!.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Text('삭제', style: AppText.meta(tk.mark, size: 11)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: tk.ink),
          const SizedBox(height: 14),
          // 제목 (프롬프트)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: Text('›', style: AppText.glyph(tk.mark, size: 16)),
              ),
              Expanded(
                child: TextField(
                  controller: _title,
                  autofocus: !editing,
                  cursorColor: tk.mark,
                  style: AppText.body(tk.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '무엇을 하나요?',
                    hintStyle: AppText.meta(tk.inkSoft, size: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 종일 토글
          Row(
            children: [
              Expanded(child: Text('종일', style: AppText.body(tk.ink))),
              Switch(
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v),
              ),
            ],
          ),
          // 시간 (종일이 아닐 때만)
          if (!_allDay) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: _timeBtn(tk, '시작', _start, true)),
                const SizedBox(width: 10),
                Expanded(child: _timeBtn(tk, '끝', _end, false)),
              ],
            ),
          ],
          // 구글 캘린더(종류) 선택 — 연결됐고 선택된 캘린더가 있을 때만.
          _calendarPicker(tk),
          const SizedBox(height: 14),
          // 메모
          TextField(
            controller: _note,
            cursorColor: tk.mark,
            style: AppText.body(tk.ink),
            decoration: InputDecoration(
              isDense: true,
              hintText: '메모 (선택)',
              hintStyle: AppText.meta(tk.inkSoft, size: 13),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 18),
          // 액션
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text('취소', style: AppText.nav(tk.inkSoft)),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _save,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  color: tk.ink,
                  child: Text('저장',
                      style: AppText.nav(tk.paper, active: true)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 구글 캘린더 종류 선택 — 연결됐고 동기화 대상 캘린더가 있을 때만 노출.
  Widget _calendarPicker(AppTokens tk) {
    final connected = ref.watch(gcalControllerProvider).connected;
    if (!connected) return const SizedBox.shrink();
    final cals = ref.watch(gcalCalendarsProvider).valueOrNull ?? const [];
    final writable = cals
        .where((c) =>
            c.selected &&
            (c.accessRole == 'writer' || c.accessRole == 'owner'))
        .toList();
    if (writable.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('구글 캘린더', style: AppText.meta(tk.inkSoft, size: 10)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in writable)
                GestureDetector(
                  onTap: () => setState(() => _calId = c.id),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _calId == c.id ? tk.ink : tk.line,
                        width: _calId == c.id ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      c.summary,
                      style: AppText.chip(
                          _calId == c.id ? tk.ink : tk.inkSoft),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeBtn(AppTokens tk, String label, int min, bool isStart) {
    return GestureDetector(
      onTap: () => _pickTime(isStart),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: tk.line)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppText.meta(tk.inkSoft, size: 11)),
            Text(minToLabel(min), style: AppText.body(tk.ink)),
          ],
        ),
      ),
    );
  }
}
