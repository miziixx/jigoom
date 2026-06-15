import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/memo.dart';
import '../models/append_note.dart';
import '../models/memo_actions.dart';
import '../app_theme.dart';
import '../services/image_service.dart';
import '../services/local_search_service.dart';
import 'schedule_sheet.dart';

Color _memoDoneTextColor() => Color.lerp(kText, kDim, 0.55) ?? kDim;

Color _memoDoneAccentColor() => Color.lerp(kMint, kDim, 0.62) ?? kDim;

class MemoTile extends StatefulWidget {
  final Memo memo;
  final MemoActions actions;
  final bool highlighted;
  final List<Memo> allMemos;

  const MemoTile({
    super.key,
    required this.memo,
    required this.actions,
    this.highlighted = false,
    this.allMemos = const [],
  });

  @override
  State<MemoTile> createState() => _MemoTileState();
}

class _MemoTileState extends State<MemoTile> {
  // habit/goal memos cannot be moved or merged
  bool get _isSystemMemo =>
      widget.memo.tags.any((t) => t == 'habit' || t == 'goal');

  MemoActions get _a => widget.actions;

  bool _hovered = false;
  bool _isEditing = false;
  String? _editFolderId;
  final _editController = TextEditingController();
  final _editFocusNode = FocusNode();

  // Checklist add-item input
  final _addItemController = TextEditingController();
  final _addItemFocusNode = FocusNode();
  bool _checkItemInputVisible = false;

  // Append note input
  bool _isAddingNote = false;
  final _noteController = TextEditingController();
  final _noteFocusNode = FocusNode();

  // Append note edit
  int _editingNoteIndex = -1;
  final _editNoteController = TextEditingController();
  final _editNoteFocusNode = FocusNode();

  // Checklist item inline edit
  int _editingCheckIndex = -1;
  final _editCheckController = TextEditingController();
  final _editCheckFocusNode = FocusNode();

  // Context menu tap position
  Offset _tapPosition = Offset.zero;

  // [1] Swipe state
  double _swipeOffset = 0;
  bool _deleteRevealed = false;

  static const _kDeleteSnap = -75.0;
  static const _kDeleteThreshold = -55.0;
  static const _kMoveThreshold = 52.0;

  // Only match # preceded by whitespace or at start — avoids URL fragments like #section
  static final _tagRe = RegExp(
    r'(?<![^\s])#[a-zA-Zㄱ-ㅎㅏ-ㅣ가-힣][a-zA-Z0-9_ㄱ-ㅎㅏ-ㅣ가-힣]*',
  );
  static final _checkRe = RegExp(r'^- \[[ x]\] |^• ');

  @override
  void initState() {
    super.initState();
    _addItemController.addListener(_onAddItemChanged);
    _editFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _cancelEdit();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter &&
            HardwareKeyboard.instance.isShiftPressed) {
          _saveEdit();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _noteFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          setState(() {
            _isAddingNote = false;
            _noteController.clear();
          });
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter &&
            HardwareKeyboard.instance.isShiftPressed) {
          _saveNote();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _editNoteFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          setState(() {
            _editingNoteIndex = -1;
            _editNoteController.clear();
          });
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter &&
            HardwareKeyboard.instance.isShiftPressed) {
          _saveNoteEdit();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
  }

  // ── Append note ──────────────────────────────────────

  void _saveNote() {
    final text = _noteController.text.trim();
    if (text.isNotEmpty) _a.onAddNote(widget.memo, text);
    setState(() {
      _isAddingNote = false;
      _noteController.clear();
    });
  }

