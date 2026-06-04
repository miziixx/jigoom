import 'dart:async';
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
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => _ScheduleSheet(
        current: current,
        initialDate: initialDate,
        currentRepeat: currentRepeat,
        onResult: onResult,
        scrollController: scrollCtrl,
      ),
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
  final ScrollController? scrollController;

  const _ScheduleSheet({
    this.current,
    this.initialDate,
    this.currentRepeat = 'none',
    required this.onResult,
    this.scrollController,
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
  }

  @override
  void dispose() {
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

  void _selectQuick(int daysFromNow) {
    final d = DateTime.now().add(Duration(days: daysFromNow));
    setState(() {
      _calYear  = d.year;
      _calMonth = d.month;
      _selDay   = d.day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSet  = _selDay != null;
    final repeatOn = _repeatCount > 0;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        color: kSurface,
        child: SafeArea(
          child: Column(
            children: [
              Container(height: 2, color: kMint),
              Expanded(
                child: SingleChildScrollView(
                  controller: widget.scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      // ── DATE ─────────────────────────────
                      _SectionHeader(title: 'DATE'),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            _PillBtn(label: '오늘',   onTap: () => _selectQuick(0)),
                            const SizedBox(width: 8),
                            _PillBtn(label: '내일',   onTap: () => _selectQuick(1)),
                            const SizedBox(width: 8),
                            _PillBtn(label: '다음주', onTap: () => _selectQuick(7)),
                            if (widget.current != null) ...[
                              const Spacer(),
                              _PillBtn(label: '일정취소', danger: true, onTap: _clear),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onHorizontalDragEnd: (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (v < -200) _nextMonth();
                          else if (v > 200) _prevMonth();
                        },
                        child: _MiniCalendar(
                          year: _calYear, month: _calMonth,
                          selectedDay: _selDay,
                          onDayTap: (d) => setState(() => _selDay = d),
                          onPrev: _prevMonth, onNext: _nextMonth,
                          onYearTap: _pickYear, onMonthTap: _pickMonth,
                        ),
                      ),

                      // ── TIME ─────────────────────────────
                      _SectionHeader(title: 'TIME'),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                        child: Column(
                          children: [
                            Text(
                              'time_input  ·  키보드 없이 조작',
                              style: mono(color: kDim.withValues(alpha: 0.4), fontSize: 11),
                            ),
                            const SizedBox(height: 12),
                            // + 버튼 행
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _TimeBtn(
                                  label: '+',
                                  tapStep: 1, holdStep: 1,
                                  onStep: (s) => setState(() => _hour = (_hour + s + 24) % 24),
                                ),
                                const SizedBox(width: 60),
                                _TimeBtn(
                                  label: '+',
                                  tapStep: 5, holdStep: 1,
                                  onStep: (s) => setState(() => _minute = (_minute + s + 60) % 60),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // 시간 표시
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _hour.toString().padLeft(2, '0'),
                                  style: mono(color: kMint, fontSize: 42, fontWeight: FontWeight.bold),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(':', style: mono(color: kDim, fontSize: 36)),
                                ),
                                Text(
                                  _minute.toString().padLeft(2, '0'),
                                  style: mono(color: kMint, fontSize: 42, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // - 버튼 행
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _TimeBtn(
                                  label: '−',
                                  tapStep: -1, holdStep: -1,
                                  onStep: (s) => setState(() => _hour = (_hour + s + 24) % 24),
                                ),
                                const SizedBox(width: 60),
                                _TimeBtn(
                                  label: '−',
                                  tapStep: -5, holdStep: -1,
                                  onStep: (s) => setState(() => _minute = (_minute + s + 60) % 60),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '분 단위 : 5분씩  ·  길게 누르면 1분씩',
                              style: mono(color: kDim.withValues(alpha: 0.35), fontSize: 10),
                            ),
                          ],
                        ),
                      ),

                      // ── REPEAT ───────────────────────────
                      _SectionHeader(title: 'REPEAT'),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('반복', style: mono(color: kDim, fontSize: 12)),
                                const Spacer(),
                                _SegBtn(label: 'OFF', selected: !repeatOn,
                                    onTap: () => setState(() => _repeatCount = 0)),
                                const SizedBox(width: 8),
                                _SegBtn(label: 'ON', selected: repeatOn,
                                    onTap: () => setState(() { if (!repeatOn) _repeatCount = 1; })),
                              ],
                            ),
                            if (repeatOn) ...[
                              const SizedBox(height: 12),
                              // 반복 횟수
                              Row(
                                children: [
                                  _TimeBtn(
                                    label: '−', tapStep: -1, holdStep: -1,
                                    onStep: (s) => setState(() {
                                      _repeatCount = (_repeatCount + s).clamp(1, 99);
                                    }),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('$_repeatCount',
                                        style: mono(color: kMint, fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                                  _TimeBtn(
                                    label: '+', tapStep: 1, holdStep: 1,
                                    onStep: (s) => setState(() {
                                      _repeatCount = (_repeatCount + s).clamp(1, 99);
                                    }),
                                  ),
                                  const SizedBox(width: 20),
                                  ...List.generate(_kUnits.length, (i) => GestureDetector(
                                    onTap: () => setState(() => _repeatUnitIdx = i),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 80),
                                      width: 40,
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _repeatUnitIdx == i
                                            ? kMint.withValues(alpha: 0.1) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _repeatUnitIdx == i ? kMint : kBorder,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(_kUnits[i], style: mono(
                                        color: _repeatUnitIdx == i ? kMint : kDim.withValues(alpha: 0.5),
                                        fontSize: 12,
                                      )),
                                    ),
                                  )),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      // ── 액션 ─────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _PillBtn(label: '[취소]', onTap: () => Navigator.pop(context)),
                            const SizedBox(width: 8),
                            _PillBtn(
                              label: '[확인]',
                              active: canSet,
                              onTap: canSet ? _confirm : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
  final double fontSize;

  const _MiniCalendar({
    required this.year,
    required this.month,
    required this.selectedDay,
    required this.onDayTap,
    required this.onPrev,
    required this.onNext,
    this.onYearTap,
    this.onMonthTap,
    this.fontSize = 12,
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
                  style: mono(color: kMint, fontSize: fontSize, letterSpacing: 0.5),
                ),
              ),
              Text(' . ',
                  style: mono(color: kBorder, fontSize: fontSize)),
              GestureDetector(
                onTap: onMonthTap,
                child: Text(
                  month.toString().padLeft(2, '0'),
                  style: mono(color: kMint, fontSize: fontSize, letterSpacing: 0.5),
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
                child: Center(child: Text(_wd[i], style: mono(color: c, fontSize: fontSize - 3))),
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
                        fontSize: isSelected || isToday ? fontSize : fontSize - 1,
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
// Small widgets
// ──────────────────────────────────────────────────────────────

/// 섹션 헤더 (- - - TITLE - - -)
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashedLine(),
          const SizedBox(height: 4),
          Text(title, style: mono(color: kText, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          _DashedLine(),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final n = (c.maxWidth / 7).floor();
      return Text(
        List.filled(n, '-').join(' '),
        style: mono(color: kBorder.withValues(alpha: 0.7), fontSize: 10),
        overflow: TextOverflow.clip,
        maxLines: 1,
      );
    });
  }
}

/// 라운드 테두리 버튼 (오늘/내일/다음주/[취소]/[확인])
class _PillBtn extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final bool active; // 확인 버튼 활성화 여부
  const _PillBtn({required this.label, this.onTap, this.danger = false, this.active = true});

  @override
  State<_PillBtn> createState() => _PillBtnState();
}

class _PillBtnState extends State<_PillBtn> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && widget.active;
    final color = widget.danger
        ? Colors.red.shade400
        : enabled ? kDim : kDim.withValues(alpha: 0.3);
    return GestureDetector(
      onTap: enabled ? widget.onTap : null,
      onTapDown: (_) { if (enabled) setState(() => _pressing = true); },
      onTapUp: (_) => setState(() => _pressing = false),
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _pressing ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _pressing ? color : color.withValues(alpha: 0.5)),
        ),
        child: Text(widget.label, style: mono(color: color, fontSize: 12)),
      ),
    );
  }
}

/// +/- 버튼 (탭 = tapStep, 홀드 = holdStep 가속)
class _TimeBtn extends StatefulWidget {
  final String label;
  final int tapStep;
  final int holdStep;
  final void Function(int step) onStep;
  const _TimeBtn({
    required this.label,
    required this.tapStep,
    required this.holdStep,
    required this.onStep,
  });

  @override
  State<_TimeBtn> createState() => _TimeBtnState();
}

class _TimeBtnState extends State<_TimeBtn> {
  Timer? _timer;
  int _ticks = 0;
  bool _holding = false;

  void _start() {
    widget.onStep(widget.tapStep);
    _ticks = 0;
    _holding = false;
    _timer = Timer(const Duration(milliseconds: 400), _repeat);
  }

  void _repeat() {
    if (!mounted) return;
    _holding = true;
    widget.onStep(widget.holdStep);
    _ticks++;
    final ms = _ticks < 8 ? 120 : _ticks < 20 ? 70 : 35;
    _timer = Timer(Duration(milliseconds: ms), _repeat);
  }

  void _stop() { _timer?.cancel(); _timer = null; }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _stop(),
      onTapCancel: () => _stop(),
      child: Container(
        width: 56, height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: mono(color: kDim.withValues(alpha: 0.6), fontSize: 18),
        ),
      ),
    );
  }
}

/// OFF/ON 세그먼트 버튼
class _SegBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kMint.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? kMint : kBorder),
        ),
        child: Text(
          label,
          style: mono(
            color: selected ? kMint : kDim.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _CalNavBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _CalNavBtn({required this.label, required this.onTap});

  @override
  State<_CalNavBtn> createState() => _CalNavBtnState();
}

class _CalNavBtnState extends State<_CalNavBtn> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) => setState(() => _pressing = false),
      onTapCancel: () => setState(() => _pressing = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(widget.label,
            style: mono(color: _pressing ? kMint : kDim, fontSize: 12)),
      ),
    );
  }
}
