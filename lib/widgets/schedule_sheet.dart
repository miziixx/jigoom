import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'scroll_picker_dialog.dart';

// ──────────────────────────────────────────────────────────────
// Mode
// ──────────────────────────────────────────────────────────────

enum ScheduleSheetMode {
  event,    // 일정: 날짜 범위 + scheduleRepeat
  reminder, // 알림: 단일 시각 + reminderRepeat
}

// ──────────────────────────────────────────────────────────────
// Public helper
// ──────────────────────────────────────────────────────────────

Future<void> showScheduleSheet(
  BuildContext context, {
  ScheduleSheetMode mode = ScheduleSheetMode.event,
  DateTime? current,
  DateTime? rangeEndDate,
  String currentRepeat = 'none',
  String repeatEndType = 'infinite',
  int repeatEndCount = 5,
  DateTime? repeatEndDate,
  bool initialNotifyForEvent = false,
  required void Function(
    DateTime? dt,
    String repeat,
    DateTime? rangeEndDate,
    String repeatEndType,
    int repeatEndCount,
    DateTime? repeatEndDate,
    bool notifyForEvent,
  ) onResult,
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
        mode: mode,
        current: current,
        rangeEndDate: rangeEndDate,
        currentRepeat: currentRepeat,
        repeatEndType: repeatEndType,
        repeatEndCount: repeatEndCount,
        repeatEndDate: repeatEndDate,
        initialNotifyForEvent: initialNotifyForEvent,
        onResult: onResult,
        scrollController: scrollCtrl,
      ),
    ),
  );
}

// ──────────────────────────────────────────────────────────────
// Internal enums
// ──────────────────────────────────────────────────────────────

enum _DateMode { single, range }

enum _RepeatUnit { daily, weekly, monthly, yearly }

enum _RepeatEndMode { infinite, count, date }

// Calendar tap target (which state a day-tap modifies)
enum _CalTarget { eventDate, repeatEndDate }

// ──────────────────────────────────────────────────────────────
// Sheet widget
// ──────────────────────────────────────────────────────────────

class _ScheduleSheet extends StatefulWidget {
  final ScheduleSheetMode mode;
  final DateTime? current;
  final DateTime? rangeEndDate;
  final String currentRepeat;
  final String repeatEndType;
  final int repeatEndCount;
  final DateTime? repeatEndDate;
  final bool initialNotifyForEvent;
  final void Function(
    DateTime?,
    String,
    DateTime?,
    String,
    int,
    DateTime?,
    bool,
  ) onResult;
  final ScrollController? scrollController;

  const _ScheduleSheet({
    required this.mode,
    this.current,
    this.rangeEndDate,
    this.currentRepeat = 'none',
    this.repeatEndType = 'infinite',
    this.repeatEndCount = 5,
    this.repeatEndDate,
    this.initialNotifyForEvent = false,
    required this.onResult,
    this.scrollController,
  });

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  // ── Calendar navigation ──────────────────────────────────────
  late int _calYear, _calMonth;

  // ── Date mode (event only) ───────────────────────────────────
  late _DateMode _dateMode;

  // Single mode
  int? _selDay;

  // Range mode
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _pickingRangeEnd = false; // false = picking start, true = picking end

  // ── Time ────────────────────────────────────────────────────
  late int _hour, _minute;

  // ── Repeat ──────────────────────────────────────────────────
  _RepeatUnit? _repeatUnit; // null = OFF
  final Set<int> _weekdays = {}; // 1=Mon … 7=Sun (weekly only)

  // ── Repeat end ──────────────────────────────────────────────
  late _RepeatEndMode _repeatEndMode;
  late int _repeatEndCount;
  DateTime? _repeatEndDateVal;
  bool? _notifyForEvent;

  bool get _notifyForEventOn => _notifyForEvent ?? false;

  // Which state a calendar day-tap modifies
  _CalTarget _calTarget = _CalTarget.eventDate;

  // ── Init ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final ref = widget.current ?? now;

    _calYear  = ref.year;
    _calMonth = ref.month;

