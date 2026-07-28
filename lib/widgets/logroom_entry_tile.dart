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

bool _contentHasChecklistLines(String content) =>
    content.split('\n').any((l) =>
        l.startsWith('- [ ] ') || l.startsWith('- [x] '));

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
  const LogroomEntryTile({
    super.key,
    required this.memo,
    required this.actions,
    this.highlighted = false,
    this.onTap,
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

  void _editNote(int index) {
    final note = widget.memo.appendNotes[index];
    showDialog(
      context: context,
      builder: (_) => _NoteDialog(
        title: '💬 댓글 수정',
        initialText: note.content,
        bordered: true,
        onSave: (text) =>
            widget.actions.onUpdateNote(widget.memo, index, text),
      ),
    );
  }

  void _addNote() {
    showDialog(
      context: context,
      builder: (_) => _NoteDialog(
        title: '댓글 추가',
        initialText: '',
        bordered: false,
        onSave: (text) => widget.actions.onAddNote(widget.memo, text),
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
    final isTaskMemo = memo.isChecklist;
    final hasInlineChecklist = _contentHasChecklistLines(memo.content);
    final shouldRenderChecklistLines = isTaskMemo || hasInlineChecklist;
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

    final dotColor = _timelineDotColorForMemo(memo, links);

    // Entry type badge — only for non-default types
    Widget? typeBadge;
    if (isTaskMemo) {
      final done = !logroomHasUnchecked(memo.content);
      typeBadge = _TypeBadge(done ? 'DONE' : 'TODO', color: kTypeTodo);
    } else if (memo.scheduledAt != null) {
      typeBadge = _TypeBadge('SCHED', color: kTeal);
    } else if (links.isNotEmpty) {
      typeBadge = _TypeBadge('LINK', color: const Color(0xFF64AA82));
    }

    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      color: widget.highlighted
          ? kMint.withValues(alpha: 0.08)
          : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LogroomTimelineLane(dotColor: dotColor),
                Expanded(
                  child: Padding(
            padding: EdgeInsets.fromLTRB(appSpace(5), appSpace(5), appSpace(8), appSpace(5)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: appSpace(7),
                  runSpacing: appSpace(2),
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: isTaskMemo ? _toggleTask : null,
                      behavior: HitTestBehavior.opaque,
                      child: logroomPrefixText(memo, fontSize: tsMeta),
                    ),
                    if (typeBadge != null) typeBadge,
                    Text(
                      displayTime,
                      style: monoLabel(color: kText3, fontSize: tsMeta),
                    ),
                    if (scheduleMeta != null)
                      Text(
                        '· $scheduleMeta',
                        style: monoLabel(color: kTeal, fontSize: tsMeta),
                      ),
                  ],
                ),
                SizedBox(height: appSpace(4)),

                // ── Main content row ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: shouldRenderChecklistLines
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
                    SizedBox(width: appSpace(8)),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showMoreMenu,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(appSpace(8), 0, appSpace(2), appSpace(6)),
                        child: Text(
                          '⋮',
                          style: mono(color: kDim, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),

                if (links.isNotEmpty) ...[
                  SizedBox(height: appSpace(4)),
                  ...links.map((url) => _LinkRow(url: url)),
                ],

                // ── Structural meta badges ──
                if (hasStructMeta) ...[
                  SizedBox(height: appSpace(4)),
                  Wrap(
                    spacing: appSpace(7),
                    runSpacing: appSpace(2),
                    children: [
                      if (memo.reminderAt != null)
                        _MBadge('🔔 ${logroomShortDateTime(memo.reminderAt!)}'),
                      if (memo.folderId != null) const _MBadge('📁'),
                      if (repeat) const _MBadge('↺'),
                    ],
                  ),
                ],

                if (visibleTags.isNotEmpty) ...[
                  SizedBox(height: appSpace(6)),
                  Wrap(
                    spacing: appSpace(6),
                    runSpacing: appSpace(4),
                    children: memo.tags
                        .where((t) => t != 'habit' && t != 'goal')
                        .map((t) => _TagPill(t))
                        .toList(),
                  ),
                ],

                SizedBox(height: appSpace(4)),
                Wrap(
                  spacing: appSpace(8),
                  runSpacing: appSpace(2),
                  children: [
                    if (memo.appendNotes.isNotEmpty)
                      _MBadge('💬 댓글 ${memo.appendNotes.length}개'),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _addNote,
                      child: Text(
                        memo.appendNotes.isEmpty ? '+ 댓글 추가' : '+ 댓글',
                        style: mono(color: kAccent, fontSize: tsTiny),
                      ),
                    ),
                    if (memo.imagePaths.isNotEmpty)
                      _MBadge('📷 ${memo.imagePaths.length}'),
                  ],
                ),

                // ── Inline notes ──
                if (memo.appendNotes.isNotEmpty) ...[
                  SizedBox(height: appSpace(4)),
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
                  SizedBox(height: appSpace(5)),
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
                ),  // Expanded
              ],
            ),      // Row
          ),        // IntrinsicHeight
          // gap only — no separator line (mirrors HTML gap-en between entries)
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
    final isTaskMemo = memo.isChecklist;
    final hasInlineChecklist = _contentHasChecklistLines(memo.content);
    final shouldRenderChecklistLines = isTaskMemo || hasInlineChecklist;
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
              style: mono(color: kDim, fontSize: tsMeta, height: 1.35),
              maxLines: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isTaskMemo ? _toggleTask : null,
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
                      style: mono(color: kTeal, fontSize: tsMeta, height: 1.3),
                    ),
                  ),
                if (shouldRenderChecklistLines)
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
                      fontSize: tsBody,
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
                          style: mono(color: kDim, fontSize: tsTiny),
                        ),
                      if (repeat)
                        Text('반복', style: mono(color: kDim, fontSize: tsTiny)),
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
                        style: mono(color: kTeal, fontSize: tsSmall, height: 1.25),
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
                        style: mono(color: kDim, fontSize: tsTiny),
                      ),
                    ),
                    if (memo.appendNotes.isNotEmpty)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _addNote,
                        child: Text(
                          '+',
                          style: mono(color: kTeal, fontSize: tsTiny),
                        ),
                      ),
                    if (memo.imagePaths.isNotEmpty)
                      Text(
                        '이미지 ${memo.imagePaths.length}',
                        style: mono(color: kDim, fontSize: tsTiny),
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
    final isTaskMemo = memo.isChecklist;
    final hasInlineChecklist = _contentHasChecklistLines(memo.content);
    final shouldRenderChecklistLines = isTaskMemo || hasInlineChecklist;
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
                        onTap: isTaskMemo ? _toggleTask : null,
                        child: Text(
                          '$type ${logroomTime(memo.createdAt)}',
                          style: mono(color: kMint, fontSize: tsSmall),
                        ),
                      ),
                      if (memo.scheduledAt != null)
                        Expanded(
                          child: Text(
                            '  SCHED ${logroomShortDateTime(memo.scheduledAt!)}',
                            style: mono(color: kTeal, fontSize: tsMeta),
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
                          style: mono(color: kTeal, fontSize: tsMeta),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (shouldRenderChecklistLines)
                    _DosChecklistContent(
                      content: memo.content,
                      onToggle: _toggleChecklistLine,
                      onEdit: _editChecklistLine,
                      onDelete: _deleteChecklistLine,
                    )
                  else if (displayText.isNotEmpty)
                    _FullContentText(text: displayText, onTap: widget.onTap)
                  else if (links.isEmpty)
                    Text('NO CONTENT.', style: mono(color: kDim, fontSize: tsSmall)),
                  if (links.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    ...links.map((url) => _DosLinkRow(url: url)),
                  ],
                  if (memo.reminderAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '[ALARM] ${logroomShortDateTime(memo.reminderAt!)}',
                      style: mono(color: kTeal, fontSize: tsMeta),
                    ),
                  ],
                  if (visibleTags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(visibleTags, style: mono(color: kTeal, fontSize: tsSmall)),
                  ],
                  if (memo.appendNotes.isNotEmpty ||
                      memo.imagePaths.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${memo.appendNotes.isNotEmpty ? '[COMMENTS:${memo.appendNotes.length}] ' : ''}${memo.imagePaths.isNotEmpty ? '[IMG:${memo.imagePaths.length}]' : ''}',
                      style: mono(color: kDim, fontSize: tsMeta),
                    ),
                  ],
                  const SizedBox(height: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _addNote,
                    child: Text(
                      memo.appendNotes.isEmpty ? '[ COMMENT + ]' : '[ + ]',
                      style: mono(color: kTeal, fontSize: tsTiny),
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

// ── Full content text — collapses beyond 10 lines ─────────────────────────────

class _FullContentText extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;

  const _FullContentText({required this.text, this.onTap});

  @override
  State<_FullContentText> createState() => _FullContentTextState();
}

class _FullContentTextState extends State<_FullContentText> {
  static const _maxLines = 10;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final lineCount = widget.text.split('\n').length;
    final needsCollapse = lineCount > _maxLines;
    final style = mono(
      color: kText.withValues(alpha: 0.82),
      fontSize: tsBody,
      height: 1.6,
    );

    if (!needsCollapse) {
      final child = Text(widget.text, style: style, softWrap: true);
      if (widget.onTap != null) {
        return GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: child,
        );
      }
      return child;
    }

    return GestureDetector(
      onTap: () {
        if (_expanded) {
          widget.onTap?.call();
        } else {
          setState(() => _expanded = true);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: style,
            softWrap: true,
            maxLines: _expanded ? null : _maxLines,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.fade,
          ),
          if (!_expanded) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: kText.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                '▾ 더 보기',
                style: mono(color: kBg, fontSize: tsBody - 1),
              ),
            ),
          ],
        ],
      ),
    );
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
      style: mono(color: kText, fontSize: tsBody, height: 1.38),
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
          fontSize: tsTiny,
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
            style: mono(color: kText, fontSize: tsBody, height: 1.45),
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
                  onTap: () => onToggle(i),
                  onLongPress: () => onDelete(i),
                  child: Text(
                    text,
                    style:
                        mono(
                          color: checked ? _doneTextColor() : kText,
                          fontSize: tsBody,
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
                          fontSize: tsBody,
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
                          fontSize: tsBody,
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
          style: mono(color: kTeal, fontSize: tsSmall, height: 1.35),
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
      child: Text('[LINK] $_label', style: mono(color: kTeal, fontSize: tsSmall)),
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
        style: mono(color: kTeal, fontSize: tsSmall, height: 1.3),
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

// ── Inline note row with edit/delete ─────────────────────────────────────────

// Owns its own TextEditingController so it is disposed only after the dialog
// route is fully removed (after the close animation). Disposing the controller
// synchronously right after `await showDialog` crashes, because the still-
// animating TextField touches the disposed controller.
class _NoteDialog extends StatefulWidget {
  final String title;
  final String initialText;
  final bool bordered;
  final ValueChanged<String> onSave;

  const _NoteDialog({
    required this.title,
    required this.initialText,
    required this.bordered,
    required this.onSave,
  });

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) widget.onSave(text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      insetPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: mono(color: kMint, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: null,
                style: mono(color: kText, fontSize: 12),
                decoration: widget.bordered
                    ? InputDecoration(
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
                      )
                    : const InputDecoration(border: InputBorder.none),
                onSubmitted: widget.bordered ? null : (_) => _save(),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text('취소', style: mono(color: kDim, fontSize: 12)),
                    ),
                  ),
                  GestureDetector(
                    onTap: _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text('저장', style: mono(color: kMint, fontSize: 12)),
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
        padding: const EdgeInsets.only(top: 2, bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 14,
              child: Text(
                'ㄴ',
                style: mono(
                  color: kDim.withValues(alpha: 0.74),
                  fontSize: tsSmall,
                  height: 1.45,
                ),
              ),
            ),
            Expanded(
              child: Text(
                content,
                style: mono(
                  color: kDim.withValues(alpha: 0.78),
                  fontSize: tsSmall,
                  height: 1.45,
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
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

// ── Entry type badge ──────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeBadge(this.label, {required this.color});

  @override
  Widget build(BuildContext context) {
    // Editorial: borderless uppercase mono label in its type color.
    return Text(
      label.toUpperCase(),
      style: monoLabel(color: color, fontSize: tsTiny, letterSpacing: 1.4),
    );
  }
}

// Terracotta outline tag pill — "dev", "secondbrain".
class _TagPill extends StatelessWidget {
  final String tag;
  const _TagPill(this.tag);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: appSpace(9),
        vertical: appSpace(2),
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: kAccent.withValues(alpha: 0.45),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tag,
        style: mono(color: kAccent, fontSize: tsSmall, height: 1.2),
      ),
    );
  }
}

// ── v3 Timeline ───────────────────────────────────────────────────────────────

// Returns a dot color for the timeline lane based on entry type.
// Mirrors the v3 HTML en-dot color scheme.
Color _timelineDotColorForMemo(Memo memo, List<String> links) {
  if (memo.isChecklist || _contentHasChecklistLines(memo.content)) {
    return kTypeTodo; // 할 일 — 세이지
  }
  if (memo.scheduledAt != null) {
    return kTeal; // 일정
  }
  if (links.isNotEmpty) {
    return const Color(0xFF64AA82); // 링크 — 그린
  }
  return kAccent; // 로그(기본) — 테라코타
}

// Vertical timeline lane: a thin line with a small dot at the top.
// Width is fixed; height stretches to the entry's IntrinsicHeight.
class _LogroomTimelineLane extends StatelessWidget {
  final Color dotColor;

  const _LogroomTimelineLane({required this.dotColor});

  @override
  Widget build(BuildContext context) {
    final width   = appSpace(34.0);
    final lineX   = appSpace(16.0);
    final dotSize = appSpace(5.0);
    final dotTop  = appSpace(12.0);
    return SizedBox(
      width: width,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // vertical line — full height so adjacent entries visually connect
          Positioned(
            left: lineX - 0.5,
            top: 0,
            bottom: 0,
            width: 1,
            child: Container(color: kTlLine),
          ),
          // dot overlaid on line
          Positioned(
            left: lineX - dotSize / 2,
            top: dotTop,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
