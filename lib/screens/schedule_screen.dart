import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../flavor.dart';
import '../models/memo.dart';
import '../models/memo_actions.dart';
import '../widgets/logroom_entry_tile.dart';
import '../widgets/memo_tile.dart';
import '../widgets/input_bar.dart';

class ScheduleView extends StatefulWidget {
  final List<Memo> memos;
  final MemoActions actions;
  final void Function(
    String content,
    bool isChecklist,
    DateTime? reminderAt,
    String? folderId,
    List<String> imagePaths,
    String reminderRepeat,
    DateTime? scheduledAt,
    DateTime? rangeEndDate,
    String scheduleRepeat,
    String repeatEndType,
    int repeatEndCount,
    DateTime? repeatEndDate,
  )?
  onAddMemo;
  final void Function(
    Memo memo,
    String content,
    bool isChecklist,
    DateTime? reminderAt,
    String? folderId,
    List<String> imagePaths,
    String reminderRepeat,
    DateTime? scheduledAt,
    DateTime? rangeEndDate,
    String scheduleRepeat,
    String repeatEndType,
    int repeatEndCount,
    DateTime? repeatEndDate,
  )?
  onEditMemo;

  const ScheduleView({
    super.key,
    required this.memos,
    required this.actions,
    this.onAddMemo,
    this.onEditMemo,
  });

  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  final _collapsed = <String>{};
  Memo? _editingMemo;

  MemoActions get _localActions => widget.actions.copyWith(
    onEditRequest: (memo) => setState(() => _editingMemo = memo),
  );

  void _submitFromInput(
    String content,
    bool isChecklist,
    DateTime? reminderAt,
    String? folderId,
    List<String> imagePaths,
    String reminderRepeat,
    DateTime? scheduledAt,
    DateTime? rangeEndDate,
    String scheduleRepeat,
    String repeatEndType,
    int repeatEndCount,
    DateTime? repeatEndDate,
  ) {
    final editing = _editingMemo;
    if (editing != null && widget.onEditMemo != null) {
      widget.onEditMemo!(
        editing,
        content,
        isChecklist,
        reminderAt,
        folderId,
        imagePaths,
        reminderRepeat,
        scheduledAt,
        rangeEndDate,
        scheduleRepeat,
        repeatEndType,
        repeatEndCount,
        repeatEndDate,
      );
      setState(() => _editingMemo = null);
      return;
    }
    widget.onAddMemo?.call(
      content,
      isChecklist,
      reminderAt,
      folderId,
      imagePaths,
      reminderRepeat,
      scheduledAt,
      rangeEndDate,
      scheduleRepeat,
      repeatEndType,
      repeatEndCount,
      repeatEndDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: themeNotifier,
      builder: (_, __, ___) => _buildContent(),
    );
  }

  Widget _buildContent() {
    final now = DateTime.now();
    final todayKey = _dateKey(now);

    final scheduled = widget.memos.where((m) => m.scheduledAt != null).toList();

    if (scheduled.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                '예정된 이벤트가 없어요',
                style: mono(color: kDim.withValues(alpha: 0.4), fontSize: 12),
              ),
            ),
          ),
          Container(height: 1, color: kBorder),
          if (widget.onAddMemo != null)
            InputBar(
              scheduleMode: true,
              onSubmit: _submitFromInput,
              editingMemo: _editingMemo,
              onCancelEdit: () => setState(() => _editingMemo = null),
            ),
        ],
      );
    }

    // Group by reminderAt date
    final grouped = <String, List<Memo>>{};
    for (final m in scheduled) {
      final k = _dateKey(m.scheduledAt!);
      grouped.putIfAbsent(k, () => []).add(m);
    }
    // Sort memos within each group by time
    for (final list in grouped.values) {
      list.sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    }

    // Split date keys: future/today (ascending) then past (descending)
    final futureKeys =
        grouped.keys.where((k) => k.compareTo(todayKey) >= 0).toList()..sort();
    final pastKeys =
        grouped.keys.where((k) => k.compareTo(todayKey) < 0).toList()
          ..sort((a, b) => b.compareTo(a)); // most recent past first

    final items = <Widget>[];

    for (final key in futureKeys) {
      final memos = grouped[key]!;
      final isToday = key == todayKey;
      items.add(
        _DateHeader(
          dateKey: key,
          count: memos.length,
          isToday: isToday,
          isPast: false,
          collapsed: _collapsed.contains(key),
          onToggle: () => setState(() {
            if (_collapsed.contains(key)) {
              _collapsed.remove(key);
            } else {
              _collapsed.add(key);
            }
          }),
        ),
      );
      if (!_collapsed.contains(key)) {
        for (final m in memos) {
          items.add(_ScheduleTile(memo: m, actions: _localActions));
        }
      }
    }

    if (pastKeys.isNotEmpty) {
      items.add(_PastDivider());
      for (final key in pastKeys) {
        final memos = grouped[key]!;
        items.add(
          _DateHeader(
            dateKey: key,
            count: memos.length,
            isToday: false,
            isPast: true,
            collapsed: _collapsed.contains(key),
            onToggle: () => setState(() {
              if (_collapsed.contains(key)) {
                _collapsed.remove(key);
              } else {
                _collapsed.add(key);
              }
            }),
          ),
        );
        if (!_collapsed.contains(key)) {
          for (final m in memos) {
            items.add(
              _ScheduleTile(memo: m, actions: _localActions, isPast: true),
            );
          }
        }
      }
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 8),
            children: items,
          ),
        ),
        Container(height: 1, color: kBorder),
        if (widget.onAddMemo != null)
          InputBar(
            scheduleMode: true,
            onSubmit: _submitFromInput,
            editingMemo: _editingMemo,
            onCancelEdit: () => setState(() => _editingMemo = null),
          ),
      ],
    );
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────
// Date group header (collapsible)
// ─────────────────────────────────────────────────────────────────

