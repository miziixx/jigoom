import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../models/folder.dart';
import '../services/image_service.dart';
import 'schedule_sheet.dart';

class InputBar extends StatefulWidget {
  final void Function(
    String content,
    bool isChecklist,
    DateTime? reminderAt,
    String? folderId,
    List<String> imagePaths,
    String reminderRepeat,
    DateTime? scheduledAt,
  ) onSubmit;
  final DateTime? initialDate;
  final List<Folder> folders;
  final String? currentFolderId;
  final bool scheduleMode;

  const InputBar({
    super.key,
    required this.onSubmit,
    this.initialDate,
    this.folders = const [],
    this.currentFolderId,
    this.scheduleMode = false,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  DateTime? _reminderAt;
  String _reminderRepeat = 'none';
  DateTime? _scheduledAt;
  String? _selectedFolderId;
  final _pendingImages = <String>[];
  bool _forceChecklist = false;
  String _prevText = '';
  bool _processingExcl = false;
  bool _schedulePickerOpened = false;

  static final _tagRe = RegExp(r'#([a-zA-Zㄱ-ㅎㅏ-ㅣ가-힣][a-zA-Z0-9_ㄱ-ㅎㅏ-ㅣ가-힣]*)');

  List<String> get _tags => _tagRe
      .allMatches(_controller.text)
      .map((m) => m.group(1)!)
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList();

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.currentFolderId;
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      setState(() {});
      if (widget.scheduleMode &&
          _focusNode.hasFocus &&
          _scheduledAt == null &&
          !_schedulePickerOpened) {
        _schedulePickerOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSchedulePicker();
        });
      }
    });
    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.enter &&
            HardwareKeyboard.instance.isShiftPressed) {
          _submit();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
  }

  void _onTextChanged() {
    if (_processingExcl) {
      setState(() {});
      return;
    }
    final newText = _controller.text;
    if (_scheduledAt == null && newText.contains('!') && !_prevText.contains('!')) {
      _processingExcl = true;
      final excIdx = newText.indexOf('!');
      final cleaned = newText.replaceFirst('!', '');
      _controller.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: excIdx.clamp(0, cleaned.length)),
      );
      _processingExcl = false;
      _prevText = cleaned;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSchedulePicker();
      });
    } else {
      _prevText = newText;
    }
    final hadFocus = _focusNode.hasFocus;
    setState(() {});
    // 태그 배지가 나타나면서 레이아웃이 변해 키보드가 내려가는 경우 방지
    if (hadFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) _focusNode.requestFocus();
      });
    }
  }

  void _showSchedulePicker() {
    showScheduleSheet(
      context,
      current: _scheduledAt,
      initialDate: widget.initialDate ?? DateTime.now(),
      currentRepeat: 'none',
      onResult: (dt, _) => setState(() => _scheduledAt = dt),
    );
  }

  bool get _isChecklist {
    final lines = _controller.text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return false;
    return lines.every((l) =>
        l.startsWith('- [ ] ') ||
        l.startsWith('- [x] ') ||
        l.startsWith('• '));
  }

  void _wrapSelection(String prefix, String suffix) {
    final sel = _controller.selection;
    final old = _controller.text;
    if (sel.isValid && !sel.isCollapsed) {
      final selected = old.substring(sel.start, sel.end);
      final newText = old.replaceRange(sel.start, sel.end, '$prefix$selected$suffix');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: sel.start + prefix.length,
          extentOffset: sel.start + prefix.length + selected.length,
        ),
      );
    } else {
      final pos = sel.isValid ? sel.start : old.length;
      final newText = old.substring(0, pos) + '$prefix$suffix' + old.substring(pos);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + prefix.length),
      );
    }
    _focusNode.requestFocus();
  }

  void _insertText(String text) {
    final sel = _controller.selection;
    final old = _controller.text;
    final String newText;
    final int offset;
    if (sel.isValid && sel.start >= 0) {
      newText = old.replaceRange(sel.start, sel.end, text);
      offset = sel.start + text.length;
    } else {
      newText = old + text;
      offset = newText.length;
    }
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset),
    );
    _focusNode.requestFocus();
  }

  void _insertListPrefix(String prefix) {
    final sel = _controller.selection;
    final old = _controller.text;
    if (old.isEmpty || !sel.isValid || sel.start <= 0) {
      final newText = prefix + old;
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: prefix.length),
      );
    } else {
      final insert = '\n$prefix';
      final newText = old.substring(0, sel.start) + insert + old.substring(sel.end);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + insert.length),
      );
    }
    _focusNode.requestFocus();
  }

  String _fmtReminder(DateTime dt) {
    final mo = dt.month.toString().padLeft(2, '0');
    final d  = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$mo/$d $hh:$mm';
  }

  String _repeatLabel(String repeat) {
    switch (repeat) {
      case 'daily':   return ' ↻매일';
      case 'weekly':  return ' ↻매주';
      case 'monthly': return ' ↻매월';
      default:        return '';
    }
  }

  void _showReminderPicker() {
    showScheduleSheet(
      context,
      current: _reminderAt,
      initialDate: widget.initialDate ?? DateTime.now(),
      currentRepeat: _reminderRepeat,
      onResult: (dt, repeat) => setState(() {
        _reminderAt = dt;
        _reminderRepeat = repeat;
      }),
    );
  }

  void _showFolderDropdown() async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final pos = renderBox.localToGlobal(Offset.zero);

    final result = await showMenu<String?>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(pos.dx + 14, pos.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      color: kSurface,
      elevation: 3,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      items: [
        PopupMenuItem<String?>(
          value: '__inbox__',
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('/inbox',
              style: mono(
                  color: _selectedFolderId == null ? kMint : kText,
                  fontSize: 12)),
        ),
        ...widget.folders.map((f) => PopupMenuItem<String?>(
              value: f.id,
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('/${f.name}',
                  style: mono(
                      color: _selectedFolderId == f.id ? kMint : kText,
                      fontSize: 12)),
            )),
      ],
    );
    if (result != null) {
      setState(
          () => _selectedFolderId = result == '__inbox__' ? null : result);
    }
  }

  Future<void> _pickImage() async {
    if (kIsWeb) return;
    final source = await _showImageSourceSheet();
    if (source == null) return;

    final path = await ImageService.pick(source);
    if (!mounted) return;

    if (path == '__TOO_LARGE__') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: kSurface,
        duration: const Duration(seconds: 2),
        content: Text('이미지 용량이 5MB를 초과합니다',
            style: mono(color: Colors.red.shade400, fontSize: 12)),
      ));
      return;
    }

    if (path != null) setState(() => _pendingImages.add(path));
  }

  Future<ImageSource?> _showImageSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('[이미지 추가]',
                  style: mono(color: kMint, fontSize: 13, letterSpacing: 1)),
              const SizedBox(height: 12),
              Container(height: 1, color: kBorder),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SheetBtn(
                    label: '[갤러리]',
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                  const SizedBox(width: 12),
                  _SheetBtn(
                    label: '[카메라]',
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _reorderChecklistFirst(String content) {
    final lines = content.split('\n');
    final listLines = lines
        .where((l) =>
            l.startsWith('- [ ] ') ||
            l.startsWith('- [x] ') ||
            l.startsWith('• '))
        .toList();
    final plainLines = lines
        .where((l) =>
            !l.startsWith('- [ ] ') &&
            !l.startsWith('- [x] ') &&
            !l.startsWith('• '))
        .toList();
    if (listLines.isEmpty || plainLines.isEmpty) return content;
    return [...listLines, ...plainLines].join('\n');
  }

  void _submit() {
    final raw = _controller.text.trim();
    final text = _reorderChecklistFirst(raw);
    if (text.isEmpty && _pendingImages.isEmpty) return;
    widget.onSubmit(
      text,
      _isChecklist,
      _reminderAt,
      _selectedFolderId,
      List<String>.from(_pendingImages),
      _reminderRepeat,
      _scheduledAt,
    );
    _controller.clear();
    setState(() {
      _reminderAt = null;
      _reminderRepeat = 'none';
      _scheduledAt = null;
      _pendingImages.clear();
      _forceChecklist = false;
      _schedulePickerOpened = false;
    });
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tags = _tags;
    return Container(
      color: kBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toolbar row (포커스 시에만 표시) ───────────────
          if (_focusNode.hasFocus || _pendingImages.isNotEmpty || _reminderAt != null)
          MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 1, 6, 1),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: kBorder.withValues(alpha: 0.5))),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TextFmtBtn(label: 'B', bold: true,
                      onTap: () => _wrapSelection('**', '**')),
                  _TextFmtBtn(label: 'I', italic: true,
                      onTap: () => _wrapSelection('*', '*')),
                  _TextFmtBtn(label: 'S', strike: true,
                      onTap: () => _wrapSelection('~~', '~~')),
                  Container(width: 1, height: 14, color: kBorder.withValues(alpha: 0.6),
                      margin: const EdgeInsets.symmetric(horizontal: 2)),
                  _ToolBtn(
                    icon: Icons.check_box_outline_blank,
                    tooltip: '체크박스',
                    onTap: () => _insertListPrefix('- [ ] '),
                  ),
                  _ToolBtn(
                    icon: Icons.format_list_bulleted,
                    tooltip: '불릿',
                    onTap: () => _insertListPrefix('• '),
                  ),
                  _ToolBtn(
                    icon: Icons.tag,
                    tooltip: '태그',
                    onTap: () => _insertText('#'),
                  ),
                  _ToolBtn(
                    icon: Icons.calendar_today,
                    tooltip: 'event',
                    active: _scheduledAt != null,
                    onTap: _showSchedulePicker,
                  ),
                  _ToolBtn(
                    icon: Icons.alarm_outlined,
                    tooltip: 'task 알림',
                    active: _reminderAt != null,
                    onTap: _showReminderPicker,
                  ),
                  if (!kIsWeb)
                    _ToolBtn(
                      icon: Icons.image_outlined,
                      tooltip: '이미지',
                      active: _pendingImages.isNotEmpty,
                      onTap: _pickImage,
                    ),
                  const Spacer(),
                  _AddBtn(onTap: _submit),
                ],
              ),
            ),
          ),

          // ── Badges: tags + reminder ────────────────────────
          if (tags.isNotEmpty || _reminderAt != null || _scheduledAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ...tags.map((t) =>
                      Text('#$t', style: mono(color: kTeal, fontSize: 11))),
                  if (_scheduledAt != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('! ${_fmtReminder(_scheduledAt!)}',
                            style: mono(color: kMint, fontSize: 10)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() => _scheduledAt = null),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Text('[×]',
                                style: mono(
                                    color: kDim.withValues(alpha: 0.6),
                                    fontSize: 10)),
                          ),
                        ),
                      ],
                    ),
                  if (_reminderAt != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🔔 ${_fmtReminder(_reminderAt!)}${_repeatLabel(_reminderRepeat)}',
                            style: mono(color: kMint, fontSize: 10)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() {
                            _reminderAt = null;
                            _reminderRepeat = 'none';
                          }),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Text('[×]',
                                style: mono(
                                    color: kDim.withValues(alpha: 0.6),
                                    fontSize: 10)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

          // ── Pending images row ─────────────────────────────
          if (_pendingImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pendingImages.length,
                  itemBuilder: (ctx, i) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.zero,
                            child: Image.file(
                              File(_pendingImages[i]),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => setState(
                                  () => _pendingImages.removeAt(i)),
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.close,
                                    size: 10, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          // ── Text input ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 5, 14, 7),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: mono(fontSize: 13, height: 1.35),
              maxLines: 6,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              cursorColor: kMint,
              cursorWidth: 2,
              decoration: InputDecoration(
                hintText: widget.scheduleMode ? '! new event' : 'new memo',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                hintStyle: mono(
                    color: kDim.withValues(alpha: 0.55), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Tool button
// ─────────────────────────────────────────────────────────────────

class _ToolBtn extends StatefulWidget {
  final IconData? icon;
  final String? iconText; // text-based icon (e.g. '◷')
  final VoidCallback onTap;
  final bool active;
  final String? tooltip;

  const _ToolBtn({
    this.icon,
    this.iconText,
    required this.onTap,
    this.active = false,
    this.tooltip,
  }) : assert(icon != null || iconText != null);

  @override
  State<_ToolBtn> createState() => _ToolBtnState();
}

class _ToolBtnState extends State<_ToolBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? kMint
        : (_hovered ? kText : kDim.withValues(alpha: 0.55));

    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => widget.onTap(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: widget.active
                ? kMint.withValues(alpha: 0.1)
                : (_hovered ? kSurface : Colors.transparent),
          ),
          child: widget.iconText != null
              ? Text(widget.iconText!, style: mono(color: color, fontSize: 17))
              : Icon(widget.icon!, size: 15, color: color),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        preferBelow: false,
        textStyle: mono(color: kText, fontSize: 10),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kBorder),
        ),
        child: btn,
      );
    }
    return btn;
  }
}

