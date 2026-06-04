import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../flavor.dart';

/// Terminal-style dialog for setting/clearing a memo reminder.
/// [onResult] is called with the chosen DateTime, or null to clear.
class ReminderDialog extends StatefulWidget {
  final DateTime? current;
  final DateTime? initialDate; // pre-fills date fields only (not time)
  final void Function(DateTime?) onResult;

  const ReminderDialog({
    super.key,
    this.current,
    this.initialDate,
    required this.onResult,
  });

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  late TextEditingController _yearCtrl,
      _monthCtrl,
      _dayCtrl,
      _hourCtrl,
      _minCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final base = widget.current ?? DateTime.now().add(const Duration(hours: 1));
    // Date: current reminder → initialDate → base (today+1h)
    final dateSource = widget.current ?? widget.initialDate ?? base;
    _yearCtrl = TextEditingController(text: dateSource.year.toString());
    _monthCtrl = TextEditingController(text: _p2(dateSource.month));
    _dayCtrl = TextEditingController(text: _p2(dateSource.day));
    // Time: always from base (current reminder or now+1h)
    _hourCtrl = TextEditingController(text: _p2(base.hour));
    _minCtrl = TextEditingController(text: _p2(base.minute));
  }

  @override
  void dispose() {
    for (final c in [_yearCtrl, _monthCtrl, _dayCtrl, _hourCtrl, _minCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String _p2(int v) => v.toString().padLeft(2, '0');

  void _applyQuickDate(int days, DateTime base) {
    final result = base.add(Duration(days: days));
    setState(() {
      _yearCtrl.text = result.year.toString();
      _monthCtrl.text = _p2(result.month);
      _dayCtrl.text = _p2(result.day);
      _error = null;
    });
  }

  void _showBaseDatePicker(int days) {
    showDialog(
      context: context,
      builder: (_) =>
          _BaseDateDialog(onResult: (date) => _applyQuickDate(days, date)),
    );
  }

  void _confirm() {
    final year = int.tryParse(_yearCtrl.text.trim());
    final month = int.tryParse(_monthCtrl.text.trim());
    final day = int.tryParse(_dayCtrl.text.trim());
    final hour = int.tryParse(_hourCtrl.text.trim());
    final min = int.tryParse(_minCtrl.text.trim());

    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        min == null ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31 ||
        hour < 0 ||
        hour > 23 ||
        min < 0 ||
        min > 59) {
      setState(() => _error = '올바른 날짜/시간을 입력하세요');
      return;
    }

    late DateTime dt;
    try {
      dt = DateTime(year, month, day, hour, min);
    } catch (_) {
      setState(() => _error = '유효하지 않은 날짜입니다');
      return;
    }
    if (dt.isBefore(DateTime.now())) {
      setState(() => _error = '현재 시각 이후로 설정하세요');
      return;
    }

    Navigator.pop(context);
    widget.onResult(dt);
  }

  void _clear() {
    Navigator.pop(context);
    widget.onResult(null);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 340,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                '[ SET REMINDER ]',
                style: mono(color: kMint, fontSize: 13, letterSpacing: 1),
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: kBorder),
              const SizedBox(height: 12),

              // Quick date buttons (store flavor only)
              if (isStoreFlavor) ...[
                Row(
                  children: [
                    _QuickDateBtn(
                      label: '[심플코스]',
                      sub: '+183일',
                      onTap: () => _showBaseDatePicker(183),
                    ),
                    const SizedBox(width: 8),
                    _QuickDateBtn(
                      label: '[요금할인]',
                      sub: '+120일',
                      onTap: () => _showBaseDatePicker(120),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: kBorder.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
              ],

              // Date row
              Row(
                children: [
                  Text('date: ', style: mono(color: kDim, fontSize: 12)),
                  _Field(_yearCtrl, 4, 'YYYY'),
                  Text(' - ', style: mono(color: kDim, fontSize: 12)),
                  _Field(_monthCtrl, 2, 'MM'),
                  Text(' - ', style: mono(color: kDim, fontSize: 12)),
                  _Field(_dayCtrl, 2, 'DD'),
                ],
              ),
              const SizedBox(height: 10),

              // Time row
              Row(
                children: [
                  Text('time: ', style: mono(color: kDim, fontSize: 12)),
                  _Field(_hourCtrl, 2, 'HH'),
                  Text(' : ', style: mono(color: kDim, fontSize: 12)),
                  _Field(_minCtrl, 2, 'MM'),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: mono(color: Colors.red.shade400, fontSize: 11),
                ),
              ],

              const SizedBox(height: 16),
              Container(height: 1, color: kBorder),
              const SizedBox(height: 12),

              // Actions
              Row(
                children: [
                  if (widget.current != null)
                    _Btn(
                      label: '[ 알림 취소 ]',
                      color: Colors.red.shade400,
                      onTap: _clear,
                    ),
                  const Spacer(),
                  _Btn(
                    label: '[ CANCEL ]',
                    color: kDim,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  _Btn(label: '[ SET ]', color: kMint, onTap: _confirm),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Number input field ────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final int maxLen;
  final String hint;

  const _Field(this.ctrl, this.maxLen, this.hint);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: maxLen == 4 ? 50.0 : 32.0,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        maxLength: maxLen,
        style: mono(color: kText, fontSize: 12),
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: mono(color: kDim.withValues(alpha: 0.4), fontSize: 10),
          filled: true,
          fillColor: kBg,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 6,
          ),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: kBorder),
            borderRadius: BorderRadius.zero,
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: kBorder),
            borderRadius: BorderRadius.zero,
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: kMint),
            borderRadius: BorderRadius.zero,
          ),
        ),
      ),
    );
  }
}

