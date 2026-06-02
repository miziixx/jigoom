import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/folder.dart';
import '../models/memo.dart';
import '../app_theme.dart';

const _kMaxDepth = 4;

class Sidebar extends StatefulWidget {
  final List<Folder> folders;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final void Function(String name, String? parentId) onCreate;
  final VoidCallback onSettingsTap;
  final List<String> allTags;
  final Map<String, int> tagCounts;
  final String? selectedTag;
  final ValueChanged<String?> onSelectTag;
  final Map<String?, int> memoCounts;
  final List<Memo> recentMemos;
  final ValueChanged<Memo>? onSelectRecent;
  final int totalWords;
  final int streak;
  final void Function(Memo memo, String? folderId)? onMoveMemo;
  final void Function(String folderId, String? newParentId, int insertIndex)?
      onMoveFolder;
  final void Function(String folderId, String newName)? onRenameFolder;
  final int dayCount;
  final bool habitActivated;
  final bool goalActivated;
  final void Function(String name) onActivateHabit;
  final void Function(String name) onActivateGoal;
  final VoidCallback? onSelectHabit;
  final VoidCallback? onSelectGoal;

  const Sidebar({
    super.key,
    required this.folders,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
    required this.onSettingsTap,
    required this.allTags,
    required this.tagCounts,
    required this.selectedTag,
    required this.onSelectTag,
    required this.memoCounts,
    required this.recentMemos,
    this.onSelectRecent,
    required this.totalWords,
    required this.streak,
    this.onMoveMemo,
    this.onMoveFolder,
    this.onRenameFolder,
    required this.dayCount,
    required this.habitActivated,
    required this.goalActivated,
    required this.onActivateHabit,
    required this.onActivateGoal,
    this.onSelectHabit,
    this.onSelectGoal,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isCreating = false;
  String? _creatingParentId;
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  // Collapsed folder IDs — absent = expanded (default)
  final _collapsed = <String>{};

  bool _isExpanded(String id) => !_collapsed.contains(id);
  void _toggleExpand(String id) => setState(() {
        if (_collapsed.contains(id)) {
          _collapsed.remove(id);
        } else {
          _collapsed.add(id);
        }
      });

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _cancel();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          _confirm();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
  }

  void _startCreate(String? parentId) {
    setState(() {
      _isCreating = true;
      _creatingParentId = parentId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _confirm() {
    final name = _ctrl.text.trim();
    if (name.isNotEmpty) widget.onCreate(name, _creatingParentId);
    _ctrl.clear();
    setState(() {
      _isCreating = false;
      _creatingParentId = null;
    });
  }

  void _cancel() {
    _ctrl.clear();
    setState(() {
      _isCreating = false;
      _creatingParentId = null;
    });
  }

  // ── Drag feedback ───────────────────────────────────

  Widget _buildFolderFeedback(Folder folder) => Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: kSurface,
            border: Border.all(color: kMint),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6)
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('‣ ', style: mono(color: kMint, fontSize: 12)),
              Text(folder.name, style: mono(color: kText, fontSize: 12)),
            ],
          ),
        ),
      );

  // ── Drop divider ────────────────────────────────────

  Widget _buildDivider(String? parentId, int insertIndex, int depth) {
    final leftPad = 14.0 + depth * 12.0;
    return DragTarget<Folder>(
      onAcceptWithDetails: (details) {
        widget.onMoveFolder?.call(details.data.id, parentId, insertIndex);
      },
      builder: (context, candidates, _) {
        final isActive = candidates.isNotEmpty;
        return Container(
          height: 8,
          alignment: Alignment.center,
          padding: EdgeInsets.only(left: leftPad, right: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: isActive ? 2.0 : 0.0,
            decoration: BoxDecoration(
              color: kMint,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }

  // ── Folder tree ─────────────────────────────────────

  List<Widget> _buildTree(String? parentId, int depth) {
    final children = widget.folders
        .where((f) => f.parentId == parentId)
        .toList()
      ..sort((a, b) => a.order != b.order
          ? a.order.compareTo(b.order)
          : a.name.compareTo(b.name));

    final widgets = <Widget>[];

    if (!_isCreating && children.isNotEmpty) {
      widgets.add(_buildDivider(parentId, 0, depth));
    }

    for (int i = 0; i < children.length; i++) {
      final folder = children[i];
      final hasChildren = widget.folders.any((f) => f.parentId == folder.id);
      final isExpanded = _isExpanded(folder.id);
      final canSub = depth < _kMaxDepth && !_isCreating;

      widgets.add(
        LongPressDraggable<Folder>(
          data: folder,
          delay: const Duration(milliseconds: 350),
          feedback: _buildFolderFeedback(folder),
          child: DragTarget<Object>(
            onWillAcceptWithDetails: (details) {
              if (details.data is Folder) {
                return (details.data as Folder).id != folder.id;
              }
              return details.data is Memo;
            },
            onAcceptWithDetails: (details) {
              if (details.data is Memo) {
                widget.onMoveMemo?.call(details.data as Memo, folder.id);
              } else if (details.data is Folder) {
                final childCount =
                    widget.folders.where((f) => f.parentId == folder.id).length;
                widget.onMoveFolder?.call(
                    (details.data as Folder).id, folder.id, childCount);
              }
            },
            builder: (context, candidates, _) {
              final isMemoTarget = candidates.any((c) => c is Memo);
              final isFolderNestTarget = candidates.any((c) => c is Folder);
              return _FolderRow(
                key: ValueKey(folder.id),
                folder: folder,
                depth: depth,
                isSelected: widget.selectedId == folder.id,
                atMaxDepth: depth >= _kMaxDepth,
                hasChildren: hasChildren,
                isExpanded: isExpanded,
                count: widget.memoCounts[folder.id] ?? 0,
                isMemoTarget: isMemoTarget,
                isFolderNestTarget: isFolderNestTarget,
                onTap: () => widget.onSelect(folder.id),
                onAddSub: canSub ? () => _startCreate(folder.id) : null,
                onToggleExpand: () => _toggleExpand(folder.id),
                onRename: widget.onRenameFolder != null
                    ? (newName) => widget.onRenameFolder!(folder.id, newName)
                    : null,
              );
            },
          ),
        ),
      );

      if (_isCreating && _creatingParentId == folder.id) {
        widgets.add(_InlineInput(
          ctrl: _ctrl,
          focusNode: _focusNode,
          depth: depth + 1,
          onCancel: _cancel,
          onConfirm: _confirm,
        ));
      }

      // Only recurse when expanded
      if (isExpanded) {
        widgets.addAll(_buildTree(folder.id, depth + 1));
      }

      if (!_isCreating) {
        widgets.add(_buildDivider(parentId, i + 1, depth));
      }
    }

    return widgets;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMemos = widget.memoCounts.values.fold(0, (s, c) => s + c);

    return Container(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────
          Container(
            height: 44,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('~/memo',
                style: mono(color: kMint, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          Container(height: 1, color: kBorder),

          // ── Scrollable content ───────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 4),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                  child: _SectionLabel('folders'),
                ),
                DragTarget<Memo>(
                  onAcceptWithDetails: (details) {
                    widget.onMoveMemo?.call(details.data, null);
                  },
                  builder: (context, candidates, _) => _InboxRow(
                    isSelected:
                        widget.selectedId == null && widget.selectedTag == null,
                    onTap: () => widget.onSelect(null),
                    count: widget.memoCounts[null] ?? 0,
                    isMemoTarget: candidates.isNotEmpty,
                  ),
                ),
                ..._buildTree(null, 0),
                if (_isCreating && _creatingParentId == null)
                  _InlineInput(
                    ctrl: _ctrl,
                    focusNode: _focusNode,
                    depth: 0,
                    onCancel: _cancel,
                    onConfirm: _confirm,
                  ),

                _SystemFolderSection(
                  dayCount: widget.dayCount,
                  habitActivated: widget.habitActivated,
                  goalActivated: widget.goalActivated,
                  streak: widget.streak,
                  onActivateHabit: widget.onActivateHabit,
                  onActivateGoal: widget.onActivateGoal,
                  onSelectHabit: widget.onSelectHabit,
                  onSelectGoal: widget.onSelectGoal,
                ),

                if (widget.allTags.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
                    child: _SectionLabel('tags'),
                  ),
                  ...widget.allTags.map((tag) => _TagRow(
                        tag: tag,
                        count: widget.tagCounts[tag] ?? 0,
                        isSelected: widget.selectedTag == tag,
                        onTap: () => widget.onSelectTag(
                            tag == widget.selectedTag ? null : tag),
                      )),
                ],

                if (widget.recentMemos.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
                    child: _SectionLabel('recent'),
                  ),
                  ...widget.recentMemos.map((memo) => _RecentMemoRow(
                        memo: memo,
                        onTap: () => widget.onSelectRecent?.call(memo),
                      )),
                ],

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
                  child: _SectionLabel('stats'),
                ),
                _StatsBlock(
                  totalMemos: totalMemos,
                  totalFolders: widget.folders.length,
                  totalWords: widget.totalWords,
                  streak: widget.streak,
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),

          Container(height: 1, color: kBorder),
          _TextBtn(
            label: '[+ new folder]',
            color: kTeal,
            onTap: _isCreating ? null : () => _startCreate(null),
          ),
          Container(height: 1, color: kBorder),
          _SettingsRow(onTap: widget.onSettingsTap),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Section label
// ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text,
            style: mono(
                color: kDim.withValues(alpha: 0.55),
                fontSize: 10,
                letterSpacing: 0.5)),
        const SizedBox(width: 6),
        Expanded(child: Container(height: 1, color: kBorder.withValues(alpha: 0.5))),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Inbox row
// ──────────────────────────────────────────────────────────────

class _InboxRow extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final int count;
  final bool isMemoTarget;

  const _InboxRow({
    required this.isSelected,
    required this.onTap,
    required this.count,
    this.isMemoTarget = false,
  });

  @override
  State<_InboxRow> createState() => _InboxRowState();
}

class _InboxRowState extends State<_InboxRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (widget.isMemoTarget) {
      bg = kMint.withValues(alpha: 0.12);
      fg = kMint;
    } else if (widget.isSelected) {
      bg = kMint.withValues(alpha: 0.08);
      fg = kMint;
    } else if (_hovered) {
      bg = kBorder.withValues(alpha: 0.22);
      fg = kText;
    } else {
      bg = Colors.transparent;
      fg = kDim;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: bg,
          padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
          child: Row(
            children: [
              Text('‣ ', style: mono(color: fg, fontSize: 12)),
              Text('inbox', style: mono(color: fg, fontSize: 12)),
              if (widget.count > 0) ...[
                const SizedBox(width: 5),
                Text('(${widget.count})',
                    style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 10)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Folder row — supports collapse/expand + double-tap rename
// ──────────────────────────────────────────────────────────────

class _FolderRow extends StatefulWidget {
  final Folder folder;
  final int depth;
  final bool isSelected;
  final bool atMaxDepth;
  final bool hasChildren;
  final bool isExpanded;
  final int count;
  final bool isMemoTarget;
  final bool isFolderNestTarget;
  final VoidCallback onTap;
  final VoidCallback? onAddSub;
  final VoidCallback? onToggleExpand;
  final void Function(String newName)? onRename;

  const _FolderRow({
    super.key,
    required this.folder,
    required this.depth,
    required this.isSelected,
    required this.atMaxDepth,
    required this.hasChildren,
    required this.isExpanded,
    required this.count,
    this.isMemoTarget = false,
    this.isFolderNestTarget = false,
    required this.onTap,
    this.onAddSub,
    this.onToggleExpand,
    this.onRename,
  });

  @override
  State<_FolderRow> createState() => _FolderRowState();
}

class _FolderRowState extends State<_FolderRow> {
  bool _hovered = false;
  bool _addHovered = false;
  bool _isRenaming = false;
  DateTime? _lastTapTime;
  late final TextEditingController _renameCtrl;
  late final FocusNode _renameFocus;

  @override
  void initState() {
    super.initState();
    _renameCtrl = TextEditingController();
    _renameFocus = FocusNode();
    _renameFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          setState(() => _isRenaming = false);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          _submitRename();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _renameCtrl.dispose();
    _renameFocus.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onRename != null) {
      final now = DateTime.now();
      if (_lastTapTime != null &&
          now.difference(_lastTapTime!).inMilliseconds < 400) {
        _lastTapTime = null;
        _startRename();
        return;
      }
      _lastTapTime = now;
    }
    widget.onTap();
  }

  void _startRename() {
    _renameCtrl.text = widget.folder.name;
    setState(() => _isRenaming = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _renameFocus.requestFocus();
      _renameCtrl.selection =
          TextSelection(baseOffset: 0, extentOffset: _renameCtrl.text.length);
    });
  }

  void _submitRename() {
    final name = _renameCtrl.text.trim();
    if (name.isNotEmpty) widget.onRename?.call(name);
    setState(() => _isRenaming = false);
  }

  Widget _expandIcon(Color fg) {
    final icon = widget.hasChildren
        ? (widget.isExpanded ? '▾ ' : '▸ ')
        : '‣ ';
    if (widget.hasChildren) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggleExpand,
        child: Text(icon, style: mono(color: fg, fontSize: 12)),
      );
    }
    return Text(icon, style: mono(color: fg, fontSize: 12));
  }

  @override
  Widget build(BuildContext context) {
    if (_isRenaming) return _buildRenameMode();
    return _buildViewMode();
  }

  Widget _buildRenameMode() {
    final leftPad = 14.0 + widget.depth * 12.0;
    return Container(
      color: kSurface,
      padding: EdgeInsets.fromLTRB(leftPad, 3, 10, 3),
      child: Row(
        children: [
          _expandIcon(kMint),
          Expanded(
            child: TextField(
              controller: _renameCtrl,
              focusNode: _renameFocus,
              style: mono(color: kText, fontSize: 12),
              cursorColor: kTeal,
              cursorWidth: 2,
              onSubmitted: (_) => _submitRename(),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                filled: true,
                fillColor: kBg,
                hintText: widget.folder.name,
                hintStyle: mono(color: kDim, fontSize: 11),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: kTeal),
                  borderRadius: BorderRadius.zero,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: kTeal),
                  borderRadius: BorderRadius.zero,
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: kTeal, width: 1.5),
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _submitRename,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text('[↵]', style: mono(color: kTeal, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewMode() {
    final leftPad = 14.0 + widget.depth * 12.0;

    final Color fg;
    if (widget.isMemoTarget || widget.isFolderNestTarget) {
      fg = kMint;
    } else if (widget.isSelected) {
      fg = kMint;
    } else if (_hovered) {
      fg = kText;
    } else {
      fg = kDim;
    }

    final BoxDecoration decoration;
    if (widget.isFolderNestTarget) {
      decoration = BoxDecoration(
        color: kTeal.withValues(alpha: 0.1),
        border: Border.all(color: kTeal.withValues(alpha: 0.55), width: 1),
      );
    } else if (widget.isMemoTarget) {
      decoration = BoxDecoration(color: kMint.withValues(alpha: 0.12));
    } else if (widget.isSelected) {
      decoration = BoxDecoration(color: kMint.withValues(alpha: 0.08));
    } else if (_hovered) {
      decoration = BoxDecoration(color: kBorder.withValues(alpha: 0.22));
    } else {
      decoration = const BoxDecoration(color: Colors.transparent);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: decoration,
          padding: EdgeInsets.fromLTRB(leftPad, 4, 10, 4),
          child: Row(
            children: [
              _expandIcon(fg),
              Expanded(
                child: Text(
                  widget.folder.name,
                  style: mono(color: fg, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.count > 0 &&
                  !_hovered &&
                  !widget.isMemoTarget &&
                  !widget.isFolderNestTarget)
                Text('(${widget.count})',
                    style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 10)),
              if (_hovered) ...[
                const SizedBox(width: 4),
                if (widget.atMaxDepth)
                  Tooltip(
                    message: '최대 5단계까지 가능합니다',
                    preferBelow: false,
                    child: Text('[5/5]',
                        style: mono(
                            color: kDim.withValues(alpha: 0.4), fontSize: 9)),
                  )
                else if (widget.onAddSub != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onAddSub,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _addHovered = true),
                      onExit: (_) => setState(() => _addHovered = false),
                      child: Text('[+]',
                          style: mono(
                              color: _addHovered ? kMint : kTeal,
                              fontSize: 10)),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Tag row
// ──────────────────────────────────────────────────────────────

class _TagRow extends StatefulWidget {
  final String tag;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _TagRow({
    required this.tag,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TagRow> createState() => _TagRowState();
}

class _TagRowState extends State<_TagRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.isSelected ? kMint : (_hovered ? kText : kDim);
    final bg = widget.isSelected
        ? kMint.withValues(alpha: 0.08)
        : (_hovered ? kBorder.withValues(alpha: 0.22) : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: bg,
          padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
          child: Row(
            children: [
              Text(widget.isSelected ? '> ' : '  ',
                  style: mono(color: kMint, fontSize: 12)),
              Expanded(
                child: Text('#${widget.tag}',
                    style: mono(color: fg, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('(${widget.count})',
                  style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Recent memo row
// ──────────────────────────────────────────────────────────────

class _RecentMemoRow extends StatefulWidget {
  final Memo memo;
  final VoidCallback onTap;

  const _RecentMemoRow({required this.memo, required this.onTap});

  @override
  State<_RecentMemoRow> createState() => _RecentMemoRowState();
}

class _RecentMemoRowState extends State<_RecentMemoRow> {
  bool _hovered = false;
  static final _tagRe = RegExp(r'#[a-zA-Z가-힣][a-zA-Z0-9_가-힣]*');

  String get _preview {
    final firstLine = widget.memo.content.split('\n').first;
    final cleaned = firstLine
        .replaceAll(_tagRe, '')
        .replaceAll(RegExp(r'^- \[[ x]\] '), '')
        .trim();
    return cleaned.isEmpty ? '...' : cleaned;
  }

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
          color: _hovered ? kBorder.withValues(alpha: 0.22) : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(14, 5, 10, 5),
          child: Row(
            children: [
              Text('[${widget.memo.timeStr}]',
                  style: mono(color: kDim.withValues(alpha: 0.6), fontSize: 10)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_preview,
                    style: mono(color: kDim, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Stats block
// ──────────────────────────────────────────────────────────────

class _StatsBlock extends StatelessWidget {
  final int totalMemos;
  final int totalFolders;
  final int totalWords;
  final int streak;

  const _StatsBlock({
    required this.totalMemos,
    required this.totalFolders,
    required this.totalWords,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('memos', '$totalMemos'),
      ('folders', '$totalFolders'),
      ('words', '$totalWords'),
      ('streak', '${streak}d'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows.map((r) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text(r.$1,
                      style:
                          mono(color: kDim.withValues(alpha: 0.5), fontSize: 10)),
                ),
                Text(r.$2, style: mono(color: kDim, fontSize: 10)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Inline folder name input
// ──────────────────────────────────────────────────────────────

class _InlineInput extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final int depth;

  const _InlineInput({
    required this.ctrl,
    required this.focusNode,
    required this.onCancel,
    required this.onConfirm,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    final leftPad = 14.0 + depth * 12.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(leftPad, 3, 10, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('  ', style: mono(fontSize: 12)),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  focusNode: focusNode,
                  style: mono(color: kText, fontSize: 12),
                  cursorColor: kTeal,
                  cursorWidth: 2,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onConfirm(),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    filled: true,
                    fillColor: kBg,
                    hintText: 'folder name...',
                    hintStyle: mono(color: kDim, fontSize: 11),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: kTeal),
                      borderRadius: BorderRadius.zero,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: kTeal),
                      borderRadius: BorderRadius.zero,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: kTeal, width: 1.5),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _ConfirmBtn(onTap: onConfirm),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 2),
            child: Text('↵ create  Esc cancel',
                style: mono(color: kDim.withValues(alpha: 0.4), fontSize: 9)),
          ),
        ],
      ),
    );
  }
}

class _ConfirmBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _ConfirmBtn({required this.onTap});

  @override
  State<_ConfirmBtn> createState() => _ConfirmBtnState();
}

class _ConfirmBtnState extends State<_ConfirmBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered ? kTeal.withValues(alpha: 0.15) : Colors.transparent,
          ),
          child: Text('[↵]', style: mono(color: kTeal, fontSize: 11)),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Bottom text button
// ──────────────────────────────────────────────────────────────

class _TextBtn extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _TextBtn({required this.label, required this.color, this.onTap});

  @override
  State<_TextBtn> createState() => _TextBtnState();
}

class _TextBtnState extends State<_TextBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null;
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: active && _hovered
              ? widget.color.withValues(alpha: 0.08)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            widget.label,
            style: mono(
              color: active
                  ? (_hovered ? widget.color : widget.color.withValues(alpha: 0.55))
                  : kDim.withValues(alpha: 0.3),
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Settings row
// ──────────────────────────────────────────────────────────────

class _SettingsRow extends StatefulWidget {
  final VoidCallback onTap;
  const _SettingsRow({required this.onTap});

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
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
          color: _hovered ? kDim.withValues(alpha: 0.07) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.settings_outlined,
                  size: 13, color: _hovered ? kText : kDim),
              const SizedBox(width: 8),
              Text('settings',
                  style: mono(color: _hovered ? kText : kDim, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// System folder section — habit + goal
// ──────────────────────────────────────────────────────────────

class _SystemFolderSection extends StatelessWidget {
  final int dayCount;
  final bool habitActivated;
  final bool goalActivated;
  final int streak;
  final void Function(String name) onActivateHabit;
  final void Function(String name) onActivateGoal;
  final VoidCallback? onSelectHabit;
  final VoidCallback? onSelectGoal;

  const _SystemFolderSection({
    required this.dayCount,
    required this.habitActivated,
    required this.goalActivated,
    required this.streak,
    required this.onActivateHabit,
    required this.onActivateGoal,
    this.onSelectHabit,
    this.onSelectGoal,
  });

  void _showNameDialog(BuildContext context, {required bool isHabit}) {
    final ctrl = TextEditingController();
    final focusNode = FocusNode();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());
        return _SystemNameDialog(
          isHabit: isHabit,
          ctrl: ctrl,
          focusNode: focusNode,
          onConfirm: (name) {
            Navigator.pop(dialogCtx);
            if (isHabit) {
              onActivateHabit(name);
            } else {
              onActivateGoal(name);
            }
          },
          onCancel: () => Navigator.pop(dialogCtx),
        );
      },
    );
  }

  void _showHabitSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: kTeal, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: _HabitSheetContent(
          dayCount: dayCount,
          streak: streak,
          onActivate: () {
            Navigator.pop(sheetCtx);
            _showNameDialog(context, isHabit: true);
          },
          onLater: () => Navigator.pop(sheetCtx),
        ),
      ),
    );
  }

  void _showGoalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: kTeal, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: _GoalSheetContent(
          dayCount: dayCount,
          onActivate: () {
            Navigator.pop(sheetCtx);
            _showNameDialog(context, isHabit: false);
          },
          onLater: () => Navigator.pop(sheetCtx),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goalDim = !goalActivated && dayCount < 14;
    final goalNew = !goalActivated && dayCount >= 14;

    String? habitBadge;
    if (habitActivated && dayCount >= 5) {
      habitBadge = '[ACTIVE]  streak ${streak}d';
    } else if (habitActivated) {
      habitBadge = '[ACTIVE]  $dayCount일';
    }

    final String? goalBadge = goalNew ? '[NEW]' : null;
    final String? goalSubtext = goalDim
        ? '// ${14 - dayCount}일 더 기록하면 열려요'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SystemFolderRow(
          label: '습관',
          badge: habitBadge,
          opacity: 1.0,
          subtext: null,
          onTap: () {
            if (habitActivated) {
              onSelectHabit?.call();
            } else {
              _showHabitSheet(context);
            }
          },
        ),
        _SystemFolderRow(
          label: '목표',
          badge: goalBadge,
          opacity: goalDim ? 0.4 : 1.0,
          subtext: goalSubtext,
          onTap: () {
            if (goalActivated) {
              onSelectGoal?.call();
            } else {
              _showGoalSheet(context);
            }
          },
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// System folder row
// ──────────────────────────────────────────────────────────────

class _SystemFolderRow extends StatefulWidget {
  final String label;
  final String? badge;
  final double opacity;
  final String? subtext;
  final VoidCallback onTap;

  const _SystemFolderRow({
    required this.label,
    this.badge,
    required this.opacity,
    this.subtext,
    required this.onTap,
  });

  @override
  State<_SystemFolderRow> createState() => _SystemFolderRowState();
}

class _SystemFolderRowState extends State<_SystemFolderRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fg = _hovered ? kText : kDim;
    final Color bg =
        _hovered ? kBorder.withValues(alpha: 0.22) : Colors.transparent;

    return Opacity(
      opacity: widget.opacity,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            color: bg,
            padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('‣ ', style: mono(color: fg, fontSize: 12)),
                    Text(widget.label, style: mono(color: fg, fontSize: 12)),
                    if (widget.badge != null) ...[
                      const SizedBox(width: 6),
                      Text(widget.badge!,
                          style: mono(color: kTeal, fontSize: 10)),
                    ],
                  ],
                ),
                if (widget.subtext != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 1),
                    child: Text(widget.subtext!,
                        style: mono(
                            color: kDim.withValues(alpha: 0.55), fontSize: 9)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Streak dots helper
// ──────────────────────────────────────────────────────────────

Widget _buildStreakDots(int count, {int max = 7}) {
  final filled = count.clamp(0, max);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      filled,
      (_) => Text('●', style: mono(color: kMint, fontSize: 9)),
    ),
  );
}

Widget _buildGoalProgressDots(int dayCount) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(14, (i) {
      final filled = i < dayCount;
      return Text(
        filled ? '●' : '○',
        style: mono(
          color: filled ? kMint : kDim.withValues(alpha: 0.35),
          fontSize: 9,
        ),
      );
    }),
  );
}

// ──────────────────────────────────────────────────────────────
// Habit bottom sheet content
// ──────────────────────────────────────────────────────────────

class _HabitSheetContent extends StatelessWidget {
  final int dayCount;
  final int streak;
  final VoidCallback onActivate;
  final VoidCallback onLater;

  const _HabitSheetContent({
    required this.dayCount,
    required this.streak,
    required this.onActivate,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final String body;
    final String actionLabel;
    final String laterLabel;

    if (dayCount >= 14) {
      body = '"2주 됐어요. 잘하고 있어요."\n"이제 큰 그림도 그릴 수 있어요.\n 목표 폴더도 열렸으니 살펴보세요."';
      actionLabel = '[ 습관 관리 ]';
      laterLabel = '[ 나중에 ]';
    } else if (dayCount >= 7) {
      body = '"일주일째네요."\n"습관을 좀 더 단단히 들여볼 때예요."';
      actionLabel = '[ 단단히 하기 ]';
      laterLabel = '[ 나중에 ]';
    } else if (dayCount >= 5) {
      body = '"벌써 $dayCount일째예요!"\n"슬슬 습관 하나 잡아볼까요? 작은 것도 괜찮아요."';
      actionLabel = '[ 만들기 ]';
      laterLabel = '[ 아직은요 ]';
    } else {
      body = '"습관 하나 만들어볼까요?"\n"탭 한 번이면 기록돼요.\n 그 이상은… 하다 보면 알게 돼요."';
      actionLabel = '[ 해보기 ]';
      laterLabel = '[ 나중에 ]';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dayCount >= 5)
          Row(
            children: [
              Text('[ 습관 ]  ',
                  style: mono(color: kMint, fontSize: 13, letterSpacing: 0.5)),
              _buildStreakDots(dayCount),
              Text('  $dayCount일', style: mono(color: kDim, fontSize: 11)),
            ],
          )
        else
          Text('[ 습관 ]',
              style: mono(color: kMint, fontSize: 13, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(height: 1, color: kBorder.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text(body, style: mono(color: kDim, fontSize: 12, height: 1.7)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _SheetBtn(label: laterLabel, filled: false, onTap: onLater),
            const SizedBox(width: 10),
            _SheetBtn(label: actionLabel, filled: true, onTap: onActivate),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Goal bottom sheet content
// ──────────────────────────────────────────────────────────────

class _GoalSheetContent extends StatelessWidget {
  final int dayCount;
  final VoidCallback onActivate;
  final VoidCallback onLater;

  const _GoalSheetContent({
    required this.dayCount,
    required this.onActivate,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    if (dayCount < 14) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('[ goals ]',
              style: mono(color: kMint, fontSize: 13, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Container(height: 1, color: kBorder.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('// 아직 열리지 않았어요.',
              style: mono(color: kDim, fontSize: 12)),
          const SizedBox(height: 6),
          Text('  Day $dayCount  —  ${14 - dayCount}일 후에 만나요.',
              style: mono(color: kDim.withValues(alpha: 0.7), fontSize: 11)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: _buildGoalProgressDots(dayCount),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _SheetBtn(label: '[ 알겠어요 ]', filled: true, onTap: onLater),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('[ goals ]',
            style: mono(color: kMint, fontSize: 13, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(height: 1, color: kBorder.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text(
          '"목표를 세워볼 때가 됐어요."\n"2주 꾸준히 했으니까요.\n 큰 그림을 한번 그려볼까요?"',
          style: mono(color: kDim, fontSize: 12, height: 1.7),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _SheetBtn(label: '[ 나중에 ]', filled: false, onTap: onLater),
            const SizedBox(width: 10),
            _SheetBtn(label: '[ 목표 만들기 ]', filled: true, onTap: onActivate),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Bottom sheet button
// ──────────────────────────────────────────────────────────────

class _SheetBtn extends StatefulWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _SheetBtn({
    required this.label,
    required this.filled,
    required this.onTap,
  });

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
            color: widget.filled
                ? (_hovered ? kMint.withValues(alpha: 0.85) : kTeal)
                : (_hovered ? kBorder.withValues(alpha: 0.3) : Colors.transparent),
            border: widget.filled
                ? null
                : Border.all(color: kTeal.withValues(alpha: 0.4)),
          ),
          child: Text(widget.label,
              style: mono(
                  color: widget.filled ? kBg : kDim.withValues(alpha: 0.7),
                  fontSize: 12)),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// System name input dialog
// ──────────────────────────────────────────────────────────────

class _SystemNameDialog extends StatefulWidget {
  final bool isHabit;
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final void Function(String name) onConfirm;
  final VoidCallback onCancel;

  const _SystemNameDialog({
    required this.isHabit,
    required this.ctrl,
    required this.focusNode,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_SystemNameDialog> createState() => _SystemNameDialogState();
}

class _SystemNameDialogState extends State<_SystemNameDialog> {
  void _submit() {
    final name = widget.ctrl.text.trim();
    if (name.isNotEmpty) widget.onConfirm(name);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isHabit ? '[ 습관 이름 ]' : '[ 목표 이름 ]';
    final hint =
        widget.isHabit ? '예) 물 마시기, 30분 독서' : '예) 올해 책 12권 읽기';

    return Dialog(
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: mono(color: kMint, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 10),
            Container(height: 1, color: kBorder),
            const SizedBox(height: 12),
            TextField(
              controller: widget.ctrl,
              focusNode: widget.focusNode,
              style: mono(color: kText, fontSize: 12),
              cursorColor: kTeal,
              cursorWidth: 2,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                filled: true,
                fillColor: kBg,
                hintText: hint,
                hintStyle: mono(color: kDim, fontSize: 11),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: kTeal),
                  borderRadius: BorderRadius.zero,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: kTeal),
                  borderRadius: BorderRadius.zero,
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: kTeal, width: 1.5),
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _SheetBtn(
                    label: '[ 취소 ]', filled: false, onTap: widget.onCancel),
                const SizedBox(width: 10),
                _SheetBtn(label: '[ 확인 ]', filled: true, onTap: _submit),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
