import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../flavor.dart';
import '../models/folder.dart';
import '../models/quick_tab.dart';

class Sidebar extends StatefulWidget {
  final VoidCallback onSelectMemo;
  final VoidCallback onSelectCalendar;
  final VoidCallback onSelectToday;
  final VoidCallback onSelectTasks;
  final VoidCallback onSelectTags;
  final VoidCallback onSelectSearch;
  final VoidCallback onSelectStats;
  final VoidCallback onSelectSchedule;
  final VoidCallback? onSelectGraph;
  final VoidCallback? onSelectBrain;
  final VoidCallback onSettingsTap;
  final void Function(String name, String? parentId) onCreate;
  final void Function(String id, String name) onRenameFolder;
  final void Function(String id) onDeleteFolder;
  final void Function(String id, String? parentId, int insertIndex)
  onMoveFolder;
  final String
  activeSection; // 'memo','calendar','today','tasks','habits','goals','tags','stats'
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

  // nemo (non-nemo2) tag navigation
  final List<String> allTags;
  final Map<String, int> tagCounts;
  final String? selectedTag;
  final void Function(String tag)? onSelectTag;

  // logroom: favorites (QuickTabs displayed as ★ shortcuts at top of sidebar)
  final List<QuickTab> favorites;
  final void Function(QuickTab)? onSelectFavorite;

