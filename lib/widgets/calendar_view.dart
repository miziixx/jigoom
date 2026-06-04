import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/memo.dart';
import '../models/memo_actions.dart';
import 'memo_tile.dart';
import 'input_bar.dart';
import 'scroll_picker_dialog.dart';


// Wide layout threshold: side-by-side calendar + day panel
const _kWide = 620.0;

class CalendarView extends StatefulWidget {
  final List<Memo> memos;
  final MemoActions actions;
  final void Function(String content, DateTime date, bool isChecklist, DateTime? reminderAt, List<String> imagePaths, String reminderRepeat) onAddMemo;
  final String? highlightedMemoId;

  const CalendarView({
    super.key,
    required this.memos,
    required this.actions,
    required this.onAddMemo,
    this.highlightedMemoId,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late int _year;
  late int _month;
  late DateTime _selectedDay;

  static const _cellH = 42.0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year        = now.year;
    _month       = now.month;
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  // ── Computed data ─────────────────────────────────────────────

  Map<String, List<Memo>> get _memosByDate {
    final map = <String, List<Memo>>{};
    for (final m in widget.memos) {
      map.putIfAbsent(m.dateKey, () => []).add(m);
    }
    return map;
  }

  Set<String> get _reminderDates {
    final set = <String>{};
    for (final m in widget.memos) {
      final r = m.reminderAt;
      if (r != null) {
        set.add(_key(r.year, r.month, r.day));
      }
    }
    return set;
  }

  String _key(int y, int mo, int d) =>
      '$y-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

  List<Memo> _memosForDay(DateTime day) {
    final list = _memosByDate[_key(day.year, day.month, day.day)] ?? [];
    return [...list]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  // ── Month navigation ──────────────────────────────────────────

  void _prevMonth() => setState(() {
        if (_month == 1) {
          _month = 12;
          _year--;
        } else {
          _month--;
        }
      });

  void _nextMonth() => setState(() {
        if (_month == 12) {
          _month = 1;
          _year++;
        } else {
          _month++;
        }
      });

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _year        = now.year;
      _month       = now.month;
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final isWide = constraints.maxWidth >= _kWide;
      if (isWide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 330, child: _buildCalendarPanel()),
            Expanded(child: _buildDayPanel()),
          ],
        );
      }
      // Narrow (phone): calendar + day header + memo list share one scroll
      // area, and the input bar is pinned at the bottom. This keeps the
      // input usable (and on-screen) even when the keyboard pushes up.
      return _buildNarrowLayout();
    });
  }

  Widget _buildNarrowLayout() {
    final memos = _memosForDay(_selectedDay);
    return Column(
      children: [
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              _buildCalendarPanel(),
              _buildDayHeader(memos),
              if (memos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'no memos on this day',
                      style: mono(
                          color: kDim.withValues(alpha: 0.35), fontSize: 12),
                    ),
                  ),
                )
              else
                ...memos.map((memo) => MemoTile(
                      memo:        memo,
                      actions:     widget.actions,
                      highlighted: widget.highlightedMemoId == memo.id,
                    )),
            ],
          ),
        ),
        // Input bar — pinned at bottom, always usable above the keyboard.
        InputBar(
          initialDate: _selectedDay,
          onSubmit: (content, isChecklist, reminderAt, _, imgs, rep, sched,
                  rangeEnd, schedRep, endType, endCount, endDate) =>
              widget.onAddMemo(content, _selectedDay, isChecklist, reminderAt, imgs, rep),
        ),
      ],
    );
  }

  Widget _buildDayHeader(List<Memo> memos) {
    final d = _selectedDay;
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final wdLabel = weekdays[d.weekday - 1];
    final dateLabel =
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}  $wdLabel';
    return Container(
      color: kMint,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Text(dateLabel,
              style: mono(color: kBg, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Text(
            memos.isEmpty
                ? 'no memos'
                : '${memos.length} memo${memos.length == 1 ? '' : 's'}',
            style: mono(color: kBg.withValues(alpha: 0.7), fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ── Calendar grid panel ───────────────────────────────────────

  Widget _buildCalendarPanel() {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -200) _nextMonth();
        else if (v > 200) _prevMonth();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMonthHeader(),
          _buildWeekdayRow(),
          _buildGrid(),
        ],
      ),
    );
  }

  Future<void> _showYearPicker() async {
    final years = List.generate(111, (i) => 1990 + i);
    final result = await showScrollPicker(
      context: context,
      values: years,
      labels: years.map((y) => '$y').toList(),
      initialValue: _year,
    );
    if (result != null && mounted) setState(() => _year = result);
  }

  Future<void> _showMonthPicker() async {
    final months = List.generate(12, (i) => i + 1);
    final result = await showScrollPicker(
      context: context,
      values: months,
      labels: months.map((m) => m.toString().padLeft(2, '0')).toList(),
      initialValue: _month,
    );
    if (result != null && mounted) setState(() => _month = result);
  }

  Widget _buildMonthHeader() {
    final now = DateTime.now();
    final isCurrentMonth = _year == now.year && _month == now.month;
    final labelColor = isCurrentMonth ? kMint : kText;
    final weight = isCurrentMonth ? FontWeight.bold : FontWeight.normal;

    return Container(
      color: kBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _NavBtn(label: '[<]', onTap: _prevMonth),
          const Spacer(),
          GestureDetector(
            onTap: _showYearPicker,
            child: Text(
              '$_year',
              style: mono(color: labelColor, fontSize: 13, letterSpacing: 1, fontWeight: weight),
            ),
          ),
          Text(' · ', style: mono(color: kDim.withValues(alpha: 0.4), fontSize: 13)),
          GestureDetector(
            onTap: _showMonthPicker,
            child: Text(
              _month.toString().padLeft(2, '0'),
              style: mono(color: labelColor, fontSize: 13, letterSpacing: 1, fontWeight: weight),
            ),
          ),
          const Spacer(),
          _NavBtn(label: '[>]', onTap: _nextMonth),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow() {
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: labels.asMap().entries.map((e) {
          final isSat = e.key == 5;
          final isSun = e.key == 6;
          final color = isSun
              ? const Color(0xFFFF1744).withValues(alpha: 0.8)
              : isSat
                  ? kTeal.withValues(alpha: 0.7)
                  : kDim.withValues(alpha: 0.55);
          return Expanded(
            child: Center(
              child: Text(e.value,
                  style: mono(color: color, fontSize: 9, letterSpacing: 0.5)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGrid() {
    final firstDay    = DateTime(_year, _month, 1);
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final offset      = firstDay.weekday - 1; // Mon=0 … Sun=6
    const rows        = 6; // always 6 rows → consistent height across months

    final byDate      = _memosByDate;
    final reminderSet = _reminderDates;
    final now         = DateTime.now();
    final todayKey    = _key(now.year, now.month, now.day);

    return LayoutBuilder(builder: (ctx, c) {
      final cellW = c.maxWidth / 7;
      return SizedBox(
        height: rows * _cellH,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: cellW / _cellH,
          ),
          itemCount: rows * 7,
          itemBuilder: (_, i) {
            final dayNum = i - offset + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return const SizedBox.shrink();
            }

            final date         = DateTime(_year, _month, dayNum);
            final k            = _key(_year, _month, dayNum);
            final hasMemo      = (byDate[k]?.isNotEmpty) ?? false;
            final hasReminder  = reminderSet.contains(k);
            final isToday      = k == todayKey;
            final isSelected   = date.year == _selectedDay.year &&
                date.month == _selectedDay.month &&
                date.day == _selectedDay.day;
            final weekIdx      = i % 7;

            return _DayCell(
              day:          dayNum,
              hasMemo:      hasMemo,
              hasReminder:  hasReminder,
              isToday:      isToday,
              isSelected:   isSelected,
              isSat:        weekIdx == 5,
              isSun:        weekIdx == 6,
              onTap:        () => setState(() => _selectedDay = date),
            );
          },
        ),
      );
    });
  }

  // ── Day memo panel ────────────────────────────────────────────

  Widget _buildDayPanel() {
    final memos = _memosForDay(_selectedDay);
    final d     = _selectedDay;
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final wdLabel = weekdays[d.weekday - 1];
    final dateLabel =
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}  $wdLabel';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header — inverted
        Container(
          color: kMint,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Text(dateLabel,
                  style: mono(color: kBg, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Text(
                memos.isEmpty
                    ? 'no memos'
                    : '${memos.length} memo${memos.length == 1 ? '' : 's'}',
                style: mono(color: kBg.withValues(alpha: 0.7), fontSize: 10),
              ),
            ],
          ),
        ),

        // Memo list
        Expanded(
          child: memos.isEmpty
              ? Center(
                  child: Text(
                    'no memos on this day',
                    style: mono(
                        color: kDim.withValues(alpha: 0.35), fontSize: 12),
                  ),
                )
              : ListView.builder(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: memos.length,
                  itemBuilder: (_, i) {
                    final memo = memos[i];
                    return MemoTile(
                      memo:        memo,
                      actions:     widget.actions,
                      highlighted: widget.highlightedMemoId == memo.id,
                    );
                  },
                ),
        ),
        // Input bar — saves memo to selected day's date
        InputBar(
          initialDate: _selectedDay,
          onSubmit: (content, isChecklist, reminderAt, _, imgs, rep, sched,
                  rangeEnd, schedRep, endType, endCount, endDate) =>
              widget.onAddMemo(content, _selectedDay, isChecklist, reminderAt, imgs, rep),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Day cell
// ─────────────────────────────────────────────────────────────────

class _DayCell extends StatefulWidget {
  final int day;
  final bool hasMemo, hasReminder, isToday, isSelected, isSat, isSun;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.hasMemo,
    required this.hasReminder,
    required this.isToday,
    required this.isSelected,
    required this.isSat,
    required this.isSun,
    required this.onTap,
  });

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // Text color
    Color dayColor;
    if (widget.isSelected) {
      dayColor = kMint;
    } else if (widget.isSun) {
      dayColor = const Color(0xFFFF1744);
    } else if (widget.isSat) {
      dayColor = kTeal;
    } else if (widget.isToday) {
      dayColor = kText;
    } else {
      dayColor = kDim;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? kMint.withValues(alpha: 0.10)
                : _hovered
                    ? kSurface
                    : Colors.transparent,
          ),
          alignment: Alignment.center,
          // FittedBox guarantees the cell content never overflows the fixed
          // grid cell height, regardless of the user's font-size setting.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.day.toString(),
                  style: mono(
                    color: dayColor,
                    fontSize: widget.isSelected || widget.isToday ? 13 : 12,
                    fontWeight: widget.isToday
                        ? FontWeight.bold
                        : FontWeight.normal,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                // Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.hasMemo)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: kMint.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (widget.hasReminder)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          '!',
                          style: mono(
                            color: Colors.amber.shade600
                                .withValues(alpha: 0.9),
                            fontSize: 9,
                            height: 1.1,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Scroll picker dialog (year / month)
// ─────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────
// Navigation button  [◀] / [▶]
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
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered
                ? kMint.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Text(widget.label,
              style: mono(color: _hovered ? kMint : kDim, fontSize: 11)),
        ),
      ),
    );
  }
}
