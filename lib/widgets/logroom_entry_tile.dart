import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../models/memo.dart';
import '../models/memo_actions.dart';
import '../services/image_service.dart';
import '../utils/logroom_entries.dart';

final _urlRe = RegExp(r'https?://\S+');

List<String> _extractUrls(String text) =>
    _urlRe.allMatches(text).map((m) => m.group(0)!).toSet().toList();

List<String> _entryLinks(Memo memo) => [
  ..._extractUrls(memo.content),
  if (memo.sourceUrl != null) memo.sourceUrl!,
].where((url) => url.trim().isNotEmpty).toSet().toList();

String _entryTagRow(Memo memo) => memo.tags
    .where((t) => t != 'habit' && t != 'goal')
    .map((t) => '#$t')
    .join(' ');

String _stripUrls(String text) =>
    text.replaceAll(_urlRe, '').replaceAll(RegExp(r'[ \t]+\n'), '\n').trim();

String _stripVisibleTags(String text) => text
    .replaceAll(RegExp(r'#[a-zA-Z0-9_ㄱ-ㅎㅏ-ㅣ가-힣]+'), '')
    .replaceAll(RegExp(r'[ \t]+\n'), '\n')
    .replaceAll(RegExp(r' {2,}'), ' ')
    .trim();

Color _doneTextColor() => Color.lerp(kText, kDim, 0.55) ?? kDim;

Color _doneAccentColor() => Color.lerp(kMint, kDim, 0.62) ?? kDim;

class LogroomEntryTile extends StatefulWidget {
  final Memo memo;
  final MemoActions actions;
  final bool highlighted;
  final VoidCallback? onTap;
  // expandable kept for API compatibility but ignored — always shows full content
  final bool expandable;

  const LogroomEntryTile({
    super.key,
    required this.memo,
    required this.actions,
    this.highlighted = false,
    this.onTap,
    this.expandable = true,
  });

  @override
  State<LogroomEntryTile> createState() => _LogroomEntryTileState();
}

class _LogroomEntryTileState extends State<LogroomEntryTile> {
  double _swipeOffset = 0;
  bool _deleteRevealed = false;

  static const _kDeleteSnap = -75.0;
  static const _kDeleteThreshold = -55.0;
  static const _kMoveThreshold = 52.0;

  bool get _isSystemMemo =>
      widget.memo.tags.any((t) => t == 'habit' || t == 'goal');

  // Toggle checklist: any unchecked → all done; all done → all undone
  void _toggleTask() {
    final memo = widget.memo;
    if (!memo.isChecklist) return;
    final lines = memo.content.split('\n');
    final anyUnchecked = logroomHasUnchecked(memo.content);
    final toggled = lines
        .map((line) {
          if (anyUnchecked && line.startsWith('- [ ] ')) {
            return '- [x] ${line.substring(6)}';
          } else if (!anyUnchecked && line.startsWith('- [x] ')) {
            return '- [ ] ${line.substring(6)}';
          }
          return line;
        })
        .join('\n');
    widget.actions.onUpdate(memo, toggled);
  }

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

  void _delete() {
    setState(() {
      _swipeOffset = 0;
      _deleteRevealed = false;
    });
    widget.actions.onDelete(widget.memo);
  }

