import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/memo.dart';
import '../models/folder.dart';
import '../models/append_note.dart';
import '../app_theme.dart';
import 'reminder_dialog.dart';

class MemoTile extends StatefulWidget {
  final Memo memo;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onUpdate;
  final void Function(String? folderId)? onMove;
  final void Function(DateTime?)? onSetReminder;
  final void Function(String content)? onAddNote;
  final void Function(int index, String content)? onUpdateNote;
  final void Function(int index)? onDeleteNote;
  final List<Folder> folders;
  final bool highlighted; // brief highlight on notification-tap navigation
  final void Function(String tag)? onTagTap;

  const MemoTile({
    super.key,
    required this.memo,
    this.onDelete,
    this.onUpdate,
    this.onMove,
    this.onSetReminder,
    this.onAddNote,
    this.onUpdateNote,
    this.onDeleteNote,
    this.folders = const [],
    this.highlighted = false,
    this.onTagTap,
  });

  @override
  State<MemoTile> createState() => _MemoTileState();
}

class _MemoTileState extends State<MemoTile> {
  bool _hovered = false;
  bool _isEditing = false;
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

  static const _kDeleteSnap = -72.0;
  static const _kDeleteThreshold = -52.0;
  static const _kMoveThreshold = 52.0;

  // Only match # preceded by whitespace or at start — avoids URL fragments like #section
  static final _tagRe = RegExp(r'(?<![^\s])#[a-zA-Zㄱ-ㅎㅏ-ㅣ가-힣][a-zA-Z0-9_ㄱ-ㅎㅏ-ㅣ가-힣]*');
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
          setState(() { _isAddingNote = false; _noteController.clear(); });
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
          setState(() { _editingNoteIndex = -1; _editNoteController.clear(); });
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
    if (text.isNotEmpty) widget.onAddNote?.call(text);
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
      _editNoteController.selection =
          TextSelection.collapsed(offset: _editNoteController.text.length);
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _editNoteFocusNode.requestFocus());
  }

  void _saveNoteEdit() {
    final text = _editNoteController.text.trim();
    if (text.isNotEmpty) widget.onUpdateNote?.call(_editingNoteIndex, text);
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
              Text('[ DELETE NOTE ]',
                  style: mono(color: kMint, fontSize: 13, letterSpacing: 1)),
              const SizedBox(height: 10),
              Container(height: 1, color: kBorder),
              const SizedBox(height: 12),
              Text('"$preview"',
                  style: mono(color: kDim, fontSize: 12, height: 1.6)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionBtn(
                      label: '[ CANCEL ]',
                      color: kDim,
                      onTap: () => Navigator.pop(ctx)),
                  const SizedBox(width: 10),
                  _ActionBtn(
                    label: '[ DELETE ]',
                    color: Colors.red.shade400,
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onDeleteNote?.call(index);
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
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
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
    widget.onUpdate?.call(newContent);
    _addItemController.clear();
    setState(() => _checkItemInputVisible = false);
    FocusScope.of(context).unfocus();
  }

  void _deleteChecklistItem(int lineIndex) {
    final lines = widget.memo.content.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return;
    lines.removeAt(lineIndex);
    widget.onUpdate?.call(lines.join('\n'));
  }

  void _startEditingCheckItem(int lineIndex, String currentText) {
    setState(() {
      _editingCheckIndex = lineIndex;
      _editCheckController.text = currentText;
      _editCheckController.selection =
          TextSelection.collapsed(offset: currentText.length);
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _editCheckFocusNode.requestFocus());
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
        if (old.startsWith('- [x] ')) prefix = '- [x] ';
        else if (old.startsWith('• ')) prefix = '• ';
        lines[idx] = '$prefix$trimmed';
        widget.onUpdate?.call(lines.join('\n'));
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
      setState(() { _swipeOffset = 0; _deleteRevealed = false; });
      return;
    }
    setState(() {
      _isEditing = true;
      _editController.text = widget.memo.content;
      _editController.selection =
          TextSelection.collapsed(offset: _editController.text.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _editFocusNode.requestFocus());
  }

  String _reorderChecklistFirst(String content) {
    final lines = content.split('\n');
    final listLines = lines.where((l) =>
        l.startsWith('- [ ] ') || l.startsWith('- [x] ') || l.startsWith('• ')).toList();
    final plainLines = lines.where((l) =>
        !l.startsWith('- [ ] ') && !l.startsWith('- [x] ') && !l.startsWith('• ')).toList();
    if (listLines.isEmpty || plainLines.isEmpty) return content;
    return [...listLines, ...plainLines].join('\n');
  }

  void _saveEdit() {
    final raw = _editController.text.trim();
    final newContent = _reorderChecklistFirst(raw);
    if (newContent.isNotEmpty) widget.onUpdate?.call(newContent);
    setState(() => _isEditing = false);
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
    widget.onUpdate?.call(lines.join('\n'));
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
      setState(() { _swipeOffset = _kDeleteSnap; _deleteRevealed = true; });
    } else if (_swipeOffset >= _kMoveThreshold) {
      setState(() => _swipeOffset = 0);
      _showFolderPicker();
    } else {
      setState(() { _swipeOffset = 0; _deleteRevealed = false; });
    }
  }

  void _onDeleteBtnTap() {
    setState(() { _swipeOffset = 0; _deleteRevealed = false; });
    widget.onDelete?.call();
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
        buf.write('∟ [$ts]  ${note.content}');
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
                    Text('[${widget.memo.timeStr}]',
                        style: mono(color: kDim, fontSize: 11)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Text('[×]', style: mono(color: kDim, fontSize: 11)),
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
                        SelectionArea(child: _buildRichContent(widget.memo.content)),
                          if (notes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ...notes.map((n) {
                              final t = n.addedAt;
                              final ts =
                                  '[${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}]';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('∟ $ts',
                                        style: mono(color: kDim, fontSize: 10)),
                                    const SizedBox(height: 2),
                                    Text(n.content,
                                        style: mono(color: kText, fontSize: 12, height: 1.5)),
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

  Future<void> _showContextMenu() async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        _tapPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      color: kSurface,
      elevation: 3,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      items: [
        PopupMenuItem<String>(
          value: 'share',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('[ 공유 ]', style: mono(color: kText, fontSize: 12)),
        ),
      ],
    );
    if (result == 'share') _shareMemo();
  }

  // ── Reminder ─────────────────────────────────────────

  void _showReminderDialog() {
    showDialog(
      context: context,
      builder: (_) => ReminderDialog(
        current: widget.memo.reminderAt,
        onResult: (dt) => widget.onSetReminder?.call(dt),
      ),
    );
  }

  // ── Dialogs ─────────────────────────────────────────

  void _showFolderPicker() {
    final others = widget.folders.where((f) => f.id != widget.memo.folderId).toList();
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
              Text('[ MOVE TO ]',
                  style: mono(color: kMint, fontSize: 13, letterSpacing: 1)),
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
                        onTap: () { Navigator.pop(ctx); widget.onMove?.call(null); },
                      ),
                    ...others.map((f) => _PickerRow(
                          label: f.name,
                          onTap: () { Navigator.pop(ctx); widget.onMove?.call(f.id); },
                        )),
                    if (widget.memo.folderId == null && others.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('이동할 폴더가 없습니다',
                            style: mono(color: kDim, fontSize: 11)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: _ActionBtn(
                    label: '[ CANCEL ]',
                    color: kDim,
                    onTap: () => Navigator.pop(ctx)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistory() {
    final history = widget.memo.editHistory;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('[ HISTORY ]',
                  style: mono(color: kMint, fontSize: 13, letterSpacing: 1)),
              const SizedBox(height: 10),
              Container(height: 1, color: kBorder),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _historyRow(widget.memo.createdAt, '작성'),
                      ...history.map((t) => _historyRow(t, '수정')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: kBorder),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: _ActionBtn(
                    label: '[ CLOSE ]',
                    color: kDim,
                    onTap: () => Navigator.pop(ctx)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyRow(DateTime t, String label) {
    final ts = '${t.hour.toString().padLeft(2, '0')}'
        ':${t.minute.toString().padLeft(2, '0')}'
        ':${t.second.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('[$ts]', style: mono(color: kDim, fontSize: 11)),
          const SizedBox(width: 10),
          Text(label, style: mono(color: kText, fontSize: 11)),
        ],
      ),
    );
  }

  // ── Drag feedback ────────────────────────────────────

  String _fmtReminder(DateTime dt) {
    final mo = dt.month.toString().padLeft(2, '0');
    final d  = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$mo/$d $hh:$mm';
  }

  String _stripExtraPrefixes(String text) {
    String t = text.trim();
    bool changed = true;
    while (changed) {
      changed = false;
      if (t.startsWith('- [x] '))      { t = t.substring(6).trim(); changed = true; }
      else if (t.startsWith('- [ ] ')) { t = t.substring(6).trim(); changed = true; }
      else if (t.startsWith('• '))     { t = t.substring(2).trim(); changed = true; }
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
            Text('[${widget.memo.timeStr}]', style: mono(color: kDim, fontSize: 10)),
            const SizedBox(height: 3),
            Text(
              preview.isEmpty ? '...' : preview,
              style: mono(color: kText, fontSize: 11),
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

    return ClipRect(
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
                  color: kMint.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Text('[ 이동 ]', style: mono(color: kMint, fontSize: 12)),
                ),
              ),
            ),
            // Right: delete button
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _onDeleteBtnTap,
                  child: Container(
                    color: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: Text('[ 삭제 ]',
                        style: mono(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ),
            ),
            // Main content (translated + opaque background to cover actions)
            Transform.translate(
              offset: Offset(_swipeOffset, 0),
              child: Container(
                color: kBg,
                child: kIsWeb
                    ? LongPressDraggable<Memo>(
                        data: widget.memo,
                        delay: const Duration(milliseconds: 400),
                        feedback: _buildDragFeedback(),
                        childWhenDragging:
                            Opacity(opacity: 0.4, child: _buildViewMode()),
                        child: _buildViewMode(),
                      )
                    : _buildViewMode(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── View mode ────────────────────────────────────────

  Widget _buildViewMode() {
    final lines = widget.memo.content.split('\n');
    final tags = widget.memo.tags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onDoubleTap: widget.memo.isChecklist ? null : _startEditing,
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
                  // Header row: timestamp (+ inline reminder) + controls
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('[${widget.memo.timeStr}]',
                          style: mono(color: kDim, fontSize: 11)),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        ...tags.map((t) => GestureDetector(
                          onTap: () => widget.onTagTap?.call(t),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text('#$t', style: mono(color: kTeal, fontSize: 11)),
                          ),
                        )),
                      ],
                      if (widget.memo.reminderAt != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _showReminderDialog,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Text(
                              '🔔 ${_fmtReminder(widget.memo.reminderAt!)}',
                              style: mono(color: kMint, fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (widget.memo.isChecklist) ...[
                        Text('[CHECK]',
                            style: mono(color: kTeal, fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                      ],
                      GestureDetector(
                        onTap: _showReminderDialog,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Text(
                            '[알림]',
                            style: mono(
                              color: widget.memo.reminderAt != null
                                  ? kMint
                                  : kDim.withValues(alpha: 0.45),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _showHistory,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Text(
                            '[…]',
                            style: mono(
                              color: _hovered
                                  ? kDim
                                  : kDim.withValues(alpha: 0.45),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Text(
                          '[×]',
                          style: mono(
                            color: _hovered
                                ? kDim
                                : kDim.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Content area
                  if (_hasChecklistLines)
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
        if (_isAddingNote)
          _buildAddNoteInput()
        else
          _buildAddNoteBtn(),
        // Source URL badge
        if (widget.memo.sourceUrl != null)
          _SourceBadge(url: widget.memo.sourceUrl!),
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
        '[${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}]';

    if (_editingNoteIndex == index) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.only(left: 14, top: 6, bottom: 6, right: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('∟ $timeStr',
                style: mono(color: kDim, fontSize: 10, letterSpacing: 0.5)),
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
                hintStyle: mono(color: kDim.withValues(alpha: 0.4), fontSize: 12),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionBtn(label: '[ SAVE ]', color: kMint, onTap: _saveNoteEdit),
                const SizedBox(width: 6),
                _ActionBtn(
                  label: '[ CANCEL ]',
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
                Text('∟ $timeStr',
                    style: mono(color: kDim, fontSize: 10, letterSpacing: 0.5)),
                const Spacer(),
                GestureDetector(
                  onTap: () => _confirmDeleteNote(index),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text('[×]',
                        style: mono(color: kDim.withValues(alpha: 0.7), fontSize: 10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: mono(color: kText, fontSize: 12)),
                Expanded(
                  child: Text(note.content,
                      style: mono(color: kText, fontSize: 12, height: 1.5)),
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
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _noteFocusNode.requestFocus());
            },
            child: Text(
              '[+ 추가]',
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
                hintStyle:
                    mono(color: kDim.withValues(alpha: 0.4), fontSize: 12),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionBtn(
                    label: '[ SAVE ]', color: kMint, onTap: _saveNote),
                const SizedBox(width: 8),
                _ActionBtn(
                  label: '[ CANCEL ]',
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
        ...lines.asMap().entries
            .where((e) => e.value.isNotEmpty)
            .map((e) {
              final clean = e.value.replaceAll(_tagRe, '').trim();
              if (clean.isEmpty) return const SizedBox.shrink();
              if (clean.startsWith('- [x] ')) {
                return _buildChecklistItemRow(
                    _stripExtraPrefixes(clean.substring(6)), true, e.key);
              }
              if (clean.startsWith('- [ ] ')) {
                return _buildChecklistItemRow(
                    _stripExtraPrefixes(clean.substring(6)), false, e.key);
              }
              if (clean.startsWith('• ')) {
                return _buildBulletItemRow(
                    _stripExtraPrefixes(clean.substring(2)), e.key);
              }
              // 일반 텍스트는 그대로 렌더링
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text.rich(_parseInline(
                    clean, mono(color: kText, fontSize: 13, height: 1.55))),
              );
            }),
        if (_checkItemInputVisible)
          _buildAddItemRow()
        else
          _buildAddItemBtn(),
      ],
    );
  }

  Widget _buildBulletItemRow(String text, int lineIndex) {
    if (_editingCheckIndex == lineIndex) {
      return _buildCheckItemEditRow(lineIndex);
    }
    return GestureDetector(
      onDoubleTap: () => _startEditingCheckItem(lineIndex, text),
      onLongPress: () => _startEditingCheckItem(lineIndex, text),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ',
                style: mono(color: kText, fontSize: 13)),
            Expanded(
                child: Text.rich(_parseInline(
                    text, mono(color: kText, fontSize: 13, height: 1.5)))),
            GestureDetector(
              onTap: () => _deleteChecklistItem(lineIndex),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '[×]',
                    style: mono(
                        color: _hovered
                            ? kDim
                            : kDim.withValues(alpha: 0.5),
                        fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItemRow(String text, bool checked, int lineIndex) {
    if (_editingCheckIndex == lineIndex) {
      return _buildCheckItemEditRow(lineIndex);
    }
    final textStyle = mono(
            color: checked ? kDim : kText, fontSize: 13, height: 1.5)
        .copyWith(
      decoration: checked ? TextDecoration.lineThrough : null,
      decorationColor: kDim,
    );
    return GestureDetector(
      onDoubleTap: () => _startEditingCheckItem(lineIndex, text),
      onLongPress: () => _startEditingCheckItem(lineIndex, text),
      child: Padding(
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
                  child: Text(checked ? '✓ ' : '□ ',
                      style: mono(color: checked ? kDim : kMint, fontSize: 13)),
                ),
              ),
            ),
            Expanded(child: Text.rich(_parseInline(text, textStyle))),
            GestureDetector(
              onTap: () => _deleteChecklistItem(lineIndex),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '[×]',
                    style: mono(
                        color: _hovered
                            ? kDim
                            : kDim.withValues(alpha: 0.5),
                        fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
              child: Text('[OK]', style: mono(color: kMint, fontSize: 11)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _cancelCheckEdit,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text('[×]', style: mono(color: kDim, fontSize: 11)),
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
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _addItemFocusNode.requestFocus());
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Text(
            '[+ 항목 추가]',
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
          Text('>_ ',
              style: mono(
                  color: kTeal.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
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
                    color: kDim.withValues(alpha: 0.35), fontSize: 12),
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
                child: Text('[+]',
                    style: mono(color: kTeal, fontSize: 11)),
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
                child: Text('[×]',
                    style: mono(color: kDim.withValues(alpha: 0.6), fontSize: 11)),
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
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        itemBuilder: (ctx, i) {
          final file = File(paths[i]);
          return GestureDetector(
            onTap: () => _openImageViewer(paths, i),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                border: Border.all(color: kBorder.withValues(alpha: 0.6)),
              ),
              child: file.existsSync()
                  ? Image.file(file, fit: BoxFit.cover)
                  : Container(
                      color: kSurface,
                      child: Icon(Icons.broken_image_outlined,
                          size: 20, color: kDim),
                    ),
            ),
          );
        },
      ),
    );
  }

  void _openImageViewer(List<String> paths, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _ImageViewerDialog(
        paths: paths,
        initialIndex: initialIndex,
      ),
    );
  }

  // ── Inline markdown parser ────────────────────────────

  static final _inlineRe = RegExp(
    r'\*\*(.+?)\*\*|~~(.+?)~~|\*(.+?)\*|(https?://\S+)',
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
        children.add(TextSpan(
          text: m.group(1),
          style: base.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (m.group(2) != null) {
        children.add(TextSpan(
          text: m.group(2),
          style: base.copyWith(
            decoration: TextDecoration.lineThrough,
            decorationColor: base.color,
          ),
        ));
      } else if (m.group(3) != null) {
        children.add(TextSpan(
          text: m.group(3),
          style: base.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (m.group(4) != null) {
        final url = m.group(4)!;
        final rec = TapGestureRecognizer()
          ..onTap = () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        children.add(TextSpan(
          text: url,
          style: base.copyWith(color: kTeal),
          recognizer: rec,
        ));
      }
      lastEnd = m.end;
    }
    if (lastEnd < text.length) {
      children.add(TextSpan(text: text.substring(lastEnd)));
    }
    if (children.isEmpty) return TextSpan(text: text, style: base);
    return TextSpan(children: children, style: base);
  }

  Widget _buildRichContent(String content) {
    final base = mono(color: kText, fontSize: 13, height: 1.55);
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: time label + save/cancel
          Row(
            children: [
              Text('[${widget.memo.timeStr}]', style: mono(color: kDim, fontSize: 11)),
              const Spacer(),
              _ActionBtn(label: '[ CANCEL ]', color: kDim, onTap: _cancelEdit),
              const SizedBox(width: 6),
              _ActionBtn(label: '[ SAVE ]', color: kMint, onTap: _saveEdit),
            ],
          ),
          const SizedBox(height: 6),
          // Reminder
          GestureDetector(
            onTap: _showReminderDialog,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                widget.memo.reminderAt != null
                    ? '🔔 ${_fmtReminder(widget.memo.reminderAt!)}'
                    : '[알림 추가]',
                style: mono(
                  color: widget.memo.reminderAt != null
                      ? kMint
                      : kDim.withValues(alpha: 0.55),
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Text field
          TextField(
            controller: _editController,
            focusNode: _editFocusNode,
            style: mono(fontSize: 13, height: 1.6),
            maxLines: null,
            cursorColor: kMint,
            cursorWidth: 2,
            decoration: InputDecoration(
              filled: true,
              fillColor: kSurface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
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
                child: Text(widget.label,
                    style: mono(color: kText, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
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

  const _ActionBtn({required this.label, required this.color, required this.onTap});

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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Text(widget.label,
              style: mono(color: widget.color, fontSize: 10)),
        ),
      ),
    );
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

  const _ImageViewerDialog({
    required this.paths,
    required this.initialIndex,
  });

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
                      : Icon(Icons.broken_image_outlined,
                          size: 48, color: kDim),
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
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    if (widget.paths.length > 1)
                      Text(
                        '${_index + 1} / ${widget.paths.length}',
                        style: mono(color: Colors.white70, fontSize: 11),
                      ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _share,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          border: Border.all(
                              color: Colors.white24),
                        ),
                        child: Text('[ 저장/공유 ]',
                            style: mono(
                                color: Colors.white70,
                                fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        color: Colors.black45,
                        child: Text('[×]',
                            style: mono(
                                color: Colors.white70,
                                fontSize: 11)),
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
