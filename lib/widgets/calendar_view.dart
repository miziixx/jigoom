import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/memo.dart';
import '../models/folder.dart';
import 'memo_tile.dart';
import 'input_bar.dart';


// Wide layout threshold: side-by-side calendar + day panel
const _kWide = 620.0;

class CalendarView extends StatefulWidget {
  final List<Memo> memos;
  final void Function(Memo) onDelete;
  final void Function(String, String) onUpdate;
  final void Function(Memo, String?) onMove;
  final void Function(Memo, DateTime?) onSetReminder;
  final void Function(String content, DateTime date, bool isChecklist, DateTime? reminderAt, List<String> imagePaths) onAddMemo;
  final void Function(Memo memo, String content) onAddNote;
  final void Function(Memo memo, int index, String content) onUpdateNote;
  final void Function(Memo memo, int index) onDeleteNote;
  final List<Folder> folders;
  final String? highlightedMemoId;

  const CalendarView({
    super.key,
    required this.memos,
    required this.onDelete,
    required this.onUpdate,
    required this.onMove,
    required this.onSetReminder,
    required this.onAddMemo,
    required this.onAddNote,
    required this.onUpdateNote,
    required this.onDeleteNote,
    required this.folders,
    this.highlightedMemoId,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late int _year;
  late int _month;
  late DateTime _selectedDay;

  static const _cellH = 38.0;

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
    return LayoutBuilder(builder: (context, constraints) {
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
      return Column(
        children: [
          _buildCalendarPanel(),
          Expanded(child: _buildDayPanel()),
        ],
      );
    });
  }

  // ── Calendar grid panel ───────────────────────────────────────

  Widget _buildCalendarPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMonthHeader(),
        _buildWeekdayRow(),
        _buildGrid(),
      ],
    );
  }

  Widget _buildMonthHeader() {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final now = DateTime.now();
    final isCurrentMonth = _year == now.year && _month == now.month;

    return Container(
      color: kBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _NavBtn(label: '[<]', onTap: _prevMonth),
          const Spacer(),
          GestureDetector(
            onTap: _goToday,
            child: Text(
              '$_year . ${months[_month - 1]}',
              style: mono(
                color: isCurrentMonth ? kMint : kText,
                fontSize: 13,
                letterSpacing: 2,
                fontWeight: isCurrentMonth ? FontWeight.bold : FontWeight.normal,
              ),
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
    final totalCells  = offset + daysInMonth;
    final rows        = (totalCells / 7).ceil();

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
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: memos.length,
                  itemBuilder: (_, i) {
                    final memo = memos[i];
                    return MemoTile(
                      memo:           memo,
                      onDelete:       () => widget.onDelete(memo),
                      onUpdate:       (c) => widget.onUpdate(memo.id, c),
                      onMove:         (fid) => widget.onMove(memo, fid),
                      onSetReminder:  (dt) => widget.onSetReminder(memo, dt),
                      onAddNote:      (c) => widget.onAddNote(memo, c),
                      onUpdateNote:   (idx, c) => widget.onUpdateNote(memo, idx, c),
                      onDeleteNote:   (idx) => widget.onDeleteNote(memo, idx),
                      folders:        widget.folders,
                      highlighted:    widget.highlightedMemoId == memo.id,
                    );
                  },
                ),
        ),
        // Input bar — saves memo to selected day's date
        InputBar(
          initialDate: _selectedDay,
          onSubmit: (content, isChecklist, reminderAt, _, imgs) =>
              widget.onAddMemo(content, _selectedDay, isChecklist, reminderAt, imgs),
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
          child: Column(
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
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