// ─────────────────────────────────────────────────────────────────
// ADD submit button
// ─────────────────────────────────────────────────────────────────

class _AddBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _AddBtn({required this.onTap});

  @override
  State<_AddBtn> createState() => _AddBtnState();
}

class _AddBtnState extends State<_AddBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => widget.onTap(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? kMint.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Text(
            '[추가]',
            style: mono(color: _hovered ? kMint : kDim, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Folder button
// ─────────────────────────────────────────────────────────────────

class _FolderBtn extends StatefulWidget {
  final String? label;
  final VoidCallback? onTap;
  const _FolderBtn({required this.label, this.onTap});

  @override
  State<_FolderBtn> createState() => _FolderBtnState();
}

class _FolderBtnState extends State<_FolderBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null;
    final displayLabel = widget.label != null && widget.label!.isNotEmpty
        ? '[${widget.label} ▾]'
        : '[폴더 선택]';
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered && active
                ? kMint.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Text(
            displayLabel,
            style: mono(
                color: _hovered ? kMint : kDim.withValues(alpha: 0.55),
                fontSize: 10),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Image source sheet button
// ─────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────
// Markdown formatting button (B / I / S)
// ─────────────────────────────────────────────────────────────────

class _TextFmtBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool bold;
  final bool italic;
  final bool strike;

  const _TextFmtBtn({
    required this.label,
    required this.onTap,
    this.bold = false,
    this.italic = false,
    this.strike = false,
  });

  @override
  State<_TextFmtBtn> createState() => _TextFmtBtnState();
}

class _TextFmtBtnState extends State<_TextFmtBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? kText : kDim.withValues(alpha: 0.55);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => widget.onTap(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered ? kSurface : Colors.transparent,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 12,
              color: color,
              fontWeight: widget.bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: widget.italic ? FontStyle.italic : FontStyle.normal,
              decoration: widget.strike ? TextDecoration.lineThrough : null,
              decorationColor: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SheetBtn({required this.label, required this.onTap});

  @override
  State<_SheetBtn> createState() => _SheetBtnState();
}

class _SheetBtnState extends State<_SheetBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? kMint.withValues(alpha: 0.1) : Colors.transparent,
            border: Border.all(color: kBorder),
          ),
          child: Text(widget.label,
              style: mono(color: _hovered ? kMint : kDim, fontSize: 12)),
        ),
      ),
    );
  }
}