    // Date mode (event only; reminder always single)
    _dateMode = widget.mode == ScheduleSheetMode.event && widget.rangeEndDate != null
        ? _DateMode.range
        : _DateMode.single;

    if (widget.current != null) {
      _selDay = widget.current!.day;
      _hour   = widget.current!.hour;
      _minute = widget.current!.minute;
    } else {
      _selDay = null;
      _hour   = now.hour;
      _minute = now.minute;
    }

    // Range
    if (_dateMode == _DateMode.range) {
      _rangeStart = widget.current;
      _rangeEnd   = widget.rangeEndDate;
    }

    // Repeat unit
    _repeatUnit = _parseRepeatUnit(widget.currentRepeat);

    // Repeat end
    switch (widget.repeatEndType) {
      case 'count':
        _repeatEndMode = _RepeatEndMode.count;
      case 'date':
        _repeatEndMode = _RepeatEndMode.date;
      default:
        _repeatEndMode = _RepeatEndMode.infinite;
    }
    _repeatEndCount  = widget.repeatEndCount;
    _repeatEndDateVal = widget.repeatEndDate;
    _notifyForEvent = widget.mode == ScheduleSheetMode.event &&
        widget.initialNotifyForEvent;
  }

  // ── Helpers ─────────────────────────────────────────────────

  _RepeatUnit? _parseRepeatUnit(String s) {
    switch (s) {
      case 'daily':   return _RepeatUnit.daily;
      case 'weekly':  return _RepeatUnit.weekly;
      case 'monthly': return _RepeatUnit.monthly;
      case 'yearly':  return _RepeatUnit.yearly;
      default:        return null;
    }
  }

  String _repeatString() {
    switch (_repeatUnit) {
      case _RepeatUnit.daily:   return 'daily';
      case _RepeatUnit.weekly:  return 'weekly';
      case _RepeatUnit.monthly: return 'monthly';
      case _RepeatUnit.yearly:  return 'yearly';
      case null:                return 'none';
    }
  }

  String _repeatEndTypeString() {
    switch (_repeatEndMode) {
      case _RepeatEndMode.count: return 'count';
      case _RepeatEndMode.date:  return 'date';
      case _RepeatEndMode.infinite: return 'infinite';
    }
  }

  // ── Calendar actions ─────────────────────────────────────────

  void _onDayTap(int day) {
    if (_calTarget == _CalTarget.repeatEndDate) {
      // Tapping sets the repeat-end date
      setState(() {
        _repeatEndDateVal = DateTime(_calYear, _calMonth, day);
      });
      return;
    }

    if (_dateMode == _DateMode.single) {
      setState(() => _selDay = day);
      return;
    }

    // Range mode
    final tapped = DateTime(_calYear, _calMonth, day);
    setState(() {
      if (!_pickingRangeEnd) {
        _rangeStart = tapped;
        _rangeEnd   = null;
        _pickingRangeEnd = true;
      } else {
        if (tapped.isBefore(_rangeStart!)) {
          _rangeEnd   = _rangeStart;
          _rangeStart = tapped;
        } else {
          _rangeEnd = tapped;
        }
        _pickingRangeEnd = false;
      }
      // Keep _selDay in sync with range start for confirm logic
      _selDay = _rangeStart?.day;
      if (_rangeStart != null) {
        _calYear  = _rangeStart!.year;
        _calMonth = _rangeStart!.month;
      }
    });
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
      if (_dateMode == _DateMode.single) {
        _selDay = d.day;
      } else {
        _rangeStart      = d;
        _rangeEnd        = null;
        _pickingRangeEnd = true;
        _selDay          = d.day;
      }
    });
  }

  // ── Confirm / Clear ─────────────────────────────────────────

  void _confirm() {
    DateTime? dt;
    DateTime? rangeEnd;

    if (_dateMode == _DateMode.single) {
      if (_selDay == null) return;
      try {
        dt = DateTime(_calYear, _calMonth, _selDay!, _hour, _minute);
      } catch (_) { return; }
    } else {
      if (_rangeStart == null) return;
      try {
        dt = DateTime(
          _rangeStart!.year, _rangeStart!.month, _rangeStart!.day,
          _hour, _minute,
        );
        if (_rangeEnd != null) {
          rangeEnd = DateTime(
            _rangeEnd!.year, _rangeEnd!.month, _rangeEnd!.day,
            _hour, _minute,
          );
        }
      } catch (_) { return; }
    }

    Navigator.pop(context);
    widget.onResult(
      dt,
      _repeatString(),
      widget.mode == ScheduleSheetMode.event ? rangeEnd : null,
      _repeatEndTypeString(),
      _repeatEndCount,
      _repeatEndMode == _RepeatEndMode.date ? _repeatEndDateVal : null,
      widget.mode == ScheduleSheetMode.event && _notifyForEventOn,
    );
  }

  void _clear() {
    Navigator.pop(context);
    widget.onResult(null, 'none', null, 'infinite', 5, null, false);
  }

  // ── Build ───────────────────────────────────────────────────

  bool get _canConfirm {
    if (_dateMode == _DateMode.single) return _selDay != null;
    return _rangeStart != null;
  }

  bool get _repeatOn => _repeatUnit != null;

  @override
  Widget build(BuildContext context) {
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
                      _buildDateSection(),
                      _buildTimeSection(),
                      _buildRepeatSection(),
                      if (_repeatOn) _buildRepeatEndSection(),
                      _buildActions(),
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

  // ── DATE section ─────────────────────────────────────────────

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: 'DATE'),

        // Quick buttons + optional cancel
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
                _PillBtn(
                  label: widget.mode == ScheduleSheetMode.event ? '일정취소' : '알림취소',
                  danger: true,
                  onTap: _clear,
                ),
              ],
            ],
          ),
        ),

        // event only: single | range toggle
        if (widget.mode == ScheduleSheetMode.event)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                _SegBtn(
                  label: '단일',
                  selected: _dateMode == _DateMode.single,
                  onTap: () => setState(() {
                    _dateMode = _DateMode.single;
                    _calTarget = _CalTarget.eventDate;
                  }),
                ),
                const SizedBox(width: 8),
                _SegBtn(
                  label: '범위',
                  selected: _dateMode == _DateMode.range,
                  onTap: () => setState(() {
                    _dateMode        = _DateMode.range;
                    _rangeStart      = _selDay != null
                        ? DateTime(_calYear, _calMonth, _selDay!)
                        : null;
                    _rangeEnd        = null;
                    _pickingRangeEnd = _rangeStart != null;
                    _calTarget       = _CalTarget.eventDate;
                  }),
                ),
                if (_dateMode == _DateMode.range) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _pickingRangeEnd ? '종료일을 선택하세요' : '시작일을 선택하세요',
                      style: mono(color: kMint, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),

        // Range display
        if (widget.mode == ScheduleSheetMode.event && _dateMode == _DateMode.range)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              _rangeStart != null
                  ? '${_fmtDate(_rangeStart!)}  →  ${_rangeEnd != null ? _fmtDate(_rangeEnd!) : '종료일'}'
                  : '시작일  →  종료일',
              style: mono(color: kDim, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),

        if (widget.mode == ScheduleSheetMode.event)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _notifyForEvent = !_notifyForEventOn),
              child: Row(
                children: [
                  Text(
                    _notifyForEventOn ? '[✓]' : '[ ]',
                    style: mono(
                      color: _notifyForEventOn ? kMint : kDim,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '일정 시간에 알림 받기',
                      style: mono(color: kDim, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Calendar — highlight mode indicator when picking repeat-end
        if (_calTarget == _CalTarget.repeatEndDate)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              '반복 종료일 선택 중 — 날짜를 탭하세요',
              style: mono(color: kMint.withValues(alpha: 0.8), fontSize: 10),
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
            selectedDay: _dateMode == _DateMode.single ? _selDay : null,
            rangeStart: _dateMode == _DateMode.range ? _rangeStart : null,
            rangeEnd:   _dateMode == _DateMode.range ? _rangeEnd   : null,
            repeatEndDate: _calTarget == _CalTarget.repeatEndDate ? _repeatEndDateVal : null,
            onDayTap: _onDayTap,
            onPrev: _prevMonth, onNext: _nextMonth,
            onYearTap: _pickYear, onMonthTap: _pickMonth,
          ),
        ),
      ],
    );
  }

  // ── TIME section ─────────────────────────────────────────────

  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: 'TIME'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
          child: Column(
            children: [
              Text(
                '키보드 없이 조작',
                style: mono(color: kDim.withValues(alpha: 0.4), fontSize: 11),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TimeBtn(label: '+', tapStep: 1, holdStep: 1,
                      onStep: (s) => setState(() => _hour = (_hour + s + 24) % 24)),
                  const SizedBox(width: 60),
                  _TimeBtn(label: '+', tapStep: 5, holdStep: 1,
                      onStep: (s) => setState(() => _minute = (_minute + s + 60) % 60)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_hour.toString().padLeft(2, '0'),
                      style: mono(color: kMint, fontSize: 42, fontWeight: FontWeight.bold)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(':', style: mono(color: kDim, fontSize: 36)),
                  ),
                  Text(_minute.toString().padLeft(2, '0'),
                      style: mono(color: kMint, fontSize: 42, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TimeBtn(label: '−', tapStep: -1, holdStep: -1,
                      onStep: (s) => setState(() => _hour = (_hour + s + 24) % 24)),
                  const SizedBox(width: 60),
                  _TimeBtn(label: '−', tapStep: -5, holdStep: -1,
                      onStep: (s) => setState(() => _minute = (_minute + s + 60) % 60)),
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
      ],
    );
  }

  // ── REPEAT section ───────────────────────────────────────────

  Widget _buildRepeatSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: 'REPEAT'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ON / OFF toggle
              Row(
                children: [
                  Text('반복', style: mono(color: kDim, fontSize: 12)),
                  const Spacer(),
                  _SegBtn(label: 'OFF', selected: !_repeatOn,
                      onTap: () => setState(() => _repeatUnit = null)),
                  const SizedBox(width: 8),
                  _SegBtn(label: 'ON', selected: _repeatOn,
                      onTap: () => setState(() => _repeatUnit ??= _RepeatUnit.daily)),
                ],
              ),

              if (_repeatOn) ...[
                const SizedBox(height: 12),

                // Repeat unit buttons — Wrap to prevent overflow
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _RepeatUnitBtn(
                      label: '매일',
                      selected: _repeatUnit == _RepeatUnit.daily,
                      onTap: () => setState(() {
                        _repeatUnit = _RepeatUnit.daily;
                        _weekdays.clear();
                      }),
                    ),
                    _RepeatUnitBtn(
                      label: '매주',
                      selected: _repeatUnit == _RepeatUnit.weekly,
                      onTap: () => setState(() => _repeatUnit = _RepeatUnit.weekly),
                    ),
                    _RepeatUnitBtn(
                      label: '매월',
                      selected: _repeatUnit == _RepeatUnit.monthly,
                      onTap: () => setState(() {
                        _repeatUnit = _RepeatUnit.monthly;
                        _weekdays.clear();
                      }),
                    ),
                    _RepeatUnitBtn(
                      label: '매년',
                      selected: _repeatUnit == _RepeatUnit.yearly,
                      onTap: () => setState(() {
                        _repeatUnit = _RepeatUnit.yearly;
                        _weekdays.clear();
                      }),
                    ),
                  ],
                ),

                // Weekday selector — visible only for weekly
                if (_repeatUnit == _RepeatUnit.weekly) ...[
                  const SizedBox(height: 12),
                  _WeekdayRow(
                    selected: _weekdays,
                    onToggle: (d) => setState(() {
                      if (_weekdays.contains(d)) _weekdays.remove(d);
                      else _weekdays.add(d);
                    }),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── REPEAT END section ───────────────────────────────────────

  Widget _buildRepeatEndSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: 'REPEAT END'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3-tab row
              Row(
                children: [
                  Expanded(
                    child: _SegBtn(
                      label: '무한',
                      selected: _repeatEndMode == _RepeatEndMode.infinite,
                      onTap: () => setState(() {
                        _repeatEndMode = _RepeatEndMode.infinite;
                        _calTarget     = _CalTarget.eventDate;
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _SegBtn(
                      label: 'N회',
                      selected: _repeatEndMode == _RepeatEndMode.count,
                      onTap: () => setState(() {
                        _repeatEndMode = _RepeatEndMode.count;
                        _calTarget     = _CalTarget.eventDate;
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _SegBtn(
                      label: '날짜까지',
                      selected: _repeatEndMode == _RepeatEndMode.date,
                      onTap: () => setState(() {
                        _repeatEndMode = _RepeatEndMode.date;
                        _calTarget     = _CalTarget.repeatEndDate;
                      }),
                    ),
                  ),
                ],
              ),

              // N회 controls
              if (_repeatEndMode == _RepeatEndMode.count) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TimeBtn(
                      label: '−', tapStep: -1, holdStep: -1,
                      onStep: (s) => setState(() {
                        _repeatEndCount = (_repeatEndCount + s).clamp(1, 999);
                      }),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$_repeatEndCount 회',
                        style: mono(color: kMint, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    _TimeBtn(
                      label: '+', tapStep: 1, holdStep: 1,
                      onStep: (s) => setState(() {
                        _repeatEndCount = (_repeatEndCount + s).clamp(1, 999);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'N회 종료는 현재 저장/표시만 지원합니다',
                    style: mono(color: kDim.withValues(alpha: 0.45), fontSize: 10),
                  ),
                ),
              ],

              // 날짜까지 controls
              if (_repeatEndMode == _RepeatEndMode.date) ...[
                const SizedBox(height: 10),
                Text(
                  '달력에서 날짜를 탭하면 반복 종료일로 설정됩니다',
                  style: mono(color: kDim, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Text(
                  _repeatEndDateVal != null
                      ? _fmtDate(_repeatEndDateVal!)
                      : '종료일 미설정',
                  style: mono(
                    color: _repeatEndDateVal != null ? kMint : kDim.withValues(alpha: 0.5),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '연간 반복 및 N회 종료의 실제 OS 알림 예약은 추후 지원 예정입니다',
                  style: mono(color: kDim.withValues(alpha: 0.35), fontSize: 10),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Actions row ──────────────────────────────────────────────

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _PillBtn(label: '[취소]', onTap: () => Navigator.pop(context)),
          const SizedBox(width: 8),
          _PillBtn(
            label: '[확인]',
            active: _canConfirm,
            onTap: _canConfirm ? _confirm : null,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

// ──────────────────────────────────────────────────────────────
// Mini calendar
// ──────────────────────────────────────────────────────────────

class _MiniCalendar extends StatelessWidget {
  final int year, month;
  final int? selectedDay;         // single mode
  final DateTime? rangeStart;     // range mode
  final DateTime? rangeEnd;       // range mode
  final DateTime? repeatEndDate;  // highlighted as repeat-end marker
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
    this.rangeStart,
    this.rangeEnd,
    this.repeatEndDate,
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
                child: Text('$year',
                    style: mono(color: kMint, fontSize: fontSize, letterSpacing: 0.5)),
              ),
              Text(' . ', style: mono(color: kBorder, fontSize: fontSize)),
              GestureDetector(
                onTap: onMonthTap,
                child: Text(month.toString().padLeft(2, '0'),
                    style: mono(color: kMint, fontSize: fontSize, letterSpacing: 0.5)),
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
                  : i == 5 ? kTeal.withValues(alpha: 0.7) : kDim.withValues(alpha: 0.4);
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
              final isPast     = date.isBefore(DateTime(now.year, now.month, now.day));
              final isSun      = col == 6;
              final isSat      = col == 5;

              // Single mode
              final isSelected = selectedDay == dayNum && rangeStart == null;

              // Range mode
              final isRangeStart = rangeStart != null &&
                  date.year == rangeStart!.year &&
                  date.month == rangeStart!.month &&
                  date.day == rangeStart!.day;
              final isRangeEnd = rangeEnd != null &&
                  date.year == rangeEnd!.year &&
                  date.month == rangeEnd!.month &&
                  date.day == rangeEnd!.day;
              final isInRange = rangeStart != null && rangeEnd != null &&
                  date.isAfter(rangeStart!) && date.isBefore(rangeEnd!);

              // Repeat-end marker
              final isRepeatEnd = repeatEndDate != null &&
                  date.year == repeatEndDate!.year &&
                  date.month == repeatEndDate!.month &&
                  date.day == repeatEndDate!.day;

              final isHighlighted = isSelected || isRangeStart || isRangeEnd;

              Color fg;
              if (isHighlighted)   fg = kBg;
              else if (isPast && !isRepeatEnd) fg = kDim.withValues(alpha: 0.25);
              else if (isSun)      fg = const Color(0xFFFF1744).withValues(alpha: 0.8);
              else if (isSat)      fg = kTeal.withValues(alpha: 0.8);
              else if (isToday)    fg = kMint;
              else                 fg = kDim;

              Color? bgColor;
              BorderRadius? borderRadius;
              if (isHighlighted) {
                bgColor = kMint;
                if (isRangeStart && rangeEnd != null) {
                  borderRadius = const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  );
                } else if (isRangeEnd) {
                  borderRadius = const BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  );
                }
              } else if (isInRange) {
                bgColor = kMint.withValues(alpha: 0.15);
              } else if (isToday) {
                bgColor = kMint.withValues(alpha: 0.1);
              } else if (isRepeatEnd) {
                bgColor = kTeal.withValues(alpha: 0.15);
                fg = kTeal;
              }

              return Expanded(
                child: GestureDetector(
                  onTap: () => onDayTap(dayNum),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    height: 30,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: borderRadius,
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: mono(
                            color: fg,
                            fontSize: isHighlighted || isToday ? fontSize : fontSize - 1,
                            fontWeight: isHighlighted || isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (isRepeatEnd)
                          Container(
                            width: 4, height: 4,
                            decoration: BoxDecoration(
                              color: kTeal,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
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

class _PillBtn extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final bool active;
  const _PillBtn({required this.label, this.onTap, this.danger = false, this.active = true});

  @override
  State<_PillBtn> createState() => _PillBtnState();
}

class _PillBtnState extends State<_PillBtn> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && widget.active;
    final color   = widget.danger
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

/// OFF/ON 세그먼트 버튼 (범용)
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

/// 반복 주기 버튼 (Wrap 내부)
class _RepeatUnitBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RepeatUnitBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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

/// 요일 선택 행 — Row + Expanded 균등 분할
class _WeekdayRow extends StatelessWidget {
  final Set<int> selected; // 1=월 … 7=일
  final void Function(int) onToggle;

  const _WeekdayRow({required this.selected, required this.onToggle});

  static const _labels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final day     = i + 1;
        final isSel   = selected.contains(day);
        final isSun   = day == 7;
        final isSat   = day == 6;
        final baseColor = isSun
            ? const Color(0xFFFF1744).withValues(alpha: 0.8)
            : isSat ? kTeal : kDim;
        return Expanded(
          child: GestureDetector(
            onTap: () => onToggle(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: isSel ? baseColor.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSel ? baseColor : kBorder.withValues(alpha: 0.5),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _labels[i],
                style: mono(
                  color: isSel ? baseColor : kDim.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// +/- 버튼 (탭 = tapStep, 홀드 = holdStep 가속)
class _TimeBtn extends StatefulWidget {
  final String label;
  final int tapStep;
  final int holdStep;
  final void Function(int) onStep;
  const _TimeBtn({required this.label, required this.tapStep, required this.holdStep, required this.onStep});

  @override
  State<_TimeBtn> createState() => _TimeBtnState();
}

class _TimeBtnState extends State<_TimeBtn> {
  Timer? _timer;
  int _ticks = 0;

  void _start() {
    widget.onStep(widget.tapStep);
    _ticks = 0;
    _timer = Timer(const Duration(milliseconds: 400), _repeat);
  }

  void _repeat() {
    if (!mounted) return;
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
        child: Text(widget.label, style: mono(color: kDim.withValues(alpha: 0.6), fontSize: 18)),
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
        child: Text(widget.label, style: mono(color: _pressing ? kMint : kDim, fontSize: 12)),
      ),
    );
  }
}