class _DateHeader extends StatefulWidget {
  final String dateKey; // YYYY-MM-DD
  final int count;
  final bool isToday;
  final bool isPast;
  final bool collapsed;
  final VoidCallback onToggle;

  const _DateHeader({
    required this.dateKey,
    required this.count,
    required this.isToday,
    required this.isPast,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  State<_DateHeader> createState() => _DateHeaderState();
}

class _DateHeaderState extends State<_DateHeader> {
  bool _hovered = false;

  static String _fmt(String key, bool isToday) {
    final parts = key.split('-');
    final d = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    const wd = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = d.difference(today).inDays;

    String label;
    if (diff == 0)
      label = '오늘';
    else if (diff == 1)
      label = '내일';
    else if (diff == -1)
      label = '어제';
    else if (diff > 0)
      label = 'D-$diff';
    else
      label = 'D+${-diff}';

    return '${parts[0]}.${parts[1]}.${parts[2]}  ${wd[d.weekday - 1]}  $label';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isToday
        ? kMint
        : widget.isPast
        ? kDim.withValues(alpha: 0.45)
        : kText;
    final bg = widget.isToday
        ? kMint.withValues(alpha: 0.08)
        : _hovered
        ? kSurface
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          color: bg,
          padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
          child: Row(
            children: [
              Text(
                _fmt(widget.dateKey, widget.isToday).toUpperCase(),
                style: monoLabel(
                  color: color,
                  fontSize: 11,
                  fontWeight: widget.isToday
                      ? FontWeight.w600
                      : FontWeight.normal,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.count}',
                style: monoLabel(color: color.withValues(alpha: 0.6), fontSize: 10),
              ),
              const Spacer(),
              Text(
                widget.collapsed ? '▸' : '▾',
                style: mono(color: color.withValues(alpha: 0.5), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Past section divider
// ─────────────────────────────────────────────────────────────────

class _PastDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(
        children: [
          Text(
            '── 지난 일정 ',
            style: mono(
              color: kDim.withValues(alpha: 0.4),
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
          Expanded(
            child: Text(
              '─' * 80,
              style: mono(color: kDim.withValues(alpha: 0.2), fontSize: 9),
              overflow: TextOverflow.clip,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Schedule tile — time + MemoTile
// ─────────────────────────────────────────────────────────────────

class _ScheduleTile extends StatelessWidget {
  final Memo memo;
  final MemoActions actions;
  final bool isPast;

  const _ScheduleTile({
    required this.memo,
    required this.actions,
    this.isPast = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = memo.scheduledAt!;
    final timeStr =
        '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}';
    final color = isPast ? kDim.withValues(alpha: 0.4) : kMint;

    if (isLogroomUi) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 7, 14, 0),
            child: Text(timeStr, style: mono(color: color, fontSize: 10)),
          ),
          LogroomEntryTile(memo: memo, actions: actions),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 7, 14, 0),
          child: Text(timeStr, style: mono(color: color, fontSize: 10)),
        ),
        MemoTile(memo: memo, actions: actions),
      ],
    );
  }
}