  const Sidebar({
    super.key,
    required this.onSelectMemo,
    required this.onSelectCalendar,
    required this.onSelectToday,
    required this.onSelectTasks,
    required this.onSelectTags,
    required this.onSelectSearch,
    required this.onSelectStats,
    required this.onSelectSchedule,
    required this.onSettingsTap,
    this.onSelectGraph,
    this.onSelectBrain,
    required this.onCreate,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    required this.onMoveFolder,
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
    this.allTags = const [],
    this.tagCounts = const {},
    this.selectedTag,
    this.onSelectTag,
    this.favorites = const [],
    this.onSelectFavorite,
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
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

  List<Widget> _buildFolderRows(String? parentId, int depth) {
    if (depth >= 5) return const [];
    final folders = _sortedChildFolders(widget.folders, parentId);
    final rows = <Widget>[];
    for (final entry in folders.asMap().entries) {
      final index = entry.key;
      final folder = entry.value;
      final childCount = _sortedChildFolders(widget.folders, folder.id).length;
      rows.add(
        _SubFolderRow(
          id: folder.id,
          parentId: parentId,
          depth: depth,
          orderIndex: index,
          label: folder.name,
          isActive:
              widget.activeSection == 'memo' &&
              widget.selectedFolderId == folder.id,
          canMoveInto: depth < 4,
          childCount: childCount,
          onTap: () => widget.onSelectFolder(folder.id),
          onRename: (name) => widget.onRenameFolder(folder.id, name),
          onDelete: () => widget.onDeleteFolder(folder.id),
          onMove: (id, targetParentId, insertIndex) =>
              widget.onMoveFolder(id, targetParentId, insertIndex),
        ),
      );
      rows.addAll(_buildFolderRows(folder.id, depth + 1));
    }
    return rows;
  }

  void _showNameDialog(BuildContext context, {required bool isHabit}) {
    final ctrl = TextEditingController();
    final focusNode = FocusNode();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => focusNode.requestFocus(),
        );
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

    if (isLogroomUi) return _buildLogroomSidebar(dateStr);

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
                letterSpacing: 1.5,
              ),
            ),
          ),
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
                  onToggle: () =>
                      setState(() => _memoExpanded = !_memoExpanded),
                ),
                if (_memoExpanded) ...[
                  _SubFolderRow(
                    label: 'inbox',
                    isActive:
                        widget.activeSection == 'memo' &&
                        widget.selectedFolderId == null,
                    onTap: () => widget.onSelectFolder(null),
                  ),
                  ..._buildFolderRows(null, 0),
                ],
                _MenuRow(
                  label: 'calendar',
                  isActive: widget.activeSection == 'calendar',
                  onTap: widget.onSelectCalendar,
                ),
                if (isNemo2) ...[
                  _MenuRow(
                    label: 'today',
                    isActive: widget.activeSection == 'today',
                    onTap: widget.onSelectToday,
                  ),
                  _MenuRow(
                    label: 'tags',
                    isActive: widget.activeSection == 'tags',
                    onTap: widget.onSelectTags,
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
                    label: 'event',
                    isActive: widget.activeSection == 'event',
                    onTap: widget.onSelectSchedule,
                  ),
                  _MenuRow(
                    label: 'stats',
                    isActive: widget.activeSection == 'stats',
                    onTap: widget.onSelectStats,
                  ),
                  _MenuRow(
                    label: 'graph',
                    isActive: widget.activeSection == 'graph',
                    onTap: widget.onSelectGraph ?? () {},
                  ),
                  _MenuRow(
                    label: 'brain',
                    isActive: widget.activeSection == 'brain',
                    onTap: widget.onSelectBrain ?? () {},
                  ),
                  _DivRow(),
                  _MenuRow(
                    label: 'settings',
                    isActive: false,
                    onTap: widget.onSettingsTap,
                  ),
                ] else ...[
                  // nemo: tag navigation
                  if (widget.allTags.isNotEmpty) ...[
                    _DivRow(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
                      child: Text(
                        '/TAGS',
                        style: mono(
                          color: kMint.withValues(alpha: 0.65),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ...widget.allTags.map((tag) {
                      final count = widget.tagCounts[tag] ?? 0;
                      final isActive = widget.selectedTag == tag;
                      return _TagRow(
                        tag: tag,
                        count: count,
                        isActive: isActive,
                        onTap: () => widget.onSelectTag?.call(tag),
                      );
                    }),
                  ],
                  _DivRow(),
                  _MenuRow(
                    label: 'stats',
                    isActive: widget.activeSection == 'stats',
                    onTap: widget.onSelectStats,
                  ),
                  _MenuRow(
                    label: 'graph',
                    isActive: widget.activeSection == 'graph',
                    onTap: widget.onSelectGraph ?? () {},
                  ),
                  _MenuRow(
                    label: 'brain',
                    isActive: widget.activeSection == 'brain',
                    onTap: widget.onSelectBrain ?? () {},
                  ),
                  _MenuRow(
                    label: 'settings',
                    isActive: false,
                    onTap: widget.onSettingsTap,
                  ),
                ],
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
                      letterSpacing: 1.2,
                    ),
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
            label: '+ new folder',
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

  Widget _buildLogroomSidebar(String dateStr) {
    if (isDosTheme) return _buildDosSidebar(dateStr);
    return Container(
      color: kSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand header
          Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            padding: const EdgeInsets.fromLTRB(15, 0, 12, 0),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: kAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'logroom',
                    style: display(color: kText, fontSize: 18),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      dateStr,
                      style: mono(color: kText3, fontSize: 8, height: 1.3),
                    ),
                    if (widget.streak > 0)
                      Text(
                        '${widget.streak}d',
                        style: mono(
                          color: kText3.withValues(alpha: 0.65),
                          fontSize: 8,
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                // ── FAVORITES ──────────────────────────────
                if (widget.favorites.isNotEmpty) ...[
                  _SdSecHeader('즐겨찾기'),
                  ...widget.favorites.map((fav) {
                    final label = fav.isTag ? '#${fav.label}' : fav.label;
                    final sym = fav.isTag ? '#' : '★';
                    return _SdRow(
                      sym: sym,
                      label: label,
                      isActive: false,
                      onTap: () => widget.onSelectFavorite?.call(fav),
                    );
                  }),
                  _SdSep(),
                ],

                // ── MAIN NAV ────────────────────────────────
                _SdRow(
                  sym: '●',
                  label: 'TODAY',
                  isActive: widget.activeSection == 'today',
                  onTap: widget.onSelectToday,
                ),
                _SdRow(
                  sym: '≡',
                  label: 'ENTRIES',
                  isActive: widget.activeSection == 'memo',
                  count: widget.noteCount,
                  onTap: widget.onSelectMemo,
                  trailing: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _memoExpanded = !_memoExpanded),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                      child: Text(
                        _memoExpanded ? 'OPEN' : 'CLOSED',
                        style: mono(color: kDim, fontSize: 8),
                      ),
                    ),
                  ),
                ),
                if (_memoExpanded) ...[
                  _SdSubRow(
                    label: 'inbox',
                    isActive:
                        widget.activeSection == 'memo' &&
                        widget.selectedFolderId == null,
                    onTap: () => widget.onSelectFolder(null),
                  ),
                  ..._buildFolderRowsLr(null, 0),
                ],
                _SdSep(),

                _SdRow(
                  sym: '△',
                  label: 'CALENDAR',
                  isActive: widget.activeSection == 'calendar',
                  onTap: widget.onSelectCalendar,
                ),
                _SdRow(
                  sym: '△',
                  label: 'EVENTS',
                  isActive: widget.activeSection == 'event',
                  onTap: widget.onSelectSchedule,
                ),
                _SdRow(
                  sym: '□',
                  label: 'TASKS',
                  isActive: widget.activeSection == 'tasks',
                  count: widget.taskCount,
                  onTap: widget.onSelectTasks,
                ),
                _SdSep(),

                _SdRow(
                  sym: '#',
                  label: 'TAGS',
                  isActive: widget.activeSection == 'tags',
                  onTap: widget.onSelectTags,
                ),
                _SdRow(
                  sym: '?',
                  label: 'SEARCH',
                  isActive: widget.activeSection == 'search',
                  onTap: widget.onSelectSearch,
                ),
                _SdSep(),

                // HABITS
                _SdHabitRow(
                  dayCount: widget.dayCount,
                  habitActivated: widget.habitActivated,
                  streak: widget.streak,
                  isActive: widget.activeSection == 'habits',
                  count: widget.habitCount,
                  onTap: () {
                    if (widget.habitActivated) {
                      widget.onSelectHabit?.call();
                    } else {
                      _showHabitSheet(context);
                    }
                  },
                ),
                // GOALS
                _SdGoalRow(
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
                _SdSep(),

                _SdRow(
                  sym: '∑',
                  label: 'STATS',
                  isActive: widget.activeSection == 'stats',
                  onTap: widget.onSelectStats,
                ),
                _SdRow(
                  sym: '',
                  label: 'GRAPH',
                  isActive: widget.activeSection == 'graph',
                  onTap: widget.onSelectGraph ?? () {},
                ),
                _SdRow(
                  sym: '',
                  label: 'BRAIN',
                  isActive: widget.activeSection == 'brain',
                  onTap: widget.onSelectBrain ?? () {},
                ),
                _SdRow(
                  sym: '⚙',
                  label: 'SETTINGS',
                  isActive: false,
                  onTap: widget.onSettingsTap,
                ),
                _SdSep(),
              ],
            ),
          ),

          Container(height: 1, color: kBorder),
          _TextBtn(
            label: '+ new room',
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

  Widget _buildDosSidebar(String dateStr) {
    Widget row(String id, String label, VoidCallback? onTap, {int? count}) {
      final active = widget.activeSection == id;
      final prefix = active ? '> ' : '  ';
      final suffix = count == null ? '' : '  $count';
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            '$prefix$label$suffix',
            style: mono(
              color: active ? kBg : kText,
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ).copyWith(backgroundColor: active ? kText : Colors.transparent),
          ),
        ),
      );
    }

    return Container(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              'C:\\LOGROOM',
              style: mono(color: kMint, fontSize: 13, letterSpacing: 0),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                row('today', 'TODAY', widget.onSelectToday),
                row(
                  'memo',
                  'ENTRIES',
                  widget.onSelectMemo,
                  count: widget.noteCount,
                ),
                if (widget.activeSection == 'memo') ...[
                  row('memo', '  INBOX', () => widget.onSelectFolder(null)),
                  ...widget.folders.map(
                    (f) => row(
                      'memo',
                      '  ${f.name}',
                      () => widget.onSelectFolder(f.id),
                    ),
                  ),
                ],
                row('calendar', 'CALENDAR', widget.onSelectCalendar),
                row('event', 'EVENTS', widget.onSelectSchedule),
                row(
                  'tasks',
                  'TASKS',
                  widget.onSelectTasks,
                  count: widget.taskCount,
                ),
                row('tags', 'TAGS', widget.onSelectTags),
                row('habits', 'HABITS', widget.onSelectHabit),
                row('goals', 'GOALS', widget.onSelectGoal),
                row('stats', 'STATS', widget.onSelectStats),
                row('graph', 'GRAPH', widget.onSelectGraph),
                row('brain', 'BRAIN', widget.onSelectBrain),
                row('settings', 'SETTINGS', widget.onSettingsTap),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Text(
              'DATE $dateStr',
              style: mono(color: kDim, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  // Logroom folder sub-rows (without tree chars ├─ └─, use indent + vline)
  List<Widget> _buildFolderRowsLr(String? parentId, int depth) {
    if (depth >= 5) return const [];
    final folders = _sortedChildFolders(widget.folders, parentId);
    final rows = <Widget>[];
    for (final entry in folders.asMap().entries) {
      final index = entry.key;
      final folder = entry.value;
      final childCount = _sortedChildFolders(widget.folders, folder.id).length;
      rows.add(
        _SubFolderRow(
          id: folder.id,
          parentId: parentId,
          depth: depth,
          orderIndex: index,
          label: folder.name,
          isActive:
              widget.activeSection == 'memo' &&
              widget.selectedFolderId == folder.id,
          canMoveInto: depth < 4,
          childCount: childCount,
          onTap: () => widget.onSelectFolder(folder.id),
          onRename: (name) => widget.onRenameFolder(folder.id, name),
          onDelete: () => widget.onDeleteFolder(folder.id),
          onMove: (id, targetParentId, insertIndex) =>
              widget.onMoveFolder(id, targetParentId, insertIndex),
        ),
      );
      rows.addAll(_buildFolderRowsLr(folder.id, depth + 1));
    }
    return rows;
  }
}

// ──────────────────────────────────────────────────────────────
// Divider row
// ──────────────────────────────────────────────────────────────

const _kDiv = '──────────────';

class _DivRow extends StatelessWidget {
  const _DivRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 3, 14, 3),
      child: Text(_kDiv, style: mono(color: kBorder, fontSize: 11)),
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
    final Color fg = widget.isActive ? kMint : (_hovered ? kText : kDim);
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
                Text('  └ ', style: mono(color: fg, fontSize: 12)),
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
  final VoidCallback onTap; // navigates to inbox
  final VoidCallback onToggle; // toggles expand/collapse
  final String label;

  const _MemoExpandRow({
    required this.isActive,
    required this.isExpanded,
    required this.onTap,
    required this.onToggle,
    this.label = 'memo',
  });

  @override
  State<_MemoExpandRow> createState() => _MemoExpandRowState();
}

class _MemoExpandRowState extends State<_MemoExpandRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fg = widget.isActive ? kMint : (_hovered ? kText : kDim);
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
                  Text(widget.label, style: mono(color: fg, fontSize: 12)),
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
// Tag row (nemo only)
// ──────────────────────────────────────────────────────────────

class _TagRow extends StatefulWidget {
  final String tag;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  const _TagRow({
    required this.tag,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_TagRow> createState() => _TagRowState();
}

class _TagRowState extends State<_TagRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fg = widget.isActive ? kMint : (_hovered ? kText : kDim);
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
          padding: const EdgeInsets.fromLTRB(26, 4, 10, 4),
          child: Row(
            children: [
              Text(
                '#',
                style: mono(color: fg.withValues(alpha: 0.6), fontSize: 11),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  widget.tag,
                  style: mono(color: fg, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${widget.count}',
                style: mono(color: fg.withValues(alpha: 0.45), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Sub-folder row (└ folderName)
// ──────────────────────────────────────────────────────────────

List<Folder> _sortedChildFolders(List<Folder> folders, String? parentId) {
  return folders.where((f) => f.parentId == parentId).toList()..sort(
    (a, b) => a.order != b.order
        ? a.order.compareTo(b.order)
        : a.name.compareTo(b.name),
  );
}

class _SubFolderRow extends StatefulWidget {
  final String? id;
  final String? parentId;
  final int depth;
  final int orderIndex;
  final String label;
  final bool isActive;
  final bool canMoveInto;
  final int childCount;
  final VoidCallback onTap;
  final ValueChanged<String>? onRename;
  final VoidCallback? onDelete;
  final void Function(String id, String? parentId, int insertIndex)? onMove;

  const _SubFolderRow({
    this.id,
    this.parentId,
    this.depth = 0,
    this.orderIndex = 0,
    required this.label,
    required this.isActive,
    this.canMoveInto = false,
    this.childCount = 0,
    required this.onTap,
    this.onRename,
    this.onDelete,
    this.onMove,
  });

  @override
  State<_SubFolderRow> createState() => _SubFolderRowState();
}

class _SubFolderRowState extends State<_SubFolderRow> {
  bool _hovered = false;
  bool _dragHover = false;
  bool _editing = false;
  TextEditingController? _ctrl;
  FocusNode? _focusNode;

  TextEditingController get _controller =>
      _ctrl ??= TextEditingController(text: widget.label);

  FocusNode get _editFocusNode => _focusNode ??= FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.label);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _SubFolderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.label != widget.label) {
      _controller.text = widget.label;
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _focusNode?.dispose();
    super.dispose();
  }

  void _startEdit() {
    if (widget.onRename == null) return;
    setState(() {
      _editing = true;
      _controller.text = widget.label;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _editFocusNode.requestFocus();
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _controller.text = widget.label;
    });
  }

  void _confirmEdit() {
    final next = _controller.text.trim();
    if (next.isNotEmpty && next != widget.label) {
      widget.onRename?.call(next);
    }
    if (mounted) setState(() => _editing = false);
  }

  Future<bool> _confirmDelete() async {
    if (widget.onDelete == null) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text('폴더 삭제', style: mono(color: kMint, fontSize: 13)),
        content: Text(
          '/${widget.label} 폴더를 삭제하시겠습니까?\n폴더 안의 메모는 inbox로 이동합니다.',
          style: mono(color: kDim, fontSize: 12, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소', style: mono(color: kDim, fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('삭제', style: mono(color: kTeal, fontSize: 12)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  void _handleDrop(DragTargetDetails<String> details) {
    if (widget.id == null || widget.onMove == null) return;
    final box = context.findRenderObject() as RenderBox?;
    final localY = box?.globalToLocal(details.offset).dy ?? 0;
    final height = box?.size.height ?? 1;
    setState(() => _dragHover = false);

    if (widget.canMoveInto &&
        localY >= height * 0.35 &&
        localY <= height * 0.65) {
      widget.onMove?.call(details.data, widget.id, widget.childCount);
      return;
    }

    final insertIndex = localY < height * 0.5
        ? widget.orderIndex
        : widget.orderIndex + 1;
    widget.onMove?.call(details.data, widget.parentId, insertIndex);
  }

  @override
  Widget build(BuildContext context) {
    final Color fg = widget.isActive ? kMint : (_hovered ? kText : kDim);
    final Color bg = widget.isActive
        ? kMint.withValues(alpha: 0.08)
        : (_dragHover
              ? kTeal.withValues(alpha: 0.12)
              : (_hovered
                    ? kBorder.withValues(alpha: 0.22)
                    : Colors.transparent));

    final leftPad = 14.0 + widget.depth * 14.0;
    final branch = widget.depth == 0 ? '  └ ' : '  ${'  ' * widget.depth}└ ';

    final content = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: _startEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: bg,
          padding: EdgeInsets.fromLTRB(leftPad, 5, 10, 5),
          child: Row(
            children: [
              Text(branch, style: mono(color: fg, fontSize: 12)),
              Expanded(
                child: _editing
                    ? TextField(
                        controller: _controller,
                        focusNode: _editFocusNode,
                        style: mono(color: kText, fontSize: 12),
                        cursorColor: kTeal,
                        cursorWidth: 2,
                        textInputAction: TextInputAction.done,
                        maxLength: 10,
                        inputFormatters: [LengthLimitingTextInputFormatter(10)],
                        onSubmitted: (_) => _confirmEdit(),
                        onEditingComplete: _confirmEdit,
                        decoration: InputDecoration(
                          counterText: '',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          filled: true,
                          fillColor: kBg,
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
                      )
                    : Text(
                        widget.label,
                        style: mono(color: fg, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              if (_editing) ...[
                const SizedBox(width: 5),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _cancelEdit,
                  child: Text('x', style: mono(color: kDim, fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final row = widget.id == null || widget.onMove == null || _editing
        ? content
        : DragTarget<String>(
            onWillAcceptWithDetails: (details) {
              final accept = details.data != widget.id;
              if (accept) setState(() => _dragHover = true);
              return accept;
            },
            onLeave: (_) => setState(() => _dragHover = false),
            onAcceptWithDetails: _handleDrop,
            builder: (context, candidateData, rejectedData) {
              return LongPressDraggable<String>(
                data: widget.id!,
                feedback: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: kSurface,
                        border: Border.all(color: kTeal),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 5, 10, 5),
                        child: Text(
                          '/${widget.label}',
                          style: mono(color: kText, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: content),
                child: content,
              );
            },
          );

    if (widget.onDelete == null || widget.id == null) return row;

    return Dismissible(
      key: ValueKey('folder-${widget.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(),
      onDismissed: (_) => widget.onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 14),
        color: Colors.redAccent.withValues(alpha: 0.16),
        child: Text('삭제', style: mono(color: Colors.redAccent, fontSize: 11)),
      ),
      child: row,
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
    final Color fg = widget.isActive ? kMint : (_hovered ? kText : kDim);
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
          Text('${widget.streak}d', style: mono(color: kTeal, fontSize: 9)),
        ],
      );
    } else if (widget.habitActivated) {
      badge = Padding(
        padding: const EdgeInsets.only(left: 5),
        child: Text(
          '${widget.dayCount}일',
          style: mono(color: kTeal, fontSize: 9),
        ),
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

    final Color fg = widget.isActive ? kMint : (_hovered ? kText : kDim);
    final Color bg = widget.isActive
        ? kMint.withValues(alpha: 0.08)
        : (_hovered ? kBorder.withValues(alpha: 0.22) : Colors.transparent);

    Widget? badge;
    if (!widget.goalActivated && widget.dayCount >= 14) {
      badge = Padding(
        padding: const EdgeInsets.only(left: 5),
        child: Text('NEW', style: mono(color: kTeal, fontSize: 9)),
      );
    } else if (locked) {
      badge = Padding(
        padding: const EdgeInsets.only(left: 5),
        child: Text(
          '${14 - widget.dayCount}d',
          style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 9),
        ),
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
                      color: kDim.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ),
                Text(
                  ': ',
                  style: mono(color: kDim.withValues(alpha: 0.4), fontSize: 10),
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
                  maxLength: 10,
                  inputFormatters: [LengthLimitingTextInputFormatter(10)],
                  onSubmitted: (_) => onConfirm(),
                  decoration: InputDecoration(
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
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
            child: Text(
              '↵ create  Esc cancel',
              style: mono(color: kDim.withValues(alpha: 0.4), fontSize: 9),
            ),
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
            color: _hovered
                ? kTeal.withValues(alpha: 0.15)
                : Colors.transparent,
          ),
          child: Text('↵', style: mono(color: kTeal, fontSize: 11)),
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
                  ? (_hovered
                        ? widget.color
                        : widget.color.withValues(alpha: 0.55))
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
// Logroom sidebar helper widgets
// ──────────────────────────────────────────────────────────────

class _SdSecHeader extends StatelessWidget {
  final String label;
  const _SdSecHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 3),
      child: Text(
        label.toUpperCase(),
        style: monoLabel(color: kText3, fontSize: 9, letterSpacing: 1.8),
      ),
    );
  }
}

class _SdSep extends StatelessWidget {
  const _SdSep();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: kBorder,
    );
  }
}

class _SdRow extends StatefulWidget {
  final String sym;
  final String label;
  final bool isActive;
  final int? count;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SdRow({
    required this.sym,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.count,
    this.trailing,
  });

  @override
  State<_SdRow> createState() => _SdRowState();
}

class _SdRowState extends State<_SdRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.isActive ? kMint : (_hovered ? kText2 : kText3);
    final bg = widget.isActive
        ? kMint.withValues(alpha: 0.07)
        : (_hovered ? kBorder.withValues(alpha: 0.12) : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: bg,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // timeline lane
                SizedBox(
                  width: 26,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        left: 12, top: 0, bottom: 0, width: 1,
                        child: Container(color: kTlLine),
                      ),
                      Positioned(
                        left: 8, top: 0, bottom: 0, width: 8,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: 7, height: 7,
                            decoration: BoxDecoration(
                              color: widget.isActive
                                  ? kMint.withValues(alpha: 0.65)
                                  : kBg4,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.isActive ? kMint : kTlDot,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.label,
                            style: mono(color: fg, fontSize: 11),
                          ),
                        ),
                        if (widget.count != null)
                          Text(
                            '${widget.count}',
                            style: mono(color: kText4, fontSize: 9),
                          ),
                        if (widget.trailing != null) widget.trailing!,
                      ],
                    ),
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

class _SdSubRow extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SdSubRow({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SdSubRow> createState() => _SdSubRowState();
}

class _SdSubRowState extends State<_SdSubRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.isActive ? kMint : (_hovered ? kText2 : kText3);
    final bg = widget.isActive
        ? kMint.withValues(alpha: 0.07)
        : (_hovered ? kBorder.withValues(alpha: 0.12) : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: bg,
          padding: const EdgeInsets.fromLTRB(42, 5, 10, 5),
          child: Text(
            widget.label,
            style: mono(color: fg, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}


// Habits row for logroom sidebar (shows streak info)
class _SdHabitRow extends StatefulWidget {
  final int dayCount;
  final bool habitActivated;
  final int streak;
  final bool isActive;
  final int count;
  final VoidCallback onTap;

  const _SdHabitRow({
    required this.dayCount,
    required this.habitActivated,
    required this.streak,
    required this.isActive,
    required this.count,
    required this.onTap,
  });

  @override
  State<_SdHabitRow> createState() => _SdHabitRowState();
}

class _SdHabitRowState extends State<_SdHabitRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.isActive ? kMint : (_hovered ? kText2 : kText3);
    final bg = widget.isActive
        ? kMint.withValues(alpha: 0.07)
        : (_hovered ? kBorder.withValues(alpha: 0.12) : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: bg,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 26,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        left: 12, top: 0, bottom: 0, width: 1,
                        child: Container(color: kTlLine),
                      ),
                      Positioned(
                        left: 8, top: 0, bottom: 0, width: 8,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: 7, height: 7,
                            decoration: BoxDecoration(
                              color: widget.isActive
                                  ? kMint.withValues(alpha: 0.65)
                                  : kBg4,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.isActive ? kMint : kTlDot,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('HABITS', style: mono(color: fg, fontSize: 11)),
                        ),
                        if (widget.habitActivated && widget.streak > 0)
                          Text(
                            '${widget.streak}d',
                            style: mono(color: kText3, fontSize: 9),
                          )
                        else if (widget.count > 0)
                          Text(
                            '${widget.count}',
                            style: mono(color: kText4, fontSize: 9),
                          ),
                      ],
                    ),
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

// Goals row for logroom sidebar
class _SdGoalRow extends StatefulWidget {
  final int dayCount;
  final bool goalActivated;
  final bool isActive;
  final VoidCallback onTap;

  const _SdGoalRow({
    required this.dayCount,
    required this.goalActivated,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SdGoalRow> createState() => _SdGoalRowState();
}

class _SdGoalRowState extends State<_SdGoalRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final locked = !widget.goalActivated && widget.dayCount < 14;
    final fg = widget.isActive ? kMint : (_hovered ? kText2 : kText3);
    final bg = widget.isActive
        ? kMint.withValues(alpha: 0.07)
        : (_hovered ? kBorder.withValues(alpha: 0.12) : Colors.transparent);

    return Opacity(
      opacity: locked ? 0.5 : 1.0,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            color: bg,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 26,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          left: 12, top: 0, bottom: 0, width: 1,
                          child: Container(color: kTlLine),
                        ),
                        Positioned(
                          left: 8, top: 0, bottom: 0, width: 8,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              width: 7, height: 7,
                              decoration: BoxDecoration(
                                color: widget.isActive
                                    ? kMint.withValues(alpha: 0.65)
                                    : kBg4,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: widget.isActive ? kMint : kTlDot,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('GOALS', style: mono(color: fg, fontSize: 11)),
                          ),
                          if (!widget.goalActivated && !locked)
                            Text('NEW', style: mono(color: kText3, fontSize: 9))
                          else if (locked)
                            Text(
                              '${14 - widget.dayCount}d',
                              style: mono(color: kText4, fontSize: 9),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
      actionLabel = '습관 관리';
      laterLabel = '나중에';
    } else if (dayCount >= 7) {
      body = '"일주일째네요."\n"습관을 좀 더 단단히 들여볼 때예요."';
      actionLabel = '단단히 하기';
      laterLabel = '나중에';
    } else if (dayCount >= 5) {
      body = '"벌써 $dayCount일째예요!"\n"슬슬 습관 하나 잡아볼까요? 작은 것도 괜찮아요."';
      actionLabel = '만들기';
      laterLabel = '아직은요';
    } else {
      body = '"습관 하나 만들어볼까요?"\n"탭 한 번이면 기록돼요.\n 그 이상은… 하다 보면 알게 돼요."';
      actionLabel = '해보기';
      laterLabel = '나중에';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dayCount >= 5)
          Row(
            children: [
              Text(
                'habits  ',
                style: mono(color: kMint, fontSize: 13, letterSpacing: 0.5),
              ),
              _buildStreakDots(dayCount),
              Text('  $dayCount일', style: mono(color: kDim, fontSize: 11)),
            ],
          )
        else
          Text(
            'habits',
            style: mono(color: kMint, fontSize: 13, letterSpacing: 0.5),
          ),
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
          Text(
            'goals',
            style: mono(color: kMint, fontSize: 13, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: kBorder.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('아직 열리지 않았어요.', style: mono(color: kDim, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            '  Day $dayCount  —  ${14 - dayCount}일 후에 만나요.',
            style: mono(color: kDim.withValues(alpha: 0.7), fontSize: 11),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: _buildGoalProgressDots(dayCount),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_SheetBtn(label: '알겠어요', filled: true, onTap: onLater)],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'goals',
          style: mono(color: kMint, fontSize: 13, letterSpacing: 0.5),
        ),
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
            _SheetBtn(label: '나중에', filled: false, onTap: onLater),
            const SizedBox(width: 10),
            _SheetBtn(label: '목표 만들기', filled: true, onTap: onActivate),
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
                : (_hovered
                      ? kBorder.withValues(alpha: 0.3)
                      : Colors.transparent),
            border: widget.filled
                ? null
                : Border.all(color: kTeal.withValues(alpha: 0.4)),
          ),
          child: Text(
            widget.label,
            style: mono(
              color: widget.filled ? kBg : kDim.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
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
    final title = widget.isHabit ? '습관 이름' : '목표 이름';
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
            Text(
              title,
              style: mono(color: kMint, fontSize: 13, letterSpacing: 1),
            ),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
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
                _SheetBtn(label: '취소', filled: false, onTap: widget.onCancel),
                const SizedBox(width: 10),
                _SheetBtn(label: '확인', filled: true, onTap: _submit),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
