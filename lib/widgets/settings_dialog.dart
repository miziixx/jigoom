import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../services/backup_service.dart';

class SettingsDialog extends StatefulWidget {
  final Color initialBg;
  final Color initialText;
  final bool initialTabLocked;
  final String initialFontFamily;
  final double initialFontSize;
  final void Function(
    Color bg,
    Color text,
    String fontFamily,
    double fontSize,
    bool tabLocked,
  )
  onSave;
  final VoidCallback onBackupTap;
  final void Function(Map<String, dynamic> data) onRestoreConfirmed;

  const SettingsDialog({
    super.key,
    required this.initialBg,
    required this.initialText,
    required this.initialTabLocked,
    required this.initialFontFamily,
    required this.initialFontSize,
    required this.onSave,
    required this.onBackupTap,
    required this.onRestoreConfirmed,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late Color _bg;
  late Color _text;
  late TextEditingController _bgCtrl;
  late TextEditingController _textCtrl;
  late bool _tabLocked;
  late String _fontFamily;
  late double _fontSize;
  bool _saved = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _bg = widget.initialBg;
    _text = widget.initialText;
    _tabLocked = widget.initialTabLocked;
    _fontFamily = widget.initialFontFamily;
    _fontSize = widget.initialFontSize;
    _bgCtrl = TextEditingController(text: _toHex(_bg));
    _textCtrl = TextEditingController(text: _toHex(_text));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _textCtrl.dispose();
    // Revert real-time font changes if user cancelled
    if (!_saved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        applyFont(widget.initialFontFamily, widget.initialFontSize);
      });
    }
    super.dispose();
  }

  static String _toHex(Color c) {
    int ch(double v) => (v * 255.0).round().clamp(0, 255);
    return [
      ch(c.r),
      ch(c.g),
      ch(c.b),
    ].map((v) => v.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  static Color? _parseHex(String raw) {
    final hex = raw.replaceAll('#', '').trim();
    if (hex.length == 6) {
      try {
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }
    return null;
  }

  void _resetDefaults() {
    setState(() {
      _bg = const Color(0xFFEDF2ED);
      _text = const Color(0xFF556B2F);
      _tabLocked = false;
      _fontFamily = 'JetBrains Mono';
      _fontSize = 13.0;
      _bgCtrl.text = _toHex(_bg);
      _textCtrl.text = _toHex(_text);
    });
    applyFont(_fontFamily, _fontSize);
  }

  Future<void> _doRestore() async {
    if (_restoring) return;
    setState(() => _restoring = true);

    final data = await BackupService.import();
    if (!mounted) return;

    if (data == null) {
      setState(() => _restoring = false);
      return;
    }

    final confirmed = await _showRestoreConfirm();
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _restoring = false);
      return;
    }

    _saved = true; // prevent font revert on dispose
    widget.onRestoreConfirmed(data);
    if (mounted) Navigator.pop(context);
  }

  Future<bool?> _showRestoreConfirm() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 320,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RESTORE',
                  style: monoLabel(color: kMint, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Text(
                  '. ' * 100,
                  style: mono(
                    color: kBorder.withValues(alpha: 0.8),
                    fontSize: 8,
                  ),
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                  softWrap: false,
                ),
                const SizedBox(height: 14),
                Text(
                  '기존 데이터가 덮어씌워집니다.\n계속할까요?',
                  style: mono(color: kDim, fontSize: 12, height: 1.7),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _Btn(
                      label: 'CANCEL',
                      color: kDim,
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                    const SizedBox(width: 10),
                    _Btn(
                      label: 'OK',
                      color: kMint,
                      onTap: () => Navigator.pop(ctx, true),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────
              Text(
                'SETTINGS',
                style: monoLabel(color: kMint, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Text(
                '. ' * 100,
                style: mono(color: kBorder.withValues(alpha: 0.8), fontSize: 8),
                overflow: TextOverflow.clip,
                maxLines: 1,
                softWrap: false,
              ),
              const SizedBox(height: 18),

              // ── Background color ─────────────────────
              _ColorSection(
                label: 'bg_color',
                color: _bg,
                hexCtrl: _bgCtrl,
                onColorChanged: (c) {
                  setState(() => _bg = c);
                  final hex = _toHex(c);
                  if (_bgCtrl.text.toUpperCase() != hex) {
                    _bgCtrl.value = _bgCtrl.value.copyWith(
                      text: hex,
                      selection: TextSelection.collapsed(offset: hex.length),
                    );
                  }
                },
                onHexInput: (raw) {
                  final c = _parseHex(raw);
                  if (c != null) setState(() => _bg = c);
                },
              ),

              const SizedBox(height: 22),

              // ── Font / text color ────────────────────
              _ColorSection(
                label: 'text_color',
                color: _text,
                hexCtrl: _textCtrl,
                onColorChanged: (c) {
                  setState(() => _text = c);
                  final hex = _toHex(c);
                  if (_textCtrl.text.toUpperCase() != hex) {
                    _textCtrl.value = _textCtrl.value.copyWith(
                      text: hex,
                      selection: TextSelection.collapsed(offset: hex.length),
                    );
                  }
                },
                onHexInput: (raw) {
                  final c = _parseHex(raw);
                  if (c != null) setState(() => _text = c);
                },
              ),

              const SizedBox(height: 22),
              Text(
                '. ' * 100,
                style: mono(color: kBorder.withValues(alpha: 0.8), fontSize: 8),
                overflow: TextOverflow.clip,
                maxLines: 1,
                softWrap: false,
              ),
              const SizedBox(height: 16),

              // ── Tab lock ─────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'tab_lock',
                    style: mono(color: kDim, fontSize: 11, letterSpacing: 0.5),
                  ),
                  _ToggleSwitch(
                    value: _tabLocked,
                    onChanged: (v) => setState(() => _tabLocked = v),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Text(
                '. ' * 100,
                style: mono(color: kBorder.withValues(alpha: 0.8), fontSize: 8),
                overflow: TextOverflow.clip,
                maxLines: 1,
                softWrap: false,
              ),
              const SizedBox(height: 16),

              // ── Font family ──────────────────────────
              Text(
                'font_family',
                style: mono(color: kDim, fontSize: 11, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: kBorder.withValues(alpha: 0.7)),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.25,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: kFontOptions
                        .map(
                          (f) => _FontOption(
                            fontName: f,
                            isSelected: _fontFamily == f,
                            onTap: () {
                              setState(() => _fontFamily = f);
                              applyFont(_fontFamily, _fontSize);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Font size ────────────────────────────
              Row(
                children: [
                  Text(
                    'font_size',
                    style: mono(color: kDim, fontSize: 11, letterSpacing: 0.5),
                  ),
                  const Spacer(),
                  _StepBtn(
                    label: '-',
                    enabled: _fontSize > 10,
                    onTap: () {
                      setState(() => _fontSize = (_fontSize - 1).clamp(10, 20));
                      applyFont(_fontFamily, _fontSize);
                    },
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${_fontSize.toInt()} px',
                      style: mono(color: kText, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StepBtn(
                    label: '+',
                    enabled: _fontSize < 20,
                    onTap: () {
                      setState(() => _fontSize = (_fontSize + 1).clamp(10, 20));
                      applyFont(_fontFamily, _fontSize);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 22),
              Text(
                '. ' * 100,
                style: mono(color: kBorder.withValues(alpha: 0.8), fontSize: 8),
                overflow: TextOverflow.clip,
                maxLines: 1,
                softWrap: false,
              ),
              const SizedBox(height: 16),

              // ── Backup / Restore ─────────────────────
              Text(
                'backup',
                style: mono(color: kDim, fontSize: 11, letterSpacing: 0.5),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Btn(label: 'BACKUP', color: kDim, onTap: widget.onBackupTap),
                  const SizedBox(width: 10),
                  _Btn(
                    label: _restoring ? '...' : 'RESTORE',
                    color: _restoring ? kDim.withValues(alpha: 0.4) : kDim,
                    onTap: _doRestore,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Text(
                '. ' * 100,
                style: mono(color: kBorder.withValues(alpha: 0.8), fontSize: 8),
                overflow: TextOverflow.clip,
                maxLines: 1,
                softWrap: false,
              ),
              const SizedBox(height: 14),

              // ── Actions ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _Btn(label: 'RESET', color: kDim, onTap: _resetDefaults),
                  const SizedBox(width: 10),
                  _Btn(
                    label: 'SAVE',
                    color: kMint,
                    onTap: () {
                      _saved = true;
                      widget.onSave(
                        _bg,
                        _text,
                        _fontFamily,
                        _fontSize,
                        _tabLocked,
                      );
                      Navigator.pop(context);
                    },
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

// ──────────────────────────────────────────────────────────────
// Font family option row
// ──────────────────────────────────────────────────────────────

class _FontOption extends StatefulWidget {
  final String fontName;
  final bool isSelected;
  final VoidCallback onTap;

  const _FontOption({
    required this.fontName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FontOption> createState() => _FontOptionState();
}

class _FontOptionState extends State<_FontOption> {
  bool _hovered = false;

  TextStyle _nameStyle() {
    final c = widget.isSelected ? kMint : (_hovered ? kText : kDim);
    const sz = 11.0;
    switch (widget.fontName) {
      case 'JetBrains Mono':
        return GoogleFonts.jetBrainsMono(fontSize: sz, color: c);
      case 'Fira Code':
        return GoogleFonts.firaCode(fontSize: sz, color: c);
      case 'Source Code Pro':
        return GoogleFonts.sourceCodePro(fontSize: sz, color: c);
      case 'Roboto Mono':
        return GoogleFonts.robotoMono(fontSize: sz, color: c);
      case 'Nanum Gothic Coding':
        return GoogleFonts.nanumGothicCoding(fontSize: sz, color: c);
      default:
        return TextStyle(fontFamily: widget.fontName, fontSize: sz, color: c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isSelected
        ? kMint.withValues(alpha: 0.08)
        : (_hovered ? kBorder.withValues(alpha: 0.2) : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Text(
                widget.isSelected ? '> ' : '  ',
                style: mono(color: kMint, fontSize: 11),
              ),
              Expanded(
                child: Text(
                  widget.fontName,
                  style: _nameStyle(),
                  overflow: TextOverflow.ellipsis,
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
// Toggle switch [ OFF ] / [ ON ]
// ──────────────────────────────────────────────────────────────

class _ToggleSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleSwitch({required this.value, required this.onChanged});

  @override
  State<_ToggleSwitch> createState() => _ToggleSwitchState();
}

class _ToggleSwitchState extends State<_ToggleSwitch> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.value;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onChanged(!on),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: on
                ? kMint.withValues(alpha: 0.10)
                : (_hovered
                      ? kBorder.withValues(alpha: 0.15)
                      : Colors.transparent),
          ),
          child: Text(
            on ? 'ON' : 'OFF',
            style: mono(color: on ? kMint : kDim, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// +/- step button
// ──────────────────────────────────────────────────────────────

class _StepBtn extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _StepBtn({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_StepBtn> createState() => _StepBtnState();
}

class _StepBtnState extends State<_StepBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.enabled
        ? (_hovered ? kMint : kDim)
        : kDim.withValues(alpha: 0.3);

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.enabled && _hovered
                ? kMint.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Text(widget.label, style: mono(color: c, fontSize: 14)),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// One color section: label + picker + hex input
// ──────────────────────────────────────────────────────────────

class _ColorSection extends StatelessWidget {
  final String label;
  final Color color;
  final TextEditingController hexCtrl;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<String> onHexInput;

  const _ColorSection({
    required this.label,
    required this.color,
    required this.hexCtrl,
    required this.onColorChanged,
    required this.onHexInput,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: mono(color: kDim, fontSize: 11, letterSpacing: 0.5)),
        const SizedBox(height: 8),

        LayoutBuilder(
          builder: (context, bc) {
            final pickerW = bc.maxWidth.isFinite ? bc.maxWidth - 2 : 300.0;
            return Container(
              decoration: BoxDecoration(
                color: kSurface,
                border: Border.all(color: kBorder),
              ),
              child: Theme(
                data: ThemeData.dark().copyWith(
                  textTheme: ThemeData.dark().textTheme.apply(bodyColor: kDim),
                ),
                child: ColorPicker(
                  pickerColor: color,
                  onColorChanged: onColorChanged,
                  enableAlpha: false,
                  labelTypes: const [],
                  pickerAreaHeightPercent: 0.55,
                  colorPickerWidth: pickerW,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: kBorder),
              ),
            ),
            const SizedBox(width: 10),
            Text('#', style: mono(color: kMint, fontSize: 14)),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: hexCtrl,
                style: mono(color: kText, fontSize: 13),
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                ],
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: kBorder.withValues(alpha: 0.25),
                  hintText: 'RRGGBB',
                  hintStyle: mono(color: kDim, fontSize: 12),
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
                onChanged: onHexInput,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Reusable action button
// ──────────────────────────────────────────────────────────────

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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Text(
            widget.label,
            style: mono(color: widget.color, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
