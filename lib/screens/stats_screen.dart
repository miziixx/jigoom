import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../flavor.dart';
import '../models/memo.dart';
import '../models/memo_actions.dart';
import '../widgets/input_bar.dart';
import '../widgets/logroom_entry_tile.dart';
import '../widgets/memo_tile.dart';
import '../widgets/scroll_picker_dialog.dart';

class StatsView extends StatefulWidget {
  final List<Memo> memos;
  final MemoActions actions;
  final String? contextLabel;
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

  const StatsView({
    super.key,
    required this.memos,
    required this.actions,
    this.contextLabel,
    this.onEditMemo,
  });

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  late DateTime _month;
  int? _selectedDay; // day tapped in heatmap
  Memo? _editingMemo;

  MemoActions get _localActions => widget.actions.copyWith(
    onEditRequest: (memo) => setState(() => _editingMemo = memo),
  );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  // ── computed ──────────────────────────────

  int get _memoCount => widget.memos.length;
  int get _todoCount => widget.memos.where((m) => m.isChecklist).length;
  int get _eventCount => widget.memos.where((m) => m.reminderAt != null).length;

  int get _wordCount {
    int total = 0;
    for (final m in widget.memos) {
      total += m.content
          .trim()
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .length;
    }
    return total;
  }

  int get _streak {
    if (widget.memos.isEmpty) return 0;
    final days =
        widget.memos
            .map((m) {
              final d = m.createdAt;
              return DateTime(d.year, d.month, d.day);
            })
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    DateTime check;
    if (days.contains(today)) {
      check = today;
    } else if (days.contains(yesterday)) {
      check = yesterday;
    } else {
      return 0;
    }
    int streak = 0;
    for (final day in days) {
      if (day == check) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      } else if (day.isBefore(check)) {
        break;
      }
    }
    return streak;
  }

  Map<String, int> get _tagCounts {
    final counts = <String, int>{};
    for (final m in widget.memos) {
      for (final t in m.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    return counts;
  }

  Map<int, int> _memoCountsInMonth(DateTime month) {
    final counts = <int, int>{};
    for (final m in widget.memos) {
      if (m.createdAt.year == month.year && m.createdAt.month == month.month) {
        counts[m.createdAt.day] = (counts[m.createdAt.day] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<Memo> _memosOnDay(DateTime month, int day) =>
      widget.memos
          .where(
            (m) =>
                m.createdAt.year == month.year &&
                m.createdAt.month == month.month &&
                m.createdAt.day == day,
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<MapEntry<String, int>> get _wordsPerMonth {
    final counts = <String, int>{};
    for (final m in widget.memos) {
      final key =
          '${m.createdAt.year}.${m.createdAt.month.toString().padLeft(2, '0')}';
      final words = m.content
          .trim()
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .length;
      counts[key] = (counts[key] ?? 0) + words;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.length > 12 ? sorted.sublist(sorted.length - 12) : sorted;
  }

  Future<void> _showYearPicker() async {
    final years = List.generate(111, (i) => 1990 + i);
    final result = await showScrollPicker(
      context: context,
      values: years,
      labels: years.map((y) => '$y').toList(),
      initialValue: _month.year,
    );
    if (result != null && mounted) {
      setState(() {
        _month = DateTime(result, _month.month);
        _selectedDay = null;
      });
    }
  }

  Future<void> _showMonthPicker() async {
    final months = List.generate(12, (i) => i + 1);
    final result = await showScrollPicker(
      context: context,
      values: months,
      labels: months.map((m) => m.toString().padLeft(2, '0')).toList(),
      initialValue: _month.month,
    );
    if (result != null && mounted) {
      setState(() {
        _month = DateTime(_month.year, result);
        _selectedDay = null;
      });
    }
  }

  void _submitEdit(
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
    final onEditMemo = widget.onEditMemo;
    if (editing == null || onEditMemo == null) return;
    onEditMemo(
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
  }

  // ── build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: themeNotifier,
      builder: (_, __, ___) => _buildContent(),
    );
  }

  Widget _buildContent() {
    const hPad = EdgeInsets.symmetric(horizontal: 14);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(padding: hPad, child: _buildStatsSection()),
                _divider(),
                _buildActivitySection(),
                _divider(),
                Padding(padding: hPad, child: _buildTopTagsSection()),
                _divider(),
                Padding(padding: hPad, child: _buildWordsPerMonthSection()),
                _divider(),
                Padding(padding: hPad, child: _buildMeta()),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (_editingMemo != null && widget.onEditMemo != null) ...[
          Container(height: 1, color: kBorder),
          InputBar(
            onSubmit: _submitEdit,
            folders: widget.actions.folders,
            editingMemo: _editingMemo,
            onCancelEdit: () => setState(() => _editingMemo = null),
          ),
        ],
      ],
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 18).floor().clamp(6, 64);
        return Text(
          '─' * count,
          style: mono(
            color: kBorder.withValues(alpha: 0.45),
            fontSize: 9,
            height: 1,
          ),
          overflow: TextOverflow.clip,
          maxLines: 1,
          softWrap: false,
        );
      },
    ),
  );

  // ── [ STATS ] ─────────────────────────────

  Widget _buildStatsSection() {
    final items = [
      ('memos    ', _memoCount.toString()),
      ('todos    ', _todoCount.toString()),
      ('events   ', _eventCount.toString()),
      ('words    ', _wordCount.toString()),
      ('streak   ', '$_streak days'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'STATS',
              style: mono(color: kMint, fontSize: 12, letterSpacing: 1),
            ),
            if (widget.contextLabel != null) ...[
              const SizedBox(width: 8),
              Text(
                '— ${widget.contextLabel}',
                style: mono(color: kDim.withValues(alpha: 0.7), fontSize: 10),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text('  ${item.$1}', style: mono(color: kDim, fontSize: 11)),
                Text(item.$2, style: mono(color: kText, fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── [ ACTIVITY ] ──────────────────────────

  // 5-step color: 0=empty, 1-5=progressively darker
  Color _heatColor(int count, int maxCount) {
    if (count == 0) return Colors.transparent;
    if (maxCount == 0) return kMint.withValues(alpha: 0.9);
    final ratio = count / maxCount;
    if (ratio <= 0.2) return kMint.withValues(alpha: 0.22);
    if (ratio <= 0.4) return kMint.withValues(alpha: 0.40);
    if (ratio <= 0.6) return kMint.withValues(alpha: 0.58);
    if (ratio <= 0.8) return kMint.withValues(alpha: 0.75);
    return kMint.withValues(alpha: 0.92);
  }

  Color _heatBorderColor({required bool filled}) {
    final isDarkBg =
        ThemeData.estimateBrightnessForColor(kBg) == Brightness.dark;
    if (isDarkBg) {
      return Color.lerp(
        kBorder,
        kText,
        filled ? 0.35 : 0.55,
      )!.withValues(alpha: filled ? 0.42 : 0.5);
    }
    return kBorder.withValues(alpha: filled ? 0.42 : 0.5);
  }

  Widget _buildActivitySection() {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final firstDay = DateTime(_month.year, _month.month, 1);
    final lastDay = DateTime(_month.year, _month.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startOffset = firstDay.weekday - 1; // 0=Mon
    final counts = _memoCountsInMonth(_month);
    final maxCount = counts.values.isEmpty
        ? 0
        : counts.values.reduce((a, b) => a > b ? a : b);
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;
    final todayDay = isCurrentMonth ? now.day : -1;
    final headerColor = isCurrentMonth ? kMint : kDim;

    // Memos for selected day
    final selectedDayMemos = _selectedDay != null
        ? _memosOnDay(_month, _selectedDay!)
        : <Memo>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── header + grid (padded) ────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'ACTIVITY',
                    style: mono(color: kMint, fontSize: 12, letterSpacing: 1),
                  ),
                  const Spacer(),
                  _NavBtn(
                    label: '<',
                    onTap: () => setState(() {
                      _month = DateTime(_month.year, _month.month - 1);
                      _selectedDay = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showYearPicker,
                    child: Text(
                      '${_month.year}',
                      style: mono(color: headerColor, fontSize: 10),
                    ),
                  ),
                  Text(
                    '.',
                    style: mono(
                      color: kDim.withValues(alpha: 0.4),
                      fontSize: 10,
                    ),
                  ),
                  GestureDetector(
                    onTap: _showMonthPicker,
                    child: Text(
                      _month.month.toString().padLeft(2, '0'),
                      style: mono(color: headerColor, fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _NavBtn(
                    label: '>',
                    onTap: () => setState(() {
                      _month = DateTime(_month.year, _month.month + 1);
                      _selectedDay = null;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v < -200) {
                    setState(() {
                      _month = DateTime(_month.year, _month.month + 1);
                      _selectedDay = null;
                    });
                  } else if (v > 200) {
                    setState(() {
                      _month = DateTime(_month.year, _month.month - 1);
                      _selectedDay = null;
                    });
                  }
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const cellSize = 20.0;
                    final hGap = (constraints.maxWidth - 7 * cellSize) / 6;
                    final vGap = (hGap * 0.6).clamp(2.0, 20.0);
                    final rowCount = ((startOffset + daysInMonth) / 7).ceil();
                    Widget buildRow(List<Widget> cells) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: cells,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        buildRow(
                          weekdays
                              .map(
                                (d) => SizedBox(
                                  width: cellSize,
                                  child: Center(
                                    child: Text(
                                      d,
                                      style: mono(color: kDim, fontSize: 7.5),
                                      softWrap: false,
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        SizedBox(height: vGap),
                        for (int r = 0; r < rowCount; r++) ...[
                          buildRow(
                            List.generate(7, (c) {
                              final day = r * 7 + c - startOffset + 1;
                              if (day < 1 || day > daysInMonth)
                                return SizedBox(
                                  width: cellSize,
                                  height: cellSize,
                                );
                              final count = counts[day] ?? 0;
                              final isToday = day == todayDay;
                              final isSelected = day == _selectedDay;
                              final fillColor = _heatColor(count, maxCount);
                              return GestureDetector(
                                onTap: count > 0
                                    ? () => setState(() {
                                        _selectedDay = (_selectedDay == day)
                                            ? null
                                            : day;
                                      })
                                    : null,
                                child: SizedBox(
                                  width: cellSize,
                                  height: cellSize,
                                  child: Center(
                                    child: Container(
                                      width: cellSize - 3,
                                      height: cellSize - 3,
                                      decoration: BoxDecoration(
                                        color: count > 0
                                            ? fillColor
                                            : Colors.transparent,
                                        border: isSelected
                                            ? Border.all(
                                                color: kMint,
                                                width: 1.5,
                                              )
                                            : isToday
                                            ? Border.all(
                                                color: kMint.withValues(
                                                  alpha: 0.7,
                                                ),
                                                width: 1,
                                              )
                                            : Border.all(
                                                color: _heatBorderColor(
                                                  filled: count > 0,
                                                ),
                                                width: 0.8,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          if (r < rowCount - 1) SizedBox(height: vGap),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // ── selected day bar — full width, no padding ─────────────
        if (_selectedDay != null && selectedDayMemos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            color: kMint,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Text(
                  '${_month.year}.${_month.month.toString().padLeft(2, '0')}.${_selectedDay.toString().padLeft(2, '0')}  '
                  '${['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][DateTime(_month.year, _month.month, _selectedDay!).weekday - 1]}',
                  style: mono(
                    color: kBg,
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${selectedDayMemos.length} memo${selectedDayMemos.length == 1 ? '' : 's'}',
                  style: mono(color: kBg.withValues(alpha: 0.7), fontSize: 10),
                ),
              ],
            ),
          ),
          ...selectedDayMemos.map(
            (m) => isLogroomUi
                ? LogroomEntryTile(memo: m, actions: _localActions)
                : MemoTile(memo: m, actions: _localActions),
          ),
        ],
      ],
    );
  }

  // ── [ TOP TAGS ] ──────────────────────────

  Widget _buildTopTagsSection() {
    final counts = _tagCounts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOP TAGS',
          style: mono(color: kMint, fontSize: 12, letterSpacing: 1),
        ),
        const SizedBox(height: 10),
        if (counts.isEmpty)
          Text(
            '  no tags yet',
            style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 11),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final sorted = counts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final top = sorted.take(10).toList();
              final maxCount = top.first.value;
              const rankW = 22.0;
              const tagW = 100.0;
              const countW = 28.0;
              const gap = 6.0;
              final barMaxW =
                  (constraints.maxWidth - rankW - tagW - countW - gap * 3)
                      .clamp(10.0, double.infinity);

              return Column(
                children: top.asMap().entries.map((e) {
                  final rank = e.key + 1;
                  final tag = e.value.key;
                  final count = e.value.value;
                  final barW = maxCount > 0
                      ? (count / maxCount * barMaxW).clamp(2.0, barMaxW)
                      : 2.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: rankW,
                          child: Text(
                            '$rank.',
                            style: mono(color: kDim, fontSize: 9),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: gap),
                        SizedBox(
                          width: tagW,
                          child: Text(
                            '#$tag',
                            style: mono(color: kText, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: gap),
                        Container(
                          width: barW,
                          height: 7,
                          color: kMint.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: gap),
                        SizedBox(
                          width: countW,
                          child: Text(
                            '$count',
                            style: mono(color: kDim, fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  // ── [ WORDS / MONTH ] ─────────────────────

  Widget _buildWordsPerMonthSection() {
    final data = _wordsPerMonth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WORDS / MONTH',
          style: mono(color: kMint, fontSize: 12, letterSpacing: 1),
        ),
        const SizedBox(height: 10),
        if (data.isEmpty)
          Text(
            '  no data yet',
            style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 11),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final maxCount = data
                  .map((e) => e.value)
                  .reduce((a, b) => a > b ? a : b);
              const labelW = 58.0;
              const countW = 38.0;
              const gap = 6.0;
              final barArea = (constraints.maxWidth - labelW - countW - gap * 2)
                  .clamp(10.0, double.infinity);
              // ~7px per '█' char at fontSize 10 monospace
              final maxBlocks = (barArea / 7.0).floor().clamp(1, 500);

              return Column(
                children: data.map((entry) {
                  final count = entry.value;
                  final blockCount = maxCount > 0
                      ? (count / maxCount * maxBlocks).round().clamp(
                          1,
                          maxBlocks,
                        )
                      : 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: labelW,
                          child: Text(
                            entry.key,
                            style: mono(color: kDim, fontSize: 9),
                          ),
                        ),
                        const SizedBox(width: gap),
                        SizedBox(
                          width: barArea,
                          child: Text(
                            '█' * blockCount,
                            style: mono(
                              color: kMint,
                              fontSize: 10,
                              height: 1.2,
                            ),
                            overflow: TextOverflow.clip,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                        const SizedBox(width: gap),
                        SizedBox(
                          width: countW,
                          child: Text(
                            '$count',
                            style: mono(color: kDim, fontSize: 9),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  // ── meta ──────────────────────────────────

  Widget _buildMeta() {
    if (widget.memos.isEmpty) return const SizedBox.shrink();
    final sorted = [...widget.memos]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    String fmt(DateTime d) =>
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '  created    : ${fmt(sorted.first.createdAt)}',
          style: mono(color: kDim, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          '  last entry : ${fmt(sorted.last.createdAt)}',
          style: mono(color: kDim, fontSize: 10),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Internal nav button
// ─────────────────────────────────────────────────────────────────

class _NavBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NavBtn({required this.label, required this.onTap});

  @override
  State<_NavBtn> createState() => _NavBtnState();
}

class _NavBtnState extends State<_NavBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          color: _hovered ? kMint.withValues(alpha: 0.1) : Colors.transparent,
          child: Text(
            widget.label,
            style: mono(color: _hovered ? kMint : kDim, fontSize: 10),
          ),
        ),
      ),
    );
  }
}
