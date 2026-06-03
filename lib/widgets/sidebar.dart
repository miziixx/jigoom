import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../models/folder.dart';

const _kDiv = '──────────────';

List<Folder> _sortedTopFolders(List<Folder> folders) {
  final top = folders.where((f) => f.parentId == null).toList();
  top.sort((a, b) =>
      a.order != b.order ? a.order.compareTo(b.order) : a.name.compareTo(b.name));
  return top;
}

class Sidebar extends StatefulWidget {
  final VoidCallback onSelectMemo;
  final VoidCallback onSelectCalendar;
  final VoidCallback onSelectTasks;
  final VoidCallback onSelectTags;
  final VoidCallback onSelectStats;
  final VoidCallback onSelectSchedule;
  final VoidCallback onSettingsTap;
  final void Function(String name, String? parentId) onCreate;
  final String activeSection; // 'memo','calendar','tasks','habits','goals','tags','stats'
  final List<Folder> folders;
  final String? selectedFolderId;
  final ValueChanged<String?> onSelectFolder;
  final int dayCount;
  final bool habitActivated;
  final bool goalActivated;
  final int streak;
  final void Function(String name) onActivateHabit;
  final void Function(String name) onActivateGoal;
  final VoidCallback? onSelectHabit;
  final VoidCallback? onSelectGoal;
  final int noteCount;
  final int taskCount;
  final int habitCount;

  const Sidebar({
    super.key,
    required this.onSelectMemo,
    required this.onSelectCalendar,
    required this.onSelectTasks,
    required this.onSelectTags,
    required this.onSelectStats,
    required this.onSelectSchedule,
    required this.onSettingsTap,
    required this.onCreate,
    required this.activeSection,
    required this.folders,
    required this.selectedFolderId,
    required this.onSelectFolder,
    required this.dayCount,
    required this.habitActivated,
    required this.goalActivated,
    required this.streak,
    required this.onActivateHabit,
    required this.onActivateGoal,
    this.onSelectHabit,
    this.onSelectGoal,
    required this.noteCount,
    required this.taskCount,
    required this.habitCount,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isCreating = false;
  bool _memoExpanded = true; // 기본값: 펼쳐진 상태
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

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

  void _startCreate() {
    setState(() => _isCreating = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _confirm() {
    final name = _ctrl.text.trim();
    if (name.isNotEmpty) widget.onCreate(name, null);
    _ctrl.clear();
    setState(() => _isCreating = false);
  }

  void _cancel() {
    _ctrl.clear();
    setState(() => _isCreating = false);
  }

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
              widget.onActivateHabit(name);
            } else {
              widget.onActivateGoal(name);
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
          dayCount: widget.dayCount,
          streak: widget.streak,
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
          dayCount: widget.dayCount,
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
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Container(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── /MENU header ────────────────────────────
          Container(
            height: 44,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '/MENU',
              style: mono(
                  color: kMint,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5),
            ),
          ),
          Container(height: 1, color: kBorder),

          // ── Scrollable content ───────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 4),
              children: [
                _DivRow(),
                _MemoExpandRow(
                  isActive: widget.activeSection == 'memo',
                  isExpanded: _memoExpanded,
                  onTap: widget.onSelectMemo,
                  onToggle: () => setState(() => _memoExpanded = !_memoExpanded),
                ),
                if (_memoExpanded) ...[
                  _SubFolderRow(
                    label: 'inbox',
                    isActive: widget.activeSection == 'memo' &&
                        widget.selectedFolderId == null,
                    onTap: () => widget.onSelectFolder(null),
                  ),
                  ..._sortedTopFolders(widget.folders).map((f) => _SubFolderRow(
                        label: f.name,
                        isActive: widget.activeSection == 'memo' &&
                            widget.selectedFolderId == f.id,
                        onTap: () => widget.onSelectFolder(f.id),
                      )),
                ],
                _MenuRow(
                  label: 'calendar',
                  isActive: widget.activeSection == 'calendar',
                  onTap: widget.onSelectCalendar,
                ),
                _MenuRow(
                  label: 'tasks',
                  isActive: widget.activeSection == 'tasks',
                  onTap: widget.onSelectTasks,
                ),
                _HabitMenuRow(
                  dayCount: widget.dayCount,
                  habitActivated: widget.habitActivated,
                  streak: widget.streak,
                  isActive: widget.activeSection == 'habits',
                  onTap: () {
                    if (widget.habitActivated) {
                      widget.onSelectHabit?.call();
                    } else {
                      _showHabitSheet(context);
                    }
                  },
                ),
                _GoalMenuRow(
                  dayCount: widget.dayCount,
                  goalActivated: widget.goalActivated,
                  isActive: widget.activeSection == 'goals',
                  onTap: () {
                    if (widget.goalActivated) {
                      widget.onSelectGoal?.call();
                    } else {
                      _showGoalSheet(context);
                    }
                  },
                ),
                _MenuRow(
                  label: 'tags',
                  isActive: widget.activeSection == 'tags',
                  onTap: widget.onSelectTags,
                ),
                _MenuRow(
                  label: 'stats',
                  isActive: widget.activeSection == 'stats',
                  onTap: widget.onSelectStats,
                ),
                _MenuRow(
                  label: 'schedule',
                  isActive: widget.activeSection == 'schedule',
                  onTap: widget.onSelectSchedule,
                ),
                _DivRow(),
                _MenuRow(
                  label: 'settings',
                  isActive: false,
                  onTap: widget.onSettingsTap,
                ),
                _DivRow(),

                // ── /SYSTEM header ──────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  child: Text(
                    '/SYSTEM',
                    style: mono(
                        color: kMint.withValues(alpha: 0.65),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2),
                  ),
                ),
                _DivRow(),
                _SystemBlock(
                  noteCount: widget.noteCount,
                  taskCount: widget.taskCount,
                  habitCount: widget.habitCount,
                  streak: widget.streak,
                  dateStr: dateStr,
                ),
                _DivRow(),
                const SizedBox(height: 4),
              ],
            ),
          ),