// ── Button ────────────────────────────────────────────────────────

class _Btn extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Btn({required this.label, required this.color, required this.onTap});

  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Text(
            widget.label,
            style: mono(color: widget.color, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

// ── Quick date shortcut button ────────────────────────────────────

class _QuickDateBtn extends StatefulWidget {
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _QuickDateBtn({
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  State<_QuickDateBtn> createState() => _QuickDateBtnState();
}

class _QuickDateBtnState extends State<_QuickDateBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered ? kTeal.withValues(alpha: 0.1) : Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: mono(color: _hovered ? kTeal : kDim, fontSize: 11),
              ),
              Text(
                widget.sub,
                style: mono(
                  color: _hovered
                      ? kTeal.withValues(alpha: 0.7)
                      : kDim.withValues(alpha: 0.45),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Base date picker dialog ───────────────────────────────────────

class _BaseDateDialog extends StatefulWidget {
  final void Function(DateTime) onResult;

  const _BaseDateDialog({required this.onResult});

  @override
  State<_BaseDateDialog> createState() => _BaseDateDialogState();
}

class _BaseDateDialogState extends State<_BaseDateDialog> {
  bool _showInput = false;
  late TextEditingController _yearCtrl, _monthCtrl, _dayCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _yearCtrl = TextEditingController(text: now.year.toString());
    _monthCtrl = TextEditingController(text: _p2(now.month));
    _dayCtrl = TextEditingController(text: _p2(now.day));
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  String _p2(int v) => v.toString().padLeft(2, '0');

  void _confirm() {
    final year = int.tryParse(_yearCtrl.text.trim());
    final month = int.tryParse(_monthCtrl.text.trim());
    final day = int.tryParse(_dayCtrl.text.trim());
    if (year == null ||
        month == null ||
        day == null ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      setState(() => _error = '올바른 날짜를 입력하세요');
      return;
    }
    late DateTime dt;
    try {
      dt = DateTime(year, month, day);
    } catch (_) {
      setState(() => _error = '유효하지 않은 날짜입니다');
      return;
    }
    Navigator.pop(context);
    widget.onResult(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 300,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '[ 기준 날짜 선택 ]',
                style: mono(color: kMint, fontSize: 13, letterSpacing: 1),
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: kBorder),
              const SizedBox(height: 16),

              if (!_showInput) ...[
                Row(
                  children: [
                    _Btn(
                      label: '[ 오늘 ]',
                      color: kMint,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onResult(DateTime.now());
                      },
                    ),
                    const SizedBox(width: 10),
                    _Btn(
                      label: '[ 직접 입력 ]',
                      color: kTeal,
                      onTap: () => setState(() => _showInput = true),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Text('date: ', style: mono(color: kDim, fontSize: 12)),
                    _Field(_yearCtrl, 4, 'YYYY'),
                    Text(' - ', style: mono(color: kDim, fontSize: 12)),
                    _Field(_monthCtrl, 2, 'MM'),
                    Text(' - ', style: mono(color: kDim, fontSize: 12)),
                    _Field(_dayCtrl, 2, 'DD'),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: mono(color: Colors.red.shade400, fontSize: 11),
                  ),
                ],
              ],

              const SizedBox(height: 16),
              Container(height: 1, color: kBorder),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _Btn(
                    label: '[ CANCEL ]',
                    color: kDim,
                    onTap: () => Navigator.pop(context),
                  ),
                  if (_showInput) ...[
                    const SizedBox(width: 10),
                    _Btn(label: '[ 확인 ]', color: kMint, onTap: _confirm),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