  void _startNoteEdit(int index) {
    final note = widget.memo.appendNotes[index];
    setState(() {
      _editingNoteIndex = index;
      _editNoteController.text = note.content;
      _editNoteController.selection = TextSelection.collapsed(
        offset: _editNoteController.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editNoteFocusNode.requestFocus();
    });
  }

  void _saveNoteEdit() {
    final text = _editNoteController.text.trim();
    if (text.isNotEmpty) _a.onUpdateNote(widget.memo, _editingNoteIndex, text);
    setState(() {
      _editingNoteIndex = -1;
      _editNoteController.clear();
    });
  }

  void _confirmDeleteNote(int index) {
    final note = widget.memo.appendNotes[index];
    final preview = note.content.length > 40
        ? '${note.content.substring(0, 40)}...'
        : note.content;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DELETE NOTE',
                style: mono(color: kMint, fontSize: 13, letterSpacing: 1),
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: kBorder),
              const SizedBox(height: 12),
              Text(
                '"$preview"',
                style: mono(color: kDim, fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionBtn(
                    label: '취소',
                    color: kDim,
                    onTap: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(width: 10),
                  _ActionBtn(
                    label: '삭제',
                    color: Colors.red.shade400,
                    onTap: () {
                      Navigator.pop(ctx);
                      _a.onDeleteNote(widget.memo, index);
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

  // ── Checklist ────────────────────────────────────────

  void _onAddItemChanged() {
    final text = _addItemController.text;
    if (!text.contains('\n')) return;
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    _addItemController.removeListener(_onAddItemChanged);
    _addItemController.clear();
    _addItemController.addListener(_onAddItemChanged);
    for (final line in lines) {
      _addChecklistItem(line);
    }
  }

  void _addChecklistItem(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() => _checkItemInputVisible = false);
      return;
    }
    final newLine = '- [ ] $trimmed';
    final current = widget.memo.content;
    final newContent = current.isEmpty ? newLine : '$current\n$newLine';
    _a.onUpdate(widget.memo, newContent);
    _addItemController.clear();
    setState(() => _checkItemInputVisible = false);
    FocusScope.of(context).unfocus();
  }

  void _deleteChecklistItem(int lineIndex) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('항목을 삭제하시겠습니까?', style: mono(color: kText, fontSize: 12)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionBtn(
                    label: '취소',
                    color: kDim,
                    onTap: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    label: '삭제',
                    color: Colors.red.shade400,
                    onTap: () {
                      Navigator.pop(ctx);
                      final lines = widget.memo.content.split('\n');
                      if (lineIndex < 0 || lineIndex >= lines.length) return;
                      lines.removeAt(lineIndex);
                      _a.onUpdate(widget.memo, lines.join('\n'));
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

  void _startEditingCheckItem(int lineIndex, String currentText) {
    setState(() {
      _editingCheckIndex = lineIndex;
      _editCheckController.text = currentText;
      _editCheckController.selection = TextSelection.collapsed(
        offset: currentText.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _editCheckFocusNode.requestFocus(),
    );
  }

  void _saveCheckItem() {
    final trimmed = _editCheckController.text.trim();
    if (trimmed.isEmpty) {
      _deleteChecklistItem(_editingCheckIndex);
    } else {
      final lines = widget.memo.content.split('\n');
      final idx = _editingCheckIndex;
      if (idx >= 0 && idx < lines.length) {
        final old = lines[idx];
        String prefix = '- [ ] ';
        if (old.startsWith('- [x] '))
          prefix = '- [x] ';
        else if (old.startsWith('• '))
          prefix = '• ';
        lines[idx] = '$prefix$trimmed';
        _a.onUpdate(widget.memo, lines.join('\n'));
      }
    }
    setState(() => _editingCheckIndex = -1);
    _editCheckController.clear();
  }

  void _cancelCheckEdit() {
    setState(() => _editingCheckIndex = -1);
    _editCheckController.clear();
  }

  // ── Edit ────────────────────────────────────────────

  void _startEditing() {
    if (_deleteRevealed) {
      setState(() {
        _swipeOffset = 0;
        _deleteRevealed = false;
      });
      return;
    }
    setState(() {
      _isEditing = true;
      _editFolderId = widget.memo.folderId;
      _editController.text = widget.memo.content;
      _editController.selection = TextSelection.collapsed(
        offset: _editController.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _editFocusNode.requestFocus(),
    );
  }

  void _saveEdit() {
    final raw = _editController.text.trim();
    if (raw.isNotEmpty) _a.onUpdate(widget.memo, raw);
    if (_editFolderId != widget.memo.folderId && !_isSystemMemo) {
      _a.onMove(widget.memo, _editFolderId);
    }
    setState(() => _isEditing = false);
  }

  // ── Edit mode text formatting ────────────────────────

  void _wrapEdit(String prefix, String suffix) {
    final sel = _editController.selection;
    final old = _editController.text;
    if (sel.isValid && !sel.isCollapsed) {
      final selected = old.substring(sel.start, sel.end);
      final newText = old.replaceRange(
        sel.start,
        sel.end,
        '$prefix$selected$suffix',
      );
      _editController.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: sel.start + prefix.length,
          extentOffset: sel.start + prefix.length + selected.length,
        ),
      );
    } else {
      final pos = sel.isValid ? sel.start : old.length;
      final newText =
          old.substring(0, pos) + '$prefix$suffix' + old.substring(pos);
      _editController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + prefix.length),
      );
    }
    _editFocusNode.requestFocus();
  }

  void _insertEditText(String text) {
    final sel = _editController.selection;
    final old = _editController.text;
    final int pos = sel.isValid && sel.start >= 0 ? sel.start : old.length;
    final newText = old.replaceRange(
      sel.isValid ? sel.start : old.length,
      sel.isValid ? sel.end : old.length,
      text,
    );
    _editController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + text.length),
    );
    _editFocusNode.requestFocus();
  }

  void _insertEditListPrefix(String prefix) {
    final sel = _editController.selection;
    final old = _editController.text;
    if (old.isEmpty || !sel.isValid || sel.start <= 0) {
      final newText = prefix + old;
      _editController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: prefix.length),
      );
    } else {
      final insert = '\n$prefix';
      final newText =
          old.substring(0, sel.start) + insert + old.substring(sel.end);
      _editController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + insert.length),
      );
    }
    _editFocusNode.requestFocus();
  }

  void _cancelEdit() => setState(() => _isEditing = false);

  void _toggleCheck(int lineIndex) {
    final lines = widget.memo.content.split('\n');
    if (lineIndex >= lines.length) return;
    final line = lines[lineIndex];
    if (line.startsWith('- [ ]')) {
      lines[lineIndex] = '- [x]${line.substring(5)}';
    } else if (line.startsWith('- [x]')) {
      lines[lineIndex] = '- [ ]${line.substring(5)}';
    } else {
      return;
    }
    _a.onUpdate(widget.memo, lines.join('\n'));
  }

  // ── Swipe ────────────────────────────────────────────

  void _onSwipeUpdate(DragUpdateDetails d) {
    if (_deleteRevealed) {
      if (d.delta.dx > 0) {
        setState(() {
          _swipeOffset = (_swipeOffset + d.delta.dx).clamp(_kDeleteSnap, 0);
          if (_swipeOffset >= 0) {
            _swipeOffset = 0;
            _deleteRevealed = false;
          }
        });
      }
      return;
    }
    setState(() {
      _swipeOffset = (_swipeOffset + d.delta.dx).clamp(-80.0, 80.0);
    });
  }

  void _onSwipeEnd(DragEndDetails d) {
    if (_swipeOffset <= _kDeleteThreshold) {
      setState(() {
        _swipeOffset = _kDeleteSnap;
        _deleteRevealed = true;
      });
    } else if (_swipeOffset >= _kMoveThreshold) {
      setState(() => _swipeOffset = 0);
      if (!_isSystemMemo) _showFolderPicker();
    } else {
      setState(() {
        _swipeOffset = 0;
        _deleteRevealed = false;
      });
    }
  }

  void _onDeleteBtnTap() {
    setState(() {
      _swipeOffset = 0;
      _deleteRevealed = false;
    });
    _a.onDelete(widget.memo);
  }

  // ── Share ─────────────────────────────────────────────

  String _buildShareText() {
    final memo = widget.memo;
    final d = memo.createdAt;
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final dayStr = weekdays[d.weekday - 1];

    final buf = StringBuffer();
    buf.writeln('$dateStr $dayStr  ${memo.timeStr}');
    buf.writeln('─' * 30);
    buf.writeln();
    buf.writeln(memo.content);

    final tags = memo.tags;
    if (tags.isNotEmpty) {
      buf.writeln();
      buf.write(tags.map((t) => '#$t').join('  '));
    }

    if (memo.appendNotes.isNotEmpty) {
      buf.writeln();
      for (final note in memo.appendNotes) {
        final nt = note.addedAt;
        final ts =
            '${nt.hour.toString().padLeft(2, '0')}:${nt.minute.toString().padLeft(2, '0')}';
        buf.writeln();
        buf.write('∟ $ts  ${note.content}');
      }
    }

    return buf.toString().trim();
  }

  void _shareMemo() {
    Share.share(_buildShareText());
  }

  void _showTextSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      isScrollControlled: true,
      builder: (ctx) {
        final notes = widget.memo.appendNotes;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.memo.timeStr,
                      style: mono(color: kDim, fontSize: 11),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Text('×', style: mono(color: kDim, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: kBorder),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectionArea(
                          child: _buildRichContent(widget.memo.content),
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ...notes.map((n) {
                            final t = n.addedAt;
                            final ts =
                                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '∟ $ts',
                                    style: mono(color: kDim, fontSize: 10),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    n.content,
                                    style: mono(
                                      color: kText,
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Image pick (edit mode) ───────────────────────────

  Future<void> _pickImageInEdit() async {
    if (kIsWeb) return;
    final source = await _showImageSourceSheet();
    if (source == null) return;

    if (widget.memo.imagePaths.length >= ImageService.maxImagesPerMemo) {
      _showSnack('이미지는 최대 10개까지 첨부할 수 있습니다');
      return;
    }

    if (source == ImageSource.gallery) {
      final result = await ImageService.pickManyFromGallery(
        remainingSlots:
            ImageService.maxImagesPerMemo - widget.memo.imagePaths.length,
      );
      if (!mounted) return;
      for (final path in result.paths) {
        _a.onAddImage(widget.memo, path);
      }
      if (result.rejectedCount > 0) {
        _showSnack('일부 이미지는 용량이 커서 첨부하지 못했습니다');
      }
      return;
    }

    final path = await ImageService.pick(source);
    if (!mounted) return;
    if (path == '__TOO_LARGE__') {
      _showSnack('이미지 용량이 너무 커서 첨부하지 못했습니다');
      return;
    }
    if (path != null) _a.onAddImage(widget.memo, path);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kSurface,
        duration: const Duration(seconds: 2),
        content: Text(message, style: mono(color: kText, fontSize: 12)),
      ),
    );
  }

  Future<ImageSource?> _showImageSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이미지 추가',
                    style: mono(color: kMint, fontSize: 13, letterSpacing: 1),
                  ),
                  const SizedBox(height: 12),
                  Container(height: 1, color: kBorder),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _SheetBtn(
                        label: '갤러리',
                        onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                      ),
                      const SizedBox(width: 12),
                      _SheetBtn(
                        label: '카메라',
                        onTap: () => Navigator.pop(ctx, ImageSource.camera),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Reminder ─────────────────────────────────────────

  void _showReminderDialog() {
    showScheduleSheet(
      context,
      mode: ScheduleSheetMode.reminder,
      current: widget.memo.reminderAt,
      currentRepeat: widget.memo.reminderRepeat,
      repeatEndType: widget.memo.repeatEndType,
      repeatEndCount: widget.memo.repeatEndCount,
      repeatEndDate: widget.memo.repeatEndDate,
      onResult: (dt, repeat, _, endType, endCount, endDate, __) =>
          _a.onSetReminder(widget.memo, dt, repeat, endType, endCount, endDate),
    );
  }

  void _showScheduleDialog() {
    showScheduleSheet(
      context,
      mode: ScheduleSheetMode.event,
      current: widget.memo.scheduledAt,
      rangeEndDate: widget.memo.rangeEndDate,
      currentRepeat: widget.memo.scheduleRepeat,
      repeatEndType: widget.memo.repeatEndType,
      repeatEndCount: widget.memo.repeatEndCount,
      repeatEndDate: widget.memo.repeatEndDate,
      initialNotifyForEvent: _isSameMinute(
        widget.memo.reminderAt,
        widget.memo.scheduledAt,
      ),
      onResult:
          (dt, repeat, rangeEnd, endType, endCount, endDate, notifyForEvent) {
            _a.onSetSchedule(
              widget.memo,
              dt,
              repeat,
              rangeEnd,
              endType,
              endCount,
              endDate,
            );
            if (dt == null) {
              if (_isSameMinute(
                widget.memo.reminderAt,
                widget.memo.scheduledAt,
              )) {
                _a.onSetReminder(
                  widget.memo,
                  null,
                  'none',
                  'infinite',
                  5,
                  null,
                );
              }
            } else if (notifyForEvent) {
              _a.onSetReminder(widget.memo, dt, 'none', 'infinite', 5, null);
            } else if (_isSameMinute(
              widget.memo.reminderAt,
              widget.memo.scheduledAt,
            )) {
              _a.onSetReminder(widget.memo, null, 'none', 'infinite', 5, null);
            }
          },
    );
  }

  bool _isSameMinute(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }

  // ── Dialogs ─────────────────────────────────────────

  void _showFolderPicker() {
    final others = _a.folders
        .where((f) => f.id != widget.memo.folderId)
        .toList();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 280,
            maxHeight: MediaQuery.of(ctx).size.height * 0.6,
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MOVE TO',
                style: mono(color: kMint, fontSize: 13, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Container(height: 1, color: kBorder),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    if (widget.memo.folderId != null)
                      _PickerRow(
                        label: 'inbox',
                        onTap: () {
                          Navigator.pop(ctx);
                          _a.onMove(widget.memo, null);
                        },
                      ),
                    ...others.map(
                      (f) => _PickerRow(
                        label: f.name,
                        onTap: () {
                          Navigator.pop(ctx);
                          _a.onMove(widget.memo, f.id);
                        },
                      ),
                    ),
                    if (widget.memo.folderId == null && others.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '이동할 폴더가 없습니다',
                          style: mono(color: kDim, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: _ActionBtn(
                  label: '취소',
                  color: kDim,
                  onTap: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyRow(DateTime t, String label) {
    final ts =
        '${t.hour.toString().padLeft(2, '0')}'
        ':${t.minute.toString().padLeft(2, '0')}'
        ':${t.second.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(ts, style: mono(color: kDim, fontSize: 11)),
          const SizedBox(width: 10),
          Text(label, style: mono(color: kText, fontSize: 11)),
        ],
      ),
    );
  }

  // ── Drag feedback ────────────────────────────────────

  String _fmtReminder(DateTime dt) {
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$mo/$d $hh:$mm';
  }

  static String repeatLabel(String repeat) {
    switch (repeat) {
      case 'daily':
        return ' ↻매일';
      case 'weekly':
        return ' ↻매주';
      case 'monthly':
        return ' ↻매월';
      default:
        return '';
    }
  }

  String _stripExtraPrefixes(String text) {
    String t = text.trim();
    bool changed = true;
    while (changed) {
      changed = false;
      if (t.startsWith('- [x] ')) {
        t = t.substring(6).trim();
        changed = true;
      } else if (t.startsWith('- [ ] ')) {
        t = t.substring(6).trim();
        changed = true;
      } else if (t.startsWith('• ')) {
        t = t.substring(2).trim();
        changed = true;
      }
    }
    return t;
  }

  bool get _hasChecklistLines =>
      widget.memo.isChecklist ||
      widget.memo.content.split('\n').any((l) => _checkRe.hasMatch(l.trim()));

  String get _memoPreview {
    final firstLine = widget.memo.content.split('\n').first;
    return firstLine
        .replaceAll(_tagRe, '')
        .replaceAll(RegExp(r'^- \[[ x]\] '), '')
        .replaceAll(RegExp(r'^• '), '')
        .trim();
  }

  Widget _buildDragFeedback() {
    final preview = _memoPreview;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kMint.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.memo.timeStr, style: mono(color: kDim, fontSize: tsMeta)),
            const SizedBox(height: 3),
            Text(
              preview.isEmpty ? '...' : preview,
              style: mono(color: kText, fontSize: tsSmall),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isEditing) return _buildEditMode();

    final inner = ClipRect(
      child: GestureDetector(
        onHorizontalDragUpdate: _onSwipeUpdate,
        onHorizontalDragEnd: _onSwipeEnd,
        child: Stack(
          children: [
            // Left: folder move indicator
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 75,
                  color: kMint.withValues(alpha: 0.12),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Text('이동', style: mono(color: kMint, fontSize: 12)),
                ),
              ),
            ),
            // Right: delete button
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _onDeleteBtnTap,
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.noScaling),
                    child: Container(
                      width: 75,
                      color: Colors.red.shade700,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: Text(
                        '삭제',
                        style: mono(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Main content
            Transform.translate(
              offset: Offset(_swipeOffset, 0),
              child: Container(
                color: kBg,
                child: LongPressDraggable<Memo>(
                  data: widget.memo,
                  delay: const Duration(milliseconds: 400),
                  feedback: _buildDragFeedback(),
                  childWhenDragging: Opacity(
                    opacity: 0.4,
                    child: _buildViewMode(),
                  ),
                  child: _buildViewMode(),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final withTapRegion = TapRegion(
      onTapOutside: (_) {
        if (_deleteRevealed) {
          setState(() {
            _swipeOffset = 0;
            _deleteRevealed = false;
          });
        }
      },
      child: inner,
    );

    if (_isSystemMemo) return withTapRegion;

    return DragTarget<Memo>(
      onWillAcceptWithDetails: (details) =>
          details.data.id != widget.memo.id &&
          !details.data.tags.any((t) => t == 'habit' || t == 'goal'),
      onAcceptWithDetails: (details) => _a.onMerge(details.data, widget.memo),
      builder: (context, candidateData, _) {
        if (candidateData.isEmpty) return withTapRegion;
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: kMint.withValues(alpha: 0.7), width: 1.5),
            color: kMint.withValues(alpha: 0.05),
          ),
          child: withTapRegion,
        );
      },
    );
  }

  // ── View mode ────────────────────────────────────────

  Widget _buildViewMode() {
    final tags = widget.memo.tags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onLongPress: _showTextSelectionSheet,
            onTapDown: (d) => _tapPosition = d.globalPosition,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              color: widget.highlighted
                  ? kMint.withValues(alpha: 0.08)
                  : (_hovered ? kSurface : Colors.transparent),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: timestamp + event/task labels + controls
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              widget.memo.timeStr,
                              style: mono(color: kDim, fontSize: tsMeta),
                            ),
                            ...tags.map(
                              (t) => GestureDetector(
                                onTap: () => _a.onTagTap?.call(t),
                                child: Text(
                                  '#$t',
                                  style: mono(color: kTeal, fontSize: tsSmall),
                                ),
                              ),
                            ),
                            if (widget.memo.scheduledAt != null)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onDoubleTap: _showScheduleDialog,
                                child: RichText(
                                  text: TextSpan(
                                    style: mono(fontSize: tsMeta),
                                    children: [
                                      TextSpan(
                                        text: 'event ',
                                        style: mono(color: kTeal, fontSize: tsMeta),
                                      ),
                                      TextSpan(
                                        text: _fmtReminder(
                                          widget.memo.scheduledAt!,
                                        ),
                                        style: mono(color: kDim, fontSize: tsMeta),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (widget.memo.reminderAt != null)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onDoubleTap: _showReminderDialog,
                                child: RichText(
                                  text: TextSpan(
                                    style: mono(fontSize: tsMeta),
                                    children: [
                                      TextSpan(
                                        text: 'task ',
                                        style: mono(color: kMint, fontSize: tsMeta),
                                      ),
                                      TextSpan(
                                        text:
                                            '${_fmtReminder(widget.memo.reminderAt!)}${repeatLabel(widget.memo.reminderRepeat)}',
                                        style: mono(color: kDim, fontSize: tsMeta),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: TextScaler.noScaling),
                        child: GestureDetector(
                          onTap: _startEditing,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Text(
                              '수정',
                              style: mono(
                                color: _hovered
                                    ? kDim
                                    : kDim.withValues(alpha: 0.45),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Content area — event items get a left ┃ border
                  if (widget.memo.scheduledAt != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '┃ ',
                          style: mono(
                            color: kTeal.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: _hasChecklistLines
                              ? _buildChecklistContent()
                              : _buildRichContent(widget.memo.content),
                        ),
                      ],
                    )
                  else if (_hasChecklistLines)
                    _buildChecklistContent()
                  else
                    _buildRichContent(widget.memo.content),
                  // Image thumbnails
                  if (!kIsWeb && widget.memo.imagePaths.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildImageThumbnails(),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Append notes cards
        if (widget.memo.appendNotes.isNotEmpty)
          Container(
            color: kBg,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Column(
              children: widget.memo.appendNotes
                  .asMap()
                  .entries
                  .map((e) => _buildNoteCard(e.value, e.key))
                  .toList(),
            ),
          ),
        // [+ 추가] button or inline input
        if (_isAddingNote) _buildAddNoteInput() else _buildAddNoteBtn(),
        // Source URL badge
        if (widget.memo.sourceUrl != null)
          _SourceBadge(url: widget.memo.sourceUrl!),
        // Related memos
        _buildRelatedMemos(),
        // Dotted separator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '- ' * 80,
            style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 9),
            overflow: TextOverflow.clip,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ],
    );
  }

  // ── Append note UI ────────────────────────────────────

  Widget _buildNoteCard(AppendNote note, int index) {
    final t = note.addedAt;
    final timeStr =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

    if (_editingNoteIndex == index) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.only(left: 14, top: 6, bottom: 6, right: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '∟ $timeStr',
              style: mono(color: kDim, fontSize: tsMeta, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _editNoteController,
              focusNode: _editNoteFocusNode,
              style: mono(fontSize: 12, height: 1.5, color: kText),
              maxLines: 5,
              minLines: 1,
              cursorColor: kMint,
              cursorWidth: 2,
              decoration: InputDecoration(
                hintText: '내용 수정...',
                hintStyle: mono(
                  color: kDim.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionBtn(label: '저장', color: kMint, onTap: _saveNoteEdit),
                const SizedBox(width: 6),
                _ActionBtn(
                  label: '취소',
                  color: kDim,
                  onTap: () => setState(() {
                    _editingNoteIndex = -1;
                    _editNoteController.clear();
                  }),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onDoubleTap: () => _startNoteEdit(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.only(left: 14, top: 4, bottom: 4, right: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '∟ $timeStr',
                  style: mono(color: kDim, fontSize: tsMeta, letterSpacing: 0.5),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _confirmDeleteNote(index),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      '×',
                      style: mono(
                        color: kDim.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: mono(color: kText, fontSize: tsSmall)),
                Expanded(
                  child: Text(
                    note.content,
                    style: mono(color: kText, fontSize: tsSmall, height: 1.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNoteBtn() {
    return Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              setState(() => _isAddingNote = true);
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _noteFocusNode.requestFocus(),
              );
            },
            child: Text(
              '+ 추가',
              style: mono(
                color: widget.memo.appendNotes.isNotEmpty
                    ? kTeal
                    : kDim.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddNoteInput() {
    return Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: kBorder),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _noteController,
              focusNode: _noteFocusNode,
              style: mono(fontSize: 12, height: 1.5, color: kText),
              maxLines: 5,
              minLines: 1,
              cursorColor: kMint,
              cursorWidth: 2,
              decoration: InputDecoration(
                hintText: '추가할 내용을 입력하세요...',
                hintStyle: mono(
                  color: kDim.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionBtn(label: '저장', color: kMint, onTap: _saveNote),
                const SizedBox(width: 8),
                _ActionBtn(
                  label: '취소',
                  color: kDim,
                  onTap: () => setState(() {
                    _isAddingNote = false;
                    _noteController.clear();
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Checklist content ─────────────────────────────────

  Widget _buildChecklistContent() {
    final lines = widget.memo.content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...lines.asMap().entries.where((e) => e.value.isNotEmpty).map((e) {
          final clean = e.value.replaceAll(_tagRe, '').trim();
          if (clean.isEmpty) return const SizedBox.shrink();
          if (clean.startsWith('- [x] ')) {
            return _buildChecklistItemRow(
              _stripExtraPrefixes(clean.substring(6)),
              true,
              e.key,
            );
          }
          if (clean.startsWith('- [ ] ')) {
            return _buildChecklistItemRow(
              _stripExtraPrefixes(clean.substring(6)),
              false,
              e.key,
            );
          }
          if (clean.startsWith('• ')) {
            return _buildBulletItemRow(
              _stripExtraPrefixes(clean.substring(2)),
              e.key,
            );
          }
          // 일반 텍스트는 그대로 렌더링
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text.rich(
              _parseInline(
                clean,
                mono(color: kText, fontSize: tsBody, height: 1.55),
              ),
            ),
          );
        }),
        if (_checkItemInputVisible) _buildAddItemRow() else _buildAddItemBtn(),
      ],
    );
  }

  Widget _buildBulletItemRow(String text, int lineIndex) {
    if (_editingCheckIndex == lineIndex) {
      return _buildCheckItemEditRow(lineIndex);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: mono(color: kText, fontSize: tsBody)),
          Expanded(
            child: GestureDetector(
              onTap: () => _startEditingCheckItem(lineIndex, text),
              child: Text.rich(
                _parseInline(
                  text,
                  mono(color: kText, fontSize: tsBody, height: 1.5),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _deleteChecklistItem(lineIndex),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '×',
                  style: mono(
                    color: _hovered ? kDim : kDim.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItemRow(String text, bool checked, int lineIndex) {
    if (_editingCheckIndex == lineIndex) {
      return _buildCheckItemEditRow(lineIndex);
    }
    final textStyle =
        mono(
          color: checked ? _memoDoneTextColor() : kText,
          fontSize: tsBody,
          height: 1.5,
        ).copyWith(
          decoration: checked ? TextDecoration.lineThrough : null,
          decorationColor: _memoDoneAccentColor(),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleCheck(lineIndex),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Text(
                  checked ? '✓ ' : '□ ',
                  style: mono(
                    color: checked ? _memoDoneAccentColor() : kMint,
                    fontSize: tsBody,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleCheck(lineIndex),
              onLongPress: () => _startEditingCheckItem(lineIndex, text),
              child: Text.rich(_parseInline(text, textStyle)),
            ),
          ),
          GestureDetector(
            onTap: () => _deleteChecklistItem(lineIndex),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '×',
                  style: mono(
                    color: _hovered ? kDim : kDim.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItemEditRow(int lineIndex) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _editCheckController,
              focusNode: _editCheckFocusNode,
              style: mono(fontSize: 13, color: kText, height: 1.5),
              maxLines: 1,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveCheckItem(),
              cursorColor: kMint,
              cursorWidth: 2,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                filled: true,
                fillColor: kSurface,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: kMint),
                  borderRadius: BorderRadius.zero,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: kMint.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.zero,
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: kMint),
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _saveCheckItem,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text('OK', style: mono(color: kMint, fontSize: 11)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _cancelCheckEdit,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text('×', style: mono(color: kDim, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddItemBtn() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        onTap: () {
          setState(() => _checkItemInputVisible = true);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _addItemFocusNode.requestFocus(),
          );
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Text(
            '+ 항목 추가',
            style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildAddItemRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text(
            '>_ ',
            style: mono(
              color: kTeal.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _addItemController,
              focusNode: _addItemFocusNode,
              style: mono(fontSize: 12, color: kText),
              maxLines: 1,
              textInputAction: TextInputAction.done,
              onSubmitted: _addChecklistItem,
              cursorColor: kMint,
              cursorWidth: 2,
              decoration: InputDecoration(
                hintText: 'add item...',
                hintStyle: mono(
                  color: kDim.withValues(alpha: 0.35),
                  fontSize: 12,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
                isDense: true,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _addChecklistItem(_addItemController.text),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('+', style: mono(color: kTeal, fontSize: 11)),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              _addItemController.clear();
              setState(() => _checkItemInputVisible = false);
              FocusScope.of(context).unfocus();
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  '×',
                  style: mono(color: kDim.withValues(alpha: 0.6), fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Image thumbnails ─────────────────────────────────

  Widget _buildImageThumbnails() {
    final paths = widget.memo.imagePaths;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(paths.length, (i) {
            final file = File(paths[i]);
            return GestureDetector(
              onTap: () => _openImageViewer(paths, i),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                width: 72,
                constraints: const BoxConstraints(minHeight: 72),
                decoration: BoxDecoration(
                  border: Border.all(color: kBorder.withValues(alpha: 0.6)),
                ),
                child: file.existsSync()
                    ? Image.file(file, fit: BoxFit.cover)
                    : Container(
                        color: kSurface,
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 20,
                          color: kDim,
                        ),
                      ),
              ),
            );
          }),
        ),
      ),
    );
  }

  void _openImageViewer(List<String> paths, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) =>
          _ImageViewerDialog(paths: paths, initialIndex: initialIndex),
    );
  }

  // ── Inline markdown parser ────────────────────────────

  static final _inlineRe = RegExp(
    r'\*\*(.+?)\*\*|~~(.+?)~~|\*(.+?)\*|(https?://\S+)|\[\[(.+?)\]\]',
    dotAll: false,
  );

  TextSpan _parseInline(String text, TextStyle base) {
    final children = <InlineSpan>[];
    int lastEnd = 0;
    for (final m in _inlineRe.allMatches(text)) {
      if (m.start > lastEnd) {
        children.add(TextSpan(text: text.substring(lastEnd, m.start)));
      }
      if (m.group(1) != null) {
        children.add(
          TextSpan(
            text: m.group(1),
            style: base.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (m.group(2) != null) {
        children.add(
          TextSpan(
            text: m.group(2),
            style: base.copyWith(
              decoration: TextDecoration.lineThrough,
              decorationColor: base.color,
            ),
          ),
        );
      } else if (m.group(3) != null) {
        children.add(
          TextSpan(
            text: m.group(3),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (m.group(4) != null) {
        final url = m.group(4)!;
        final rec = TapGestureRecognizer()
          ..onTap = () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        children.add(
          TextSpan(
            text: url,
            style: base.copyWith(color: kTeal),
            recognizer: rec,
          ),
        );
      } else if (m.group(5) != null) {
        final linkText = m.group(5)!;
        final rec = TapGestureRecognizer()
          ..onTap = () => _a.onWikiLinkTap?.call(linkText);
        children.add(
          TextSpan(
            text: '[[${linkText}]]',
            style: base.copyWith(
              color: kMint,
              decoration: TextDecoration.underline,
              decorationColor: kMint.withValues(alpha: 0.5),
            ),
            recognizer: rec,
          ),
        );
      }
      lastEnd = m.end;
    }
    if (lastEnd < text.length) {
      children.add(TextSpan(text: text.substring(lastEnd)));
    }
    if (children.isEmpty) return TextSpan(text: text, style: base);
    return TextSpan(children: children, style: base);
  }

  Widget _buildRelatedMemos() {
    if (widget.allMemos.isEmpty) return const SizedBox.shrink();
    final others = widget.allMemos.where((m) => m.id != widget.memo.id).toList();
    final related = LocalSearchService.search(widget.memo.content, others, limit: 3);
    if (related.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: kBorder.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'related',
            style: mono(color: kDim, fontSize: 9, letterSpacing: 0.8),
          ),
          const SizedBox(height: 5),
          ...related.map((m) {
            final preview = m.content.split('\n').first;
            final short = preview.length > 60 ? '${preview.substring(0, 60)}…' : preview;
            return GestureDetector(
              onTap: () => _a.onNavigateToMemo?.call(m.id),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '→ $short',
                  style: mono(color: kMint.withValues(alpha: 0.8), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRichContent(String content) {
    final base = mono(color: kText, fontSize: tsBody, height: 1.55);
    final lines = content.replaceAll(_tagRe, '').split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return const SizedBox(height: 4);
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text.rich(_parseInline(trimmed, base)),
        );
      }).toList(),
    );
  }

  // ── Edit mode ────────────────────────────────────────

  Widget _buildEditMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toolbar row
        MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 3, 6, 3),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: kBorder.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _EditFmtBtn(
                  label: 'B',
                  bold: true,
                  onTap: () => _wrapEdit('**', '**'),
                ),
                _EditFmtBtn(
                  label: 'I',
                  italic: true,
                  onTap: () => _wrapEdit('*', '*'),
                ),
                _EditFmtBtn(
                  label: 'S',
                  strike: true,
                  onTap: () => _wrapEdit('~~', '~~'),
                ),
                Container(
                  width: 1,
                  height: 14,
                  color: kBorder.withValues(alpha: 0.6),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                ),
                _EditIconBtn(
                  icon: Icons.check_box_outline_blank,
                  tooltip: '체크박스',
                  onTap: () => _insertEditListPrefix('- [ ] '),
                ),
                _EditIconBtn(
                  icon: Icons.format_list_bulleted,
                  tooltip: '불릿',
                  onTap: () => _insertEditListPrefix('• '),
                ),
                _EditIconBtn(
                  icon: Icons.tag,
                  tooltip: '태그',
                  onTap: () => _insertEditText('#'),
                ),
                _EditIconBtn(
                  icon: Icons.calendar_today,
                  tooltip: '알림',
                  active: widget.memo.reminderAt != null,
                  onTap: _showReminderDialog,
                ),
                if (!kIsWeb)
                  _EditIconBtn(
                    icon: Icons.image_outlined,
                    tooltip: '이미지',
                    onTap: _pickImageInEdit,
                  ),
                const Spacer(),
                _ActionBtn(
                  label: '취소',
                  color: kDim,
                  onTap: _cancelEdit,
                  fontSize: 8,
                ),
                const SizedBox(width: 2),
                _ActionBtn(
                  label: '확인',
                  color: kMint,
                  onTap: _saveEdit,
                  fontSize: 8,
                ),
              ],
            ),
          ),
        ),
        // Time + text field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.memo.timeStr, style: mono(color: kDim, fontSize: tsMeta)),
              const SizedBox(height: 6),
              TextField(
                controller: _editController,
                focusNode: _editFocusNode,
                style: mono(fontSize: tsBody, height: 1.6),
                maxLines: null,
                cursorColor: kMint,
                cursorWidth: 2,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: kSurface,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: kMint),
                    borderRadius: BorderRadius.zero,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: kMint),
                    borderRadius: BorderRadius.zero,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: kMint, width: 1.5),
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _addItemController.removeListener(_onAddItemChanged);
    _editController.dispose();
    _editFocusNode.dispose();
    _addItemController.dispose();
    _addItemFocusNode.dispose();
    _noteController.dispose();
    _noteFocusNode.dispose();
    _editNoteController.dispose();
    _editNoteFocusNode.dispose();
    _editCheckController.dispose();
    _editCheckFocusNode.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────
// Folder picker row
// ─────────────────────────────────────────────────────────────────

class _PickerRow extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _PickerRow({required this.label, required this.onTap});

  @override
  State<_PickerRow> createState() => _PickerRowState();
}

class _PickerRowState extends State<_PickerRow> {
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
          color: _hovered ? kBorder.withValues(alpha: 0.2) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Text('‣ ', style: mono(color: kDim, fontSize: 11)),
              Expanded(
                child: Text(
                  widget.label,
                  style: mono(color: kText, fontSize: 12),
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

// ─────────────────────────────────────────────────────────────────
// Action button (SAVE / CANCEL / CLOSE)
// ─────────────────────────────────────────────────────────────────

class _ActionBtn extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double fontSize;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
    this.fontSize = 10,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Text(
            widget.label,
            style: mono(color: widget.color, fontSize: widget.fontSize),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Edit mode toolbar buttons
// ─────────────────────────────────────────────────────────────────

class _EditFmtBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool bold;
  final bool italic;
  final bool strike;

  const _EditFmtBtn({
    required this.label,
    required this.onTap,
    this.bold = false,
    this.italic = false,
    this.strike = false,
  });

  @override
  State<_EditFmtBtn> createState() => _EditFmtBtnState();
}

class _EditFmtBtnState extends State<_EditFmtBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          color: _hovered ? kSurface : Colors.transparent,
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

class _EditIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final String? tooltip;

  const _EditIconBtn({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.tooltip,
  });

  @override
  State<_EditIconBtn> createState() => _EditIconBtnState();
}

class _EditIconBtnState extends State<_EditIconBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          color: widget.active
              ? kMint.withValues(alpha: 0.1)
              : (_hovered ? kSurface : Colors.transparent),
          child: Icon(widget.icon, size: 15, color: color),
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
// Source URL badge
// ─────────────────────────────────────────────────────────────────

class _SourceBadge extends StatefulWidget {
  final String url;
  const _SourceBadge({required this.url});

  @override
  State<_SourceBadge> createState() => _SourceBadgeState();
}

class _SourceBadgeState extends State<_SourceBadge> {
  bool _hovered = false;

  String get _displayUrl {
    try {
      final uri = Uri.parse(widget.url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return widget.url.length > 40
          ? '${widget.url.substring(0, 40)}...'
          : widget.url;
    }
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: _open,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _hovered
                  ? kTeal.withValues(alpha: 0.12)
                  : kTeal.withValues(alpha: 0.06),
              border: Border.all(
                color: kTeal.withValues(alpha: _hovered ? 0.5 : 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('↗ ', style: mono(color: kTeal, fontSize: 10)),
                Flexible(
                  child: Text(
                    _displayUrl,
                    style: mono(color: kTeal, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
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
// Full-screen image viewer
// ─────────────────────────────────────────────────────────────────

class _ImageViewerDialog extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const _ImageViewerDialog({required this.paths, required this.initialIndex});

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  late int _index;
  late PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final path = widget.paths[_index];
    if (!File(path).existsSync()) return;
    await Share.shareXFiles([XFile(path)]);
  }

  Future<void> _saveToGallery() async {
    final path = widget.paths[_index];
    final ok = await ImageService.saveToGallery(path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kSurface,
        duration: const Duration(seconds: 2),
        content: Text(
          ok ? '이미지를 저장했습니다' : '이미지 저장에 실패했습니다',
          style: mono(color: ok ? kText : Colors.red.shade300, fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Image pager
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.paths.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (ctx, i) {
              final file = File(widget.paths[i]);
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: file.existsSync()
                      ? Image.file(file, fit: BoxFit.contain)
                      : Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: kDim,
                        ),
                ),
              );
            },
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    if (widget.paths.length > 1)
                      Text(
                        '${_index + 1} / ${widget.paths.length}',
                        style: mono(color: Colors.white70, fontSize: 11),
                      ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _saveToGallery,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          '저장',
                          style: mono(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _share,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          '공유',
                          style: mono(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        color: Colors.black45,
                        child: Text(
                          '×',
                          style: mono(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Image source sheet button
// ─────────────────────────────────────────────────────────────────

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
          child: Text(
            widget.label,
            style: mono(color: _hovered ? kMint : kDim, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
