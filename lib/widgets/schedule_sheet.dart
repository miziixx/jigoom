import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import 'scroll_picker_dialog.dart';

// ──────────────────────────────────────────────────────────────
// Public helper
// ──────────────────────────────────────────────────────────────

Future<void> showScheduleSheet(
  BuildContext context, {
  DateTime? current,
  DateTime? initialDate,
  String currentRepeat = 'none',
  required void Function(DateTime?, String repeat) onResult,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: kSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (_) => _ScheduleSheet(
      current: current,
      initialDate: initialDate,
      currentRepeat: currentRepeat,
      onResult: onResult,
    ),
  );
}

// ──────────────────────────────────────────────────────────────
// Sheet
// ──────────────────────────────────────────────────────────────

class _ScheduleSheet extends StatefulWidget {
  final DateTime? current;
  final DateTime? initialDate;
  final String currentRepeat;
  final void Function(DateTime?, String repeat) onResult;

  const _ScheduleSheet({
    this.current,
    this.initialDate,
    this.currentRepeat = 'none',
    required this.onResult,
  });

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

const _kUnits = ['시', '일', '주', '월', '년'];

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late int _calYear, _calMonth;
  int? _selDay;
  late int _hour, _minute;
  int _repeatCount = 0;
  int _repeatUnitIdx = 1; // default: 일
  late final TextEditingController _repeatCtrl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final ref = widget.current ?? widget.initialDate ?? now;
    _calYear  = ref.year;
    _calMonth = ref.month;
    if (widget.current != null) {
      _selDay = widget.current!.day;
      _hour   = widget.current!.hour;
      _minute = widget.current!.minute;
    } else {
      _selDay = widget.initialDate?.day;
      _hour   = now.hour;
      _minute = now.minute;
    }
    // Convert old repeat format
    switch (widget.currentRepeat) {
      case 'daily':
        _repeatCount = 1; _repeatUnitIdx = 1;
      case 'weekly':
        _repeatCount = 1; _repeatUnitIdx = 2;
      case 'monthly':
        _repeatCount = 1; _repeatUnitIdx = 3;
      default:
        _repeatCount = 0; _repeatUnitIdx = 1;
    }
    _repeatCtrl = TextEditingController(
      text: _repeatCount > 0 ? '$_repeatCount' : '',
    );
  }

  @override
  void dispose() {
    _repeatCtrl.dispose();
    super.dispose();
  }

  String _repeatString() {
    if (_repeatCount <= 0) return 'none';
    final unit = _kUnits[_repeatUnitIdx];
    if (unit == '일') return 'daily';
    if (unit == '주') return 'weekly';
    if (unit == '월') return 'monthly';
    return 'none';
  }

  void _confirm() {
    if (_selDay == null) return;
    DateTime dt;
    try {
      dt = DateTime(_calYear, _calMonth, _selDay!, _hour, _minute);
    } catch (_) { return; }
    Navigator.pop(context);
    widget.onResult(dt, _repeatString());
  }

  void _clear() {
    Navigator.pop(context);
    widget.onResult(null, 'none');
  }

  void _prevMonth() => setState(() {
    if (_calMonth == 1) { _calMonth = 12; _calYear--; }
    else { _calMonth--; }
  });

  void _nextMonth() => setState(() {
    if (_calMonth == 12) { _calMonth = 1; _calYear++; }
    else { _calMonth++; }
  });

  Future<void> _pickYear() async {
    final years = List.generate(111, (i) => 1990 + i);
    final r = await showScrollPicker(
      context: context,
      values: years,
      labels: years.map((y) => '$y').toList(),
      initialValue: _calYear,
    );
    if (r != null && mounted) setState(() => _calYear = r);
  }

  Future<void> _pickMonth() async {
    final months = List.generate(12, (i) => i + 1);
    final r = await showScrollPicker(
      context: context,
      values: months,
      labels: months.map((m) => m.toString().padLeft(2, '0')).toList(),
      initialValue: _calMonth,
    );
    if (r != null && mounted) setState(() => _calMonth = r);
  }

  @override
  Widget build(BuildContext context) {
    final canSet = _selDay != null;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 2, color: kMint),

          // ── Mini calendar ─────────────────────────
          GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -200) _nextMonth();
              else if (v > 200) _prevMonth();
            },
            child: _MiniCalendar(
              year: _calYear,
              month: _calMonth,
              selectedDay: _selDay,
              onDayTap: (d) => setState(() => _selDay = d),
              onPrev: _prevMonth,
              onNext: _nextMonth,
              onYearTap: _pickYear,
              onMonthTap: _pickMonth,
            ),
          ),

          Container(height: 1, color: kBorder.withValues(alpha: 0.4)),

          // ── Time + Repeat ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text('time',
                          style: mono(color: kDim.withValues(alpha: 0.55), fontSize: 11)),
                    ),
                    _SmallTimeField(
                      value: _hour, min: 0, max: 23,
                      onChanged: (v) => setState(() => _hour = v),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(':',
                          style: mono(color: kDim.withValues(alpha: 0.55), fontSize: 12)),
                    ),
                    _SmallTimeField(
                      value: _minute, min: 0, max: 59,
                      onChanged: (v) => setState(() => _minute = v),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Repeat row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text('반복',
                          style: mono(color: kDim.withValues(alpha: 0.55), fontSize: 11)),
                    ),
                    _RepeatCountField(
                      controller: _repeatCtrl,
                      onChanged: (v) {
                        final n = int.tryParse(v) ?? 0;
                        setState(() => _repeatCount = n < 0 ? 0 : n);
                      },
                    ),
                    const SizedBox(width: 4),
                    ...List.generate(_kUnits.length, (i) => GestureDetector(
                      onTap: () => setState(() => _repeatUnitIdx = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        width: 34,
                        margin: const EdgeInsets.only(left: 2),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: _repeatUnitIdx == i
                              ? kMint.withValues(alpha: 0.10)
                              : kBg,
                          border: Border.all(
                            color: _repeatUnitIdx == i
                                ? kMint
                                : kBorder,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _kUnits[i],
                          style: mono(
                            color: _repeatUnitIdx == i ? kMint : kDim,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )),
                  ],
                ),
              ],
            ),
          ),

          Container(height: 1, color: kBorder),

          // ── Actions ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                if (widget.current != null)
                  _ActionBtn(
                    label: '[ 알림 취소 ]',
                    color: Colors.red.shade400,
                    onTap: _clear,
                  ),
                const Spacer(),
                _ActionBtn(
                  label: '[ CANCEL ]',
                  color: kDim,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                _ActionBtn(
                  label: '[ SET ]',
                  color: canSet ? kMint : kDim.withValues(alpha: 0.35),
                  onTap: canSet ? _confirm : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Mini calendar
// ──────────────────────────────────────────────────────────────

class _MiniCalendar extends StatelessWidget {
  final int year, month;
  final int? selectedDay;
  final void Function(int) onDayTap;
  final VoidCallback onPrev, onNext;
  final VoidCallback? onYearTap, onMonthTap;

  const _MiniCalendar({
    required this.year,
    required this.month,
    required this.selectedDay,
    required this.onDayTap,
    required this.onPrev,
    required this.onNext,
    this.onYearTap,
    this.onMonthTap,
  });

  static const _wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final now          = DateTime.now();
    final firstDay    = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final offset      = firstDay.weekday - 1;
    const rows        = 6;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        children: [
          // Month nav row
          Row(
            children: [
              _CalNavBtn(label: '[<]', onTap: onPrev),
              const Spacer(),
              GestureDetector(
                onTap: onYearTap,
                child: Text(
                  '$year',
                  style: mono(color: kMint, fontSize: 12, letterSpacing: 0.5),
                ),
              ),
              Text(' . ',
                  style: mono(color: kBorder, fontSize: 12)),
              GestureDetector(
                onTap: onMonthTap,
                child: Text(
                  month.toString().padLeft(2, '0'),
                  style: mono(color: kMint, fontSize: 12, letterSpacing: 0.5),
                ),
              ),
              const Spacer(),
              _CalNavBtn(label: '[>]', onTap: onNext),
            ],
          ),
          const SizedBox(height: 4),
          // Weekday labels
          Row(
            children: List.generate(7, (i) {
              final c = i == 6
                  ? const Color(0xFFFF1744).withValues(alpha: 0.7)
                  : i == 5
                      ? kTeal.withValues(alpha: 0.7)
                      : kDim.withValues(alpha: 0.4);
              return Expanded(
                child: Center(child: Text(_wd[i], style: mono(color: c, fontSize: 9))),
              );
            }),
          ),
          const SizedBox(height: 2),
          ...List.generate(rows, (row) => Row(
            children: List.generate(7, (col) {
              final dayNum = row * 7 + col - offset + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox(height: 30));
              }
              final date       = DateTime(year, month, dayNum);
              final isToday    = date.year == now.year && date.month == now.month && date.day == now.day;
              final isSelected = dayNum == selectedDay;
              final isPast     = date.isBefore(DateTime(now.year, now.month, now.day));
              final isSun      = col == 6;
              final isSat      = col == 5;

              Color fg;
              if (isSelected)   fg = kBg;
              else if (isPast)  fg = kDim.withValues(alpha: 0.25);
              else if (isSun)   fg = const Color(0xFFFF1744).withValues(alpha: 0.8);
              else if (isSat)   fg = kTeal.withValues(alpha: 0.8);
              else if (isToday) fg = kMint;
              else              fg = kDim;

              return Expanded(
                child: GestureDetector(
                  onTap: isPast ? null : () => onDayTap(dayNum),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    height: 30,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? kMint
                          : isToday ? kMint.withValues(alpha: 0.1) : Colors.transparent,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNum',
                      style: mono(
                        color: fg,
                        fontSize: isSelected || isToday ? 11 : 10,
                        fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }),
          )),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Small time field (compact)
// ──────────────────────────────────────────────────────────────

class _SmallTimeField extends StatefulWidget {
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const _SmallTimeField({
    required this.value, required this.min,
    required this.max, required this.onChanged,
  });

  @override
  State<_SmallTimeField> createState() => _SmallTimeFieldState();
}

class _SmallTimeFieldState extends State<_SmallTimeField> {
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl  = TextEditingController(text: _fmt(widget.value));
    _focus = FocusNode();
    _focus.addListener(() { if (!_focus.hasFocus) _commit(); });
  }

  @override
  void didUpdateWidget(_SmallTimeField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_focus.hasFocus) {
      _ctrl.text = _fmt(widget.value);
    }
  }

  String _fmt(int v) => v.toString().padLeft(2, '0');

  void _commit() {
    final v = int.tryParse(_ctrl.text);
    if (v == null) { _ctrl.text = _fmt(widget.value); return; }
    final c = v.clamp(widget.min, widget.max);
    _ctrl.text = _fmt(c);
    widget.onChanged(c);
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _focus,
      builder: (_, __) => Container(
        width: 36,
        decoration: BoxDecoration(
          color: kBg,
          border: Border.all(
            color: _focus.hasFocus ? kMint : kBorder,
            width: _focus.hasFocus ? 1.5 : 1.0,
          ),
        ),
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 2,
          textAlign: TextAlign.center,
          style: mono(color: kDim, fontSize: 12),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 7),
          ),
          onSubmitted: (_) => _commit(),
          onTapOutside: (_) => _focus.unfocus(),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Repeat count field
// ──────────────────────────────────────────────────────────────

class _RepeatCountField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _RepeatCountField({required this.controller, required this.onChanged});

  @override
  State<_RepeatCountField> createState() => _RepeatCountFieldState();
}

class _RepeatCountFieldState extends State<_RepeatCountField> {
  final _focus = FocusNode();

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _focus,
      builder: (_, __) => Container(
        width: 36,
        decoration: BoxDecoration(
          color: kBg,
          border: Border.all(
            color: _focus.hasFocus ? kMint : kBorder,
            width: _focus.hasFocus ? 1.5 : 1.0,
          ),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 3,
          textAlign: TextAlign.center,
          style: mono(color: kDim, fontSize: 12),
          decoration: InputDecoration(
            counterText: '',
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 7),
            hintText: '0',
            hintStyle: mono(color: kDim.withValues(alpha: 0.35), fontSize: 12),
          ),
          onChanged: widget.onChanged,
          onTapOutside: (_) => _focus.unfocus(),
        ),
      ),
    );
  }
}


// ──────────────────────────────────────────────────────────────
// Small widgets
// ──────────────────────────────────────────────────────────────

class _CalNavBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _CalNavBtn({required this.label, required this.onTap});

  @override
  State<_CalNavBtn> createState() => _CalNavBtnState();
}

class _CalNavBtnState extends State<_CalNavBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(widget.label,
              style: mono(color: _hovered ? kMint : kDim, fontSize: 11)),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionBtn({required this.label, required this.color, this.onTap});

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null;
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active && _hovered
                ? widget.color.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Text(widget.label,
              style: mono(color: widget.color, fontSize: 11)),
        ),
      ),
    );
  }
}