  void _showFolderPicker() {
    final others = widget.actions.folders
        .where((f) => f.id != widget.memo.folderId)
        .toList();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 280,
            maxHeight: MediaQuery.of(ctx).size.height * 0.64,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MOVE TO', style: mono(color: kMint, fontSize: 13)),
                const SizedBox(height: 8),
                Container(height: 1, color: kBorder),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      if (widget.memo.folderId != null)
                        _MoveRow(
                          label: 'INBOX',
                          onTap: () {
                            Navigator.pop(ctx);
                            widget.actions.onMove(widget.memo, null);
                          },
                        ),
                      ...others.map(
                        (folder) => _MoveRow(
                          label: folder.name,
                          onTap: () {
                            Navigator.pop(ctx);
                            widget.actions.onMove(widget.memo, folder.id);
                          },
                        ),
                      ),
                      if (widget.memo.folderId == null && others.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            '이동할 room이 없습니다',
                            style: mono(color: kDim, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Text('취소', style: mono(color: kDim, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: widget.memo.content);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('EDIT', style: mono(color: kMint, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: null,
                style: mono(color: kText, fontSize: 12),
                decoration: InputDecoration(
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
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text('취소', style: mono(color: kDim, fontSize: 12)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      final updated = controller.text.trim();
                      if (updated.isNotEmpty) {
                        widget.actions.onUpdate(widget.memo, updated);
                      }
                      Navigator.pop(ctx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        '저장',
                        style: mono(color: kMint, fontSize: 12),
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

  void _editNote(int index) {
    final note = widget.memo.appendNotes[index];
    final controller = TextEditingController(text: note.content);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('💬 댓글 수정', style: mono(color: kMint, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: null,
                style: mono(color: kText, fontSize: 12),
                decoration: InputDecoration(
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
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text('취소', style: mono(color: kDim, fontSize: 12)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      final updated = controller.text.trim();
                      if (updated.isNotEmpty) {
                        widget.actions.onUpdateNote(
                          widget.memo,
                          index,
                          updated,
                        );
                      }
                      Navigator.pop(ctx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        '저장',
                        style: mono(color: kMint, fontSize: 12),
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

  void _addNote() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('댓글 추가', style: mono(color: kMint, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: null,
                style: mono(color: kText, fontSize: 12),
                decoration: const InputDecoration(border: InputBorder.none),
                onSubmitted: (_) {
                  final text = controller.text.trim();
                  if (text.isNotEmpty)
                    widget.actions.onAddNote(widget.memo, text);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text('취소', style: mono(color: kDim, fontSize: 12)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      final text = controller.text.trim();
                      if (text.isNotEmpty)
                        widget.actions.onAddNote(widget.memo, text);
                      Navigator.pop(ctx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        '저장',
                        style: mono(color: kMint, fontSize: 12),
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

  Future<void> _confirmDeleteNote(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('댓글 삭제하시겠습니까?', style: mono(color: kText, fontSize: 13)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text('취소', style: mono(color: kDim, fontSize: 12)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        '삭제',
                        style: mono(color: Colors.red.shade400, fontSize: 12),
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
    if (ok == true) widget.actions.onDeleteNote(widget.memo, index);
  }

  String _shareText() {
    final parts = <String>[widget.memo.content.trim()];
    if (widget.memo.sourceUrl != null) parts.add(widget.memo.sourceUrl!);
    return parts.where((p) => p.isNotEmpty).join('\n');
  }

  Future<void> _showMoreMenu() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ActionSheetRow(
                label: '수정',
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
              _ActionSheetRow(
                label: '삭제',
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
              _ActionSheetRow(
                label: '이동',
                onTap: () => Navigator.pop(ctx, 'move'),
              ),
              _ActionSheetRow(
                label: '공유',
                onTap: () => Navigator.pop(ctx, 'share'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case 'edit':
        widget.actions.onEditRequest(widget.memo);
        break;
      case 'delete':
        _delete();
        break;
      case 'move':
        _showFolderPicker();
        break;
      case 'share':
        Share.share(_shareText());
        break;
    }
  }

  void _toggleChecklistLine(int lineIndex) {
    final lines = widget.memo.content.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return;
    final line = lines[lineIndex];
    if (line.startsWith('- [ ] ')) {
      lines[lineIndex] = '- [x] ${line.substring(6)}';
    } else if (line.startsWith('- [x] ')) {
      lines[lineIndex] = '- [ ] ${line.substring(6)}';
    } else {
      return;
    }
    widget.actions.onUpdate(widget.memo, lines.join('\n'));
  }

  void _editChecklistLine(int lineIndex) {
    final lines = widget.memo.content.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return;
    final raw = lines[lineIndex];
    final checked = raw.startsWith('- [x] ');
    final controller = TextEditingController(
      text: raw.length > 6 ? raw.substring(6) : raw,
    );
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('CHECK ITEM', style: mono(color: kMint, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                style: mono(color: kText, fontSize: 12),
                decoration: const InputDecoration(border: InputBorder.none),
                onSubmitted: (_) {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    lines[lineIndex] = '${checked ? '- [x] ' : '- [ ] '}$text';
                    widget.actions.onUpdate(widget.memo, lines.join('\n'));
                  }
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteChecklistLine(int lineIndex) {
    final lines = widget.memo.content.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return;
    lines.removeAt(lineIndex);
    widget.actions.onUpdate(widget.memo, lines.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final memo = widget.memo;
    if (isDosTheme) return _buildDosEntry(memo);
    if (isMinimalTheme) return _buildMinimalEntry(memo);
    final isTask = memo.isChecklist;
    final links = _entryLinks(memo);
    final visibleTags = _entryTagRow(memo);
    final displayText = _stripVisibleTags(_stripUrls(logroomTitle(memo)));
    final repeat =
        memo.scheduleRepeat != 'none' || memo.reminderRepeat != 'none';
    final displayTime = logroomTime(memo.createdAt);
    final scheduleMeta = memo.scheduledAt == null
        ? null
        : logroomShortDateTime(memo.scheduledAt!);

    // Structural meta (NOT tags — already in content body)
    final hasStructMeta =
        memo.reminderAt != null || memo.folderId != null || repeat;

    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      color: widget.highlighted
          ? kMint.withValues(alpha: 0.08)
          : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 7, 12, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: isTask ? _toggleTask : null,
                      behavior: HitTestBehavior.opaque,
                      child: logroomPrefixText(memo, fontSize: 10),
                    ),
                    Text(displayTime, style: mono(color: kDim, fontSize: 10)),
                    if (scheduleMeta != null)
                      Text(
                        '· $scheduleMeta',
                        style: mono(color: kTeal, fontSize: 10),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // ── Main content row ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: isTask
                          ? _ChecklistContent(
                              content: memo.content,
                              onToggle: _toggleChecklistLine,
                              onEdit: _editChecklistLine,
                              onDelete: _deleteChecklistLine,
                            )
                          : displayText.isEmpty
                          ? const SizedBox.shrink()
                          : _FullContentText(
                              text: displayText,
                              onTap: widget.onTap,
                            ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showMoreMenu,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 2, 6),
                        child: Text(
                          '⋮',
                          style: mono(color: kDim, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),

                if (links.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...links.map((url) => _LinkRow(url: url)),
                ],

                // ── Structural meta badges ──
                if (hasStructMeta) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 7,
                    runSpacing: 2,
                    children: [
                      if (memo.reminderAt != null)
                        _MBadge('🔔 ${logroomShortDateTime(memo.reminderAt!)}'),
                      if (memo.folderId != null) const _MBadge('📁'),
                      if (repeat) const _MBadge('↺'),
                    ],
                  ),
                ],

                if (visibleTags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    visibleTags,
                    style: mono(
                      color: kTeal.withValues(alpha: 0.75),
                      fontSize: 10,
                      height: 1.35,
                    ),
                    softWrap: true,
                  ),
                ],

                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    if (memo.appendNotes.isNotEmpty)
                      _MBadge('💬 댓글 ${memo.appendNotes.length}개'),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _addNote,
                      child: Text(
                        memo.appendNotes.isEmpty ? '+ 댓글 추가' : '+ 댓글',
                        style: mono(color: kTeal, fontSize: 9),
                      ),
                    ),
                    if (memo.imagePaths.isNotEmpty)
                      _MBadge('📷 ${memo.imagePaths.length}'),
                  ],
                ),

                // ── Inline notes ──
                if (memo.appendNotes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...List.generate(memo.appendNotes.length, (i) {
                    final note = memo.appendNotes[i];
                    return _InlineNoteRow(
                      content: note.content,
                      onEdit: () => _editNote(i),
                      onDelete: () => _confirmDeleteNote(i),
                    );
                  }),
                ],

                // ── Inline image thumbnails ──
                if (memo.imagePaths.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _ImageStrip(
                    paths: memo.imagePaths,
                    onTap: (index) => showDialog(
                      context: context,
                      barrierColor: Colors.black87,
                      builder: (_) => _ImageViewerDialog(
                        paths: memo.imagePaths,
                        initialIndex: index,
                        onDelete: (i) => widget.actions.onDeleteImage(memo, i),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(height: 1, color: kBorder.withValues(alpha: 0.2)),
        ],
      ),
    );

    return ClipRect(
      child: GestureDetector(
        onHorizontalDragUpdate: _onSwipeUpdate,
        onHorizontalDragEnd: _onSwipeEnd,
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 75,
                  color: kMint.withValues(alpha: 0.12),
                  alignment: Alignment.center,
                  child: Text('이동', style: mono(color: kMint, fontSize: 12)),
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _delete,
                  child: Container(
                    width: 75,
                    color: Colors.red.shade700,
                    alignment: Alignment.center,
                    child: Text(
                      '삭제',
                      style: mono(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(_swipeOffset, 0),
              child: Container(color: kBg, child: body),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalEntry(Memo memo) {
    final isTask = memo.isChecklist;
    final links = _entryLinks(memo);
    final visibleTags = memo.tags
        .where((t) => t != 'habit' && t != 'goal')
        .toList();
    final displayText = _stripVisibleTags(_stripUrls(logroomTitle(memo)));
    final scheduleMeta = memo.scheduledAt == null
        ? null
        : logroomShortDateTime(memo.scheduledAt!);
    final type = _minimalTypeLabel(memo, links);
    final repeat =
        memo.scheduleRepeat != 'none' || memo.reminderRepeat != 'none';

    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      color: widget.highlighted
          ? kMint.withValues(alpha: 0.07)
          : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(12, 5, 10, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              logroomTime(memo.createdAt),
              style: mono(color: kDim, fontSize: 8, height: 1.35),
              maxLines: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isTask ? _toggleTask : null,
              child: _MinimalTypeLabel(
                label: type,
                checked: _minimalDone(memo),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (scheduleMeta != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '일정 $scheduleMeta',
                      style: mono(color: kTeal, fontSize: 9, height: 1.3),
                    ),
                  ),
                if (isTask)
                  _MinimalChecklistContent(
                    content: memo.content,
                    onToggle: _toggleChecklistLine,
                    onEdit: _editChecklistLine,
                    onDelete: _deleteChecklistLine,
                  )
                else if (displayText.isNotEmpty)
                  _MinimalContentText(text: displayText, onTap: widget.onTap)
                else if (links.isEmpty)
                  Text(
                    '내용 없음',
                    style: mono(
                      color: kDim.withValues(alpha: 0.6),
                      fontSize: kFontSize,
                    ),
                  ),
                if (links.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  ...links.map((url) => _MinimalLinkRow(url: url)),
                ],
                if (memo.reminderAt != null || repeat) ...[
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 7,
                    runSpacing: 1,
                    children: [
                      if (memo.reminderAt != null)
                        Text(
                          '알림 ${logroomShortDateTime(memo.reminderAt!)}',
                          style: mono(color: kDim, fontSize: 8),
                        ),
                      if (repeat)
                        Text('반복', style: mono(color: kDim, fontSize: 8)),
                    ],
                  ),
                ],
                if (visibleTags.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 1,
                    children: visibleTags.map((tag) {
                      final text = Text(
                        '#$tag',
                        style: mono(color: kTeal, fontSize: 8, height: 1.25),
                      );
                      final onTagTap = widget.actions.onTagTap;
                      if (onTagTap == null) return text;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTagTap(tag),
                        child: text,
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 3),
                Wrap(
                  spacing: 9,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _addNote,
                      child: Text(
                        memo.appendNotes.isEmpty
                            ? '댓글 추가'
                            : '댓글 ${memo.appendNotes.length}개',
                        style: mono(color: kDim, fontSize: 8),
                      ),
                    ),
                    if (memo.appendNotes.isNotEmpty)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _addNote,
                        child: Text(
                          '+',
                          style: mono(color: kTeal, fontSize: 8),
                        ),
                      ),
                    if (memo.imagePaths.isNotEmpty)
                      Text(
                        '이미지 ${memo.imagePaths.length}',
                        style: mono(color: kDim, fontSize: 8),
                      ),
                  ],
                ),
                if (memo.appendNotes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  ...List.generate(memo.appendNotes.length, (i) {
                    final note = memo.appendNotes[i];
                    return _InlineNoteRow(
                      content: note.content,
                      onEdit: () => _editNote(i),
                      onDelete: () => _confirmDeleteNote(i),
                    );
                  }),
                ],
                if (memo.imagePaths.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _ImageStrip(
                    paths: memo.imagePaths,
                    onTap: (index) => showDialog(
                      context: context,
                      barrierColor: Colors.black87,
                      builder: (_) => _ImageViewerDialog(
                        paths: memo.imagePaths,
                        initialIndex: index,
                        onDelete: (i) => widget.actions.onDeleteImage(memo, i),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showMoreMenu,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 2, 8),
              child: Text('⋮', style: mono(color: kDim, fontSize: 11)),
            ),
          ),
        ],
      ),
    );

    return ClipRect(
      child: GestureDetector(
        onHorizontalDragUpdate: _onSwipeUpdate,
        onHorizontalDragEnd: _onSwipeEnd,
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 75,
                  color: kMint.withValues(alpha: 0.1),
                  alignment: Alignment.center,
                  child: Text('이동', style: mono(color: kMint, fontSize: 11)),
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _delete,
                  child: Container(
                    width: 75,
                    color: Colors.red.shade700,
                    alignment: Alignment.center,
                    child: Text(
                      '삭제',
                      style: mono(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(_swipeOffset, 0),
              child: Container(
                color: kBg,
                child: Column(
                  children: [
                    body,
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 78),
                      color: kBorder.withValues(alpha: 0.16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDosEntry(Memo memo) {
    final isTask = memo.isChecklist;
    final links = _entryLinks(memo);
    final visibleTags = memo.tags
        .where((t) => t != 'habit' && t != 'goal')
        .map((t) => '#$t')
        .join(' ');
    final displayText = _stripVisibleTags(_stripUrls(logroomTitle(memo)));
    final type = memo.isChecklist
        ? '[TODO]'
        : memo.scheduledAt != null
        ? '[SCHED]'
        : links.isNotEmpty
        ? '[LINK]'
        : '[MEMO]';
    final body = Container(
      color: kBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Container(
          decoration: BoxDecoration(
            color: kBg,
            border: Border.all(
              color: kBorder.withValues(alpha: 0.55),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: isTask ? _toggleTask : null,
                        child: Text(
                          '$type ${logroomTime(memo.createdAt)}',
                          style: mono(color: kMint, fontSize: 11),
                        ),
                      ),
                      if (memo.scheduledAt != null)
                        Expanded(
                          child: Text(
                            '  SCHED ${logroomShortDateTime(memo.scheduledAt!)}',
                            style: mono(color: kTeal, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        const Spacer(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _showMoreMenu,
                        child: Text(
                          '[ EDIT ]',
                          style: mono(color: kTeal, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (isTask)
                    _DosChecklistContent(
                      content: memo.content,
                      onToggle: _toggleChecklistLine,
                      onEdit: _editChecklistLine,
                      onDelete: _deleteChecklistLine,
                    )
                  else if (displayText.isNotEmpty)
                    _FullContentText(text: displayText, onTap: widget.onTap)
                  else if (links.isEmpty)
                    Text('NO CONTENT.', style: mono(color: kDim, fontSize: 11)),
                  if (links.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    ...links.map((url) => _DosLinkRow(url: url)),
                  ],
                  if (memo.reminderAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '[ALARM] ${logroomShortDateTime(memo.reminderAt!)}',
                      style: mono(color: kTeal, fontSize: 10),
                    ),
                  ],
                  if (visibleTags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(visibleTags, style: mono(color: kTeal, fontSize: 10)),
                  ],
                  if (memo.appendNotes.isNotEmpty ||
                      memo.imagePaths.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${memo.appendNotes.isNotEmpty ? '[COMMENTS:${memo.appendNotes.length}] ' : ''}${memo.imagePaths.isNotEmpty ? '[IMG:${memo.imagePaths.length}]' : ''}',
                      style: mono(color: kDim, fontSize: 10),
                    ),
                  ],
                  const SizedBox(height: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _addNote,
                    child: Text(
                      memo.appendNotes.isEmpty ? '[ COMMENT + ]' : '[ + ]',
                      style: mono(color: kTeal, fontSize: 10),
                    ),
                  ),
                  if (memo.appendNotes.isNotEmpty)
                    ...List.generate(memo.appendNotes.length, (i) {
                      final note = memo.appendNotes[i];
                      return _InlineNoteRow(
                        content: note.content,
                        onEdit: () => _editNote(i),
                        onDelete: () => _confirmDeleteNote(i),
                      );
                    }),
                  if (memo.imagePaths.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    _ImageStrip(
                      paths: memo.imagePaths,
                      onTap: (index) => showDialog(
                        context: context,
                        barrierColor: Colors.black87,
                        builder: (_) => _ImageViewerDialog(
                          paths: memo.imagePaths,
                          initialIndex: index,
                          onDelete: (i) =>
                              widget.actions.onDeleteImage(memo, i),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return ClipRect(
      child: GestureDetector(
        onHorizontalDragUpdate: _onSwipeUpdate,
        onHorizontalDragEnd: _onSwipeEnd,
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _delete,
                  child: Container(
                    width: 82,
                    color: Colors.red.shade900,
                    alignment: Alignment.center,
                    child: Text(
                      '[ DELETE ]',
                      style: mono(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(offset: Offset(_swipeOffset, 0), child: body),
          ],
        ),
      ),
    );
  }
}

// ── Full content text — no maxLines, natural wrap ─────────────────────────────

class _FullContentText extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _FullContentText({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = Text(
      text,
      style: mono(color: kText, fontSize: kFontSize, height: 1.45),
      softWrap: true,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
    }
    return child;
  }
}

class _MinimalContentText extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _MinimalContentText({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = Text(
      text,
      style: mono(color: kText, fontSize: kFontSize, height: 1.38),
      softWrap: true,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
    }
    return child;
  }
}

String _minimalTypeLabel(Memo memo, List<String> links) {
  if (memo.isChecklist) {
    return logroomHasUnchecked(memo.content) ? 'TODO' : 'TODO ✓';
  }
  if (memo.scheduledAt != null) return 'SCHEDULE';
  if (links.isNotEmpty) return 'LINK';
  return 'MEMO';
}

bool _minimalDone(Memo memo) =>
    memo.isChecklist && !logroomHasUnchecked(memo.content);

class _MinimalTypeLabel extends StatelessWidget {
  final String label;
  final bool checked;

  const _MinimalTypeLabel({required this.label, required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: kMint.withValues(alpha: checked ? 0.06 : 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: mono(
          color: checked ? _doneAccentColor() : kMint,
          fontSize: 7,
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
    );
  }
}

class _ChecklistContent extends StatelessWidget {
  final String content;
  final void Function(int) onToggle;
  final void Function(int) onEdit;
  final void Function(int) onDelete;

  const _ChecklistContent({
    required this.content,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines.length, (i) {
        final line = lines[i].trim();
        if (line.isEmpty) return const SizedBox(height: 3);
        final checked = line.startsWith('- [x] ');
        final unchecked = line.startsWith('- [ ] ');
        final text = (checked || unchecked) && line.length > 6
            ? line.substring(6)
            : line;
        if (!checked && !unchecked) {
          return Text(
            text,
            style: mono(color: kText, fontSize: kFontSize, height: 1.45),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onToggle(i),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    checked ? '✓' : '□',
                    style: mono(
                      color: checked ? _doneAccentColor() : kMint,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onEdit(i),
                  onLongPress: () => onDelete(i),
                  child: Text(
                    text,
                    style:
                        mono(
                          color: checked ? _doneTextColor() : kText,
                          fontSize: kFontSize,
                          height: 1.45,
                        ).copyWith(
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: _doneAccentColor(),
                        ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _MinimalChecklistContent extends StatelessWidget {
  final String content;
  final void Function(int) onToggle;
  final void Function(int) onEdit;
  final void Function(int) onDelete;

  const _MinimalChecklistContent({
    required this.content,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines.length, (i) {
        final line = lines[i].trim();
        if (line.isEmpty) return const SizedBox(height: 2);
        final checked = line.startsWith('- [x] ');
        final unchecked = line.startsWith('- [ ] ');
        final text = (checked || unchecked) && line.length > 6
            ? line.substring(6)
            : line;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: checked || unchecked ? () => onToggle(i) : () => onEdit(i),
          onLongPress: () => onDelete(i),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 18,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _MinimalCheckMark(
                      checked: checked,
                      visible: checked || unchecked,
                      onTap: () => onToggle(i),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    text,
                    style:
                        mono(
                          color: checked ? _doneTextColor() : kText,
                          fontSize: kFontSize,
                          height: 1.38,
                        ).copyWith(
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: _doneAccentColor(),
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _MinimalCheckMark extends StatelessWidget {
  final bool checked;
  final bool visible;
  final VoidCallback onTap;

  const _MinimalCheckMark({
    required this.checked,
    required this.visible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.only(top: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: checked
              ? _doneAccentColor().withValues(alpha: 0.14)
              : Colors.transparent,
          border: Border.all(
            color: checked ? _doneAccentColor() : kTeal.withValues(alpha: 0.85),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: checked
            ? Text(
                '✓',
                style: mono(color: _doneAccentColor(), fontSize: 6, height: 1),
              )
            : null,
      ),
    );
  }
}

class _DosChecklistContent extends StatelessWidget {
  final String content;
  final void Function(int) onToggle;
  final void Function(int) onEdit;
  final void Function(int) onDelete;

  const _DosChecklistContent({
    required this.content,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines.length, (i) {
        final line = lines[i].trim();
        if (line.isEmpty) return const SizedBox(height: 2);
        final checked = line.startsWith('- [x] ');
        final unchecked = line.startsWith('- [ ] ');
        final text = (checked || unchecked) && line.length > 6
            ? line.substring(6)
            : line;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: checked || unchecked ? () => onToggle(i) : () => onEdit(i),
          onLongPress: () => onDelete(i),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _MinimalCheckMark(
                      checked: checked,
                      visible: checked || unchecked,
                      onTap: () => onToggle(i),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    text,
                    style:
                        mono(
                          color: checked ? _doneTextColor() : kText,
                          fontSize: kFontSize,
                          height: 1.35,
                        ).copyWith(
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: _doneAccentColor(),
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String url;
  const _LinkRow({required this.url});

  String get _label {
    try {
      final uri = Uri.parse(url);
      return uri.host.isEmpty ? url : uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '🔗 $_label',
          style: mono(color: kTeal, fontSize: 10, height: 1.35),
          softWrap: true,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
    );
  }
}

class _DosLinkRow extends StatelessWidget {
  final String url;
  const _DosLinkRow({required this.url});

  String get _label {
    try {
      final uri = Uri.parse(url);
      return uri.host.isEmpty ? url : uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Text('[LINK] $_label', style: mono(color: kTeal, fontSize: 10)),
    );
  }
}

class _MinimalLinkRow extends StatelessWidget {
  final String url;
  const _MinimalLinkRow({required this.url});

  String get _label {
    try {
      final uri = Uri.parse(url);
      return uri.host.isEmpty ? url : uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        '링크 $_label',
        style: mono(color: kTeal, fontSize: 8, height: 1.3),
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

// ── Inline note row with edit/delete ─────────────────────────────────────────

class _InlineNoteRow extends StatelessWidget {
  final String content;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InlineNoteRow({
    required this.content,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onEdit,
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.only(top: 1, bottom: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 14,
              child: Text(
                'ㄴ',
                style: mono(
                  color: kDim.withValues(alpha: 0.74),
                  fontSize: 10,
                  height: 1.24,
                ),
              ),
            ),
            Expanded(
              child: Text(
                content,
                style: mono(
                  color: kDim.withValues(alpha: 0.78),
                  fontSize: 10,
                  height: 1.24,
                ),
                softWrap: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image thumbnails strip ────────────────────────────────────────────────────

class _ImageStrip extends StatelessWidget {
  final List<String> paths;
  final void Function(int) onTap;

  const _ImageStrip({required this.paths, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => onTap(i),
          child: ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Image.file(
              File(paths[i]),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 56,
                height: 56,
                color: kBorder.withValues(alpha: 0.3),
                child: Center(
                  child: Text('?', style: mono(color: kDim, fontSize: 10)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tiny action button ────────────────────────────────────────────────────────

class _TinyBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _TinyBtn({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: mono(color: danger ? Colors.red.shade400 : kMint, fontSize: 10),
      ),
    );
  }
}

// ── Meta badge ────────────────────────────────────────────────────────────────

class _MBadge extends StatelessWidget {
  final String label;
  const _MBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: mono(color: kDim, fontSize: 9),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── Source URL link badge ─────────────────────────────────────────────────────

class _SourceLink extends StatelessWidget {
  final String url;
  const _SourceLink({required this.url});

  String get _host {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url.length > 24 ? '${url.substring(0, 24)}…' : url;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        '🔗 $_host',
        style: mono(color: kTeal, fontSize: 9),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ActionSheetRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionSheetRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Text(label, style: mono(color: kText, fontSize: 13)),
      ),
    );
  }
}

class _ImageViewerDialog extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;
  final void Function(int) onDelete;

  const _ImageViewerDialog({
    required this.paths,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  late int _index;
  late List<String> _paths;
  late PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _paths = List<String>.from(widget.paths);
    _index = widget.initialIndex.clamp(0, _paths.length - 1);
    _pageCtrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final path = _paths[_index];
    if (!File(path).existsSync()) return;
    await Share.shareXFiles([XFile(path)]);
  }

  Future<void> _saveToGallery() async {
    final path = _paths[_index];
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

  void _deleteCurrent() {
    widget.onDelete(_index);
    _paths.removeAt(_index);
    if (_paths.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _index = _index.clamp(0, _paths.length - 1);
      _pageCtrl.jumpToPage(_index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _paths.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final file = File(_paths[i]);
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
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
                    if (_paths.length > 1)
                      Text(
                        '${_index + 1} / ${_paths.length}',
                        style: mono(color: Colors.white70, fontSize: 11),
                      ),
                    const Spacer(),
                    _ViewerBtn(label: '저장', onTap: _saveToGallery),
                    const SizedBox(width: 8),
                    _ViewerBtn(label: '공유', onTap: _share),
                    const SizedBox(width: 8),
                    _ViewerBtn(label: '삭제', onTap: _deleteCurrent),
                    const SizedBox(width: 8),
                    _ViewerBtn(label: '×', onTap: () => Navigator.pop(context)),
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

class _ViewerBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ViewerBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black45,
          border: Border.all(color: Colors.white24),
        ),
        child: Text(label, style: mono(color: Colors.white70, fontSize: 11)),
      ),
    );
  }
}

// ── Move target row ───────────────────────────────────────────────────────────

class _MoveRow extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _MoveRow({required this.label, required this.onTap});

  @override
  State<_MoveRow> createState() => _MoveRowState();
}

class _MoveRowState extends State<_MoveRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          color: _hovered ? kMint.withValues(alpha: 0.08) : Colors.transparent,
          child: Text(
            widget.label,
            style: mono(color: _hovered ? kMint : kText, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