          Container(height: 1, color: kBorder),
          _TextBtn(
            label: '[+ new folder]',
            color: kTeal,
            onTap: _isCreating ? null : _startCreate,
          ),
          if (_isCreating)
            _InlineInput(
              ctrl: _ctrl,
              focusNode: _focusNode,
              depth: 0,
              onCancel: _cancel,
              onConfirm: _confirm,
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Divider row
// ──────────────────────────────────────────────────────────────

class _DivRow extends StatelessWidget {
  const _DivRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 3, 14, 3),
      child: Text(
        _kDiv,
        style: mono(color: kBorder, fontSize: 11),
        overflow: TextOverflow.clip,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Generic menu row
// ──────────────────────────────────────────────────────────────

class _MenuRow extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isSub;

  const _MenuRow({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isSub = false,
  });

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fg = widget.isActive
        ? kMint
        : (_hovered ? kText : kDim);
    final Color bg = widget.isActive
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
          padding: const EdgeInsets.fromLTRB(14, 5, 10, 5),
          child: Row(
            children: [
              if (widget.isSub) ...[
                Text('  └ ',
                    style: mono(color: fg, fontSize: 12)),
              ] else ...[
                Text('> ', style: mono(color: fg, fontSize: 12)),
              ],
              Text(widget.label, style: mono(color: fg, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Memo expand/collapse row  (> memo ▾/▸)
// ──────────────────────────────────────────────────────────────

class _MemoExpandRow extends StatefulWidget {
  final bool isActive;
  final bool isExpanded;
  final VoidCallback onTap;    // navigates to inbox
  final VoidCallback onToggle; // toggles expand/collapse

  const _MemoExpandRow({
    required this.isActive,
    required this.isExpanded,
    required this.onTap,
    required this.onToggle,
  });

  @override
  State<_MemoExpandRow> createState() => _MemoExpandRowState();
}

class _MemoExpandRowState extends State<_MemoExpandRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fg = widget.isActive
        ? kMint
        : (_hovered ? kText : kDim);
    final Color bg = widget.isActive
        ? kMint.withValues(alpha: 0.08)
        : (_hovered ? kBorder.withValues(alpha: 0.22) : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: bg,
        padding: const EdgeInsets.fromLTRB(14, 5, 10, 5),
        child: Row(
          children: [
            GestureDetector(
              onTap: widget.onTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('> ', style: mono(color: fg, fontSize: 12)),
                  Text('memo', style: mono(color: fg, fontSize: 12)),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                child: Text(
                  widget.isExpanded ? '▾' : '▸',
                  style: mono(color: fg.withValues(alpha: 0.6), fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Sub-folder row  (└ inbox / └ 폴더명)
// ──────────────────────────────────────────────────────────────

class _SubFolderRow extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SubFolderRow({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SubFolderRow> createState() => _SubFolderRowState();
}

class _SubFolderRowState extends State<_SubFolderRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fg = widget.isActive
        ? kMint
        : (_hovered ? kText : kDim);
    final Color bg = widget.isActive
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
          padding: const EdgeInsets.fromLTRB(14, 5, 10, 5),
          child: Row(
            children: [
              Text('  └ ', style: mono(color: fg, fontSize: 12)),
              Expanded(
                child: Text(
                  widget.label,
                  style: mono(color: fg, fontSize: 12),
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
// Habits menu row (with streak dots when active)
// ──────────────────────────────────────────────────────────────

class _HabitMenuRow extends StatefulWidget {
  final int dayCount;
  final bool habitActivated;
  final int streak;
  final bool isActive;
  final VoidCallback onTap;

  const _HabitMenuRow({
    required this.dayCount,
    required this.habitActivated,
    required this.streak,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_HabitMenuRow> createState() => _HabitMenuRowState();
}

class _HabitMenuRowState extends State<_HabitMenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fg = widget.isActive
        ? kMint
        : (_hovered ? kText : kDim);
    final Color bg = widget.isActive
        ? kMint.withValues(alpha: 0.08)
        : (_hovered ? kBorder.withValues(alpha: 0.22) : Colors.transparent);

    Widget? badge;
    if (widget.habitActivated && widget.dayCount >= 5) {
      badge = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 5),
          _buildStreakDots(widget.streak.clamp(0, 7)),
          const SizedBox(width: 4),
          Text('${widget.streak}d',
              style: mono(color: kTeal, fontSize: 9)),
        ],
      );
    } else if (widget.habitActivated) {
      badge = Padding(
        padding: const EdgeInsets.only(left: 5),
        child: Text('${widget.dayCount}일',
            style: mono(color: kTeal, fontSize: 9)),
      );
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
          padding: const EdgeInsets.fromLTRB(14, 5, 10, 5),
          child: Row(
            children: [
              Text('> ', style: mono(color: fg, fontSize: 12)),
              Text('habits', style: mono(color: fg, fontSize: 12)),
              if (badge != null) badge,
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Goals menu row (dim + progress when locked)
// ──────────────────────────────────────────────────────────────

class _GoalMenuRow extends StatefulWidget {
  final int dayCount;
  final bool goalActivated;
  final bool isActive;
  final VoidCallback onTap;

  const _GoalMenuRow({
    required this.dayCount,
    required this.goalActivated,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_GoalMenuRow> createState() => _GoalMenuRowState();
}

class _GoalMenuRowState extends State<_GoalMenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final locked = !widget.goalActivated && widget.dayCount < 14;
    final opacity = locked ? 0.45 : 1.0;

    final Color fg = widget.isActive
        ? kMint
        : (_hovered ? kText : kDim);
    final Color bg = widget.isActive
        ? kMint.withValues(alpha: 0.08)
        : (_hovered ? kBorder.withValues(alpha: 0.22) : Colors.transparent);

    Widget? badge;
    if (!widget.goalActivated && widget.dayCount >= 14) {
      badge = Padding(
        padding: const EdgeInsets.only(left: 5),
        child: Text('[NEW]', style: mono(color: kTeal, fontSize: 9)),
      );
    } else if (locked) {
      badge = Padding(
        padding: const EdgeInsets.only(left: 5),
        child: Text('${14 - widget.dayCount}d',
            style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 9)),
      );
    }

    return Opacity(
      opacity: opacity,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            color: bg,
            padding: const EdgeInsets.fromLTRB(14, 5, 10, 5),
            child: Row(
              children: [
                Text('> ', style: mono(color: fg, fontSize: 12)),
                Text('goals', style: mono(color: fg, fontSize: 12)),
                if (badge != null) badge,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// /SYSTEM data block
// ──────────────────────────────────────────────────────────────

class _SystemBlock extends StatelessWidget {
  final int noteCount;
  final int taskCount;
  final int habitCount;
  final int streak;
  final String dateStr;

  const _SystemBlock({
    required this.noteCount,
    required this.taskCount,
    required this.habitCount,
    required this.streak,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('notes', '$noteCount'),
      ('tasks', '$taskCount'),
      ('events', '0'),
      ('habits', '$habitCount'),
      ('streak', '${streak}d'),
      ('date', dateStr),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows.map((r) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 62,
                  child: Text(
                    r.$1,
                    style: mono(
                        color: kDim.withValues(alpha: 0.5), fontSize: 10),
                  ),
                ),
                Text(': ',
                    style: mono(
                        color: kDim.withValues(alpha: 0.4), fontSize: 10)),
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
              Text('[ habits ]  ',
                  style: mono(color: kMint, fontSize: 13, letterSpacing: 0.5)),
              _buildStreakDots(dayCount),
              Text('  $dayCount일', style: mono(color: kDim, fontSize: 11)),
            ],
          )
        else
          Text('[ habits ]',
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
    final hint = widget.isHabit ? '예) 물 마시기, 30분 독서' : '예) 올해 책 12권 읽기';

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
