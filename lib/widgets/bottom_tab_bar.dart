import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/folder.dart';
import '../models/quick_tab.dart';
import '../app_theme.dart';

const nemo2TestMenuOptions = <String>[
  'TODAY',
  'LIST',
  'CAL',
  'EVENTS',
  'TASKS',
  'HABITS',
  'GOALS',
  'STATS',
  'SETTINGS',
  'TAGS',
];

// ──────────────────────────────────────────────────────────────
// Logroom bottom nav  (TODAY | ENTRIES | CAL | MORE)
// ──────────────────────────────────────────────────────────────

class LogroomBottomNav extends StatelessWidget {
  final bool todaySelected;
  final bool entriesSelected;
  final bool calendarSelected;
  final VoidCallback onTodayTap;
  final VoidCallback onEntriesTap;
  final VoidCallback onCalendarTap;
  final VoidCallback onMoreTap;

  const LogroomBottomNav({
    super.key,
    required this.todaySelected,
    required this.entriesSelected,
    required this.calendarSelected,
    required this.onTodayTap,
    required this.onEntriesTap,
    required this.onCalendarTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: kSurface,
          border: Border(top: BorderSide(color: kBorder, width: 1)),
        ),
        child: Row(
          children: [
            _LrNavItem(
              label: 'TODAY',
              symbol: '●',
              selected: todaySelected,
              onTap: onTodayTap,
            ),
            Container(width: 1, color: kBorder),
            _LrNavItem(
              label: 'ENTRIES',
              symbol: '≡',
              selected: entriesSelected,
              onTap: onEntriesTap,
            ),
            Container(width: 1, color: kBorder),
            _LrNavItem(
              label: 'CAL',
              symbol: '△',
              selected: calendarSelected,
              onTap: onCalendarTap,
            ),
            Container(width: 1, color: kBorder),
            _LrNavItem(
              label: 'MORE',
              symbol: '≡',
              selected: false,
              onTap: onMoreTap,
            ),
          ],
        ),
      ),
    );
  }
}

class Nemo2TestBottomNav extends StatelessWidget {
  final List<String> menus;
  final String activeMenu;
  final void Function(String menu) onTap;
  final void Function(int index) onReplace;

  const Nemo2TestBottomNav({
    super.key,
    required this.menus,
    required this.activeMenu,
    required this.onTap,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    final safeMenus = [
      ...menus.take(4),
      ...const ['TODAY', 'LIST', 'CAL', 'MORE'],
    ].take(4).toList();
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: kSurface,
          border: Border(top: BorderSide(color: kBorder, width: 1)),
        ),
        child: Row(
          children: List.generate(safeMenus.length, (i) {
            final menu = safeMenus[i];
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _N2TestNavItem(
                      label: menu,
                      selected: activeMenu == menu,
                      onTap: () => onTap(menu),
                      onLongPress: () => onReplace(i),
                    ),
                  ),
                  if (i != safeMenus.length - 1)
                    Container(width: 1, color: kBorder),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _N2TestNavItem extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _N2TestNavItem({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_N2TestNavItem> createState() => _N2TestNavItemState();
}

class _N2TestNavItemState extends State<_N2TestNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.selected ? kMint : (_hovered ? kText : kDim);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Container(
          color: widget.selected
              ? kMint.withValues(alpha: 0.06)
              : Colors.transparent,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            widget.label,
            style: mono(
              color: fg,
              fontSize: 10,
              fontWeight: widget.selected ? FontWeight.bold : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _LrNavItem extends StatefulWidget {
  final String label;
  final String symbol;
  final bool selected;
  final VoidCallback onTap;

  const _LrNavItem({
    required this.label,
    required this.symbol,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_LrNavItem> createState() => _LrNavItemState();
}

class _LrNavItemState extends State<_LrNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.selected ? kMint : (_hovered ? kText : kDim);
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            color: widget.selected
                ? kMint.withValues(alpha: 0.06)
                : Colors.transparent,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.symbol, style: mono(color: fg, fontSize: 10)),
                const SizedBox(height: 1),
                Text(
                  widget.label,
                  style: mono(color: fg, fontSize: 7, letterSpacing: 0.6),
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
// Bottom tab bar
// ──────────────────────────────────────────────────────────────

class BottomTabBar extends StatelessWidget {
  final List<QuickTab> tabs;
  final String? selectedTabId;
  final void Function(QuickTab) onSelect;
  final bool canAdd;
  final VoidCallback onAddTap;
  final void Function(QuickTab) onLongPress;
  final bool locked;
  final bool calendarSelected;
  final VoidCallback onCalendarTap;
  final bool statsSelected;
  final VoidCallback onStatsTap;
  final bool todaySelected;
  final VoidCallback onTodayTap;

  const BottomTabBar({
    super.key,
    required this.tabs,
    required this.selectedTabId,
    required this.onSelect,
    required this.canAdd,
    required this.onAddTap,
    required this.onLongPress,
    required this.onCalendarTap,
    required this.onStatsTap,
    required this.onTodayTap,
    this.locked = false,
    this.calendarSelected = false,
    this.statsSelected = false,
    this.todaySelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final slotCount = tabs.length < 3 ? 3 : tabs.length + (canAdd ? 1 : 0);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            // Left fluid area: tabs flex-fill equally
            Expanded(
              child: Row(
                children: List.generate(slotCount, (i) {
                  if (i < tabs.length) {
                    final tab = tabs[i];
                    return Expanded(
                      child: _TabChip(
                        tab: tab,
                        isSelected: tab.id == selectedTabId,
                        onTap: () => onSelect(tab),
                        onLongPress: locked ? null : () => onLongPress(tab),
                        onDelete: locked ? null : () => onLongPress(tab),
                      ),
                    );
                  }
                  return Expanded(
                    child: locked || !canAdd
                        ? Center(
                            child: Text(
                              '탭추가',
                              style: mono(
                                color: kDim.withValues(alpha: 0.25),
                                fontSize: 10,
                              ),
                            ),
                          )
                        : _AddPlaceholder(onTap: onAddTap),
                  );
                }),
              ),
            ),
            // Right fixed area: TODAY, CAL, STATS
            Container(width: 0.5, color: kBorder),
            _TodayBtn(isSelected: todaySelected, onTap: onTodayTap),
            Container(width: 0.5, color: kBorder),
            _CalBtn(isSelected: calendarSelected, onTap: onCalendarTap),
            Container(width: 0.5, color: kBorder),
            _StatsBtn(isSelected: statsSelected, onTap: onStatsTap),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Individual tab chip
// ──────────────────────────────────────────────────────────────

class _TabChip extends StatefulWidget {
  final QuickTab tab;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;

  const _TabChip({
    required this.tab,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.onDelete,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.tab.isTag ? '#${widget.tab.label}' : widget.tab.label;
    final fg = widget.isSelected ? kMint : (_hovered ? kText : kDim);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onDelete != null) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onDelete,
                  child: Text(
                    '삭제',
                    style: mono(color: Colors.red.shade300, fontSize: 9),
                  ),
                ),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Text(
                  label,
                  style: mono(color: fg, fontSize: 10),
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
// Empty tab placeholder (shows "탭추가")
// ──────────────────────────────────────────────────────────────

class _AddPlaceholder extends StatefulWidget {
  final VoidCallback onTap;
  const _AddPlaceholder({required this.onTap});

  @override
  State<_AddPlaceholder> createState() => _AddPlaceholderState();
}

class _AddPlaceholderState extends State<_AddPlaceholder> {
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
          alignment: Alignment.center,
          child: Text(
            '탭추가',
            style: mono(
              color: _hovered ? kDim : kDim.withValues(alpha: 0.3),
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// [+] add button
// ──────────────────────────────────────────────────────────────

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
        onTap: widget.onTap,
        child: Container(
          width: 36,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          alignment: Alignment.center,
          child: Text(
            '+',
            style: mono(color: _hovered ? kMint : kDim, fontSize: 10),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// [TODAY] today button
// ──────────────────────────────────────────────────────────────

class _TodayBtn extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _TodayBtn({required this.isSelected, required this.onTap});

  @override
  State<_TodayBtn> createState() => _TodayBtnState();
}

class _TodayBtnState extends State<_TodayBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.isSelected ? kMint : (_hovered ? kText : kDim);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          alignment: Alignment.center,
          child: Text('TODAY', style: mono(color: fg, fontSize: 10)),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// [CAL] calendar button
// ──────────────────────────────────────────────────────────────

class _CalBtn extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _CalBtn({required this.isSelected, required this.onTap});

  @override
  State<_CalBtn> createState() => _CalBtnState();
}

class _CalBtnState extends State<_CalBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.isSelected ? kMint : (_hovered ? kText : kDim);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          alignment: Alignment.center,
          child: Text('CAL', style: mono(color: fg, fontSize: 10)),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// [STATS] stats button
// ──────────────────────────────────────────────────────────────

class _StatsBtn extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _StatsBtn({required this.isSelected, required this.onTap});

  @override
  State<_StatsBtn> createState() => _StatsBtnState();
}

class _StatsBtnState extends State<_StatsBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.isSelected ? kMint : (_hovered ? kText : kDim);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          alignment: Alignment.center,
          child: Text('STATS', style: mono(color: fg, fontSize: 10)),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Tab add / edit dialog
// ──────────────────────────────────────────────────────────────

class TabEditDialog extends StatefulWidget {
  final QuickTab? tab; // null = add mode
  final List<Folder> folders;
  final List<String> allTags;
  final void Function(QuickTab) onSave;
  final VoidCallback? onDelete;

  const TabEditDialog({
    super.key,
    this.tab,
    required this.folders,
    required this.allTags,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<TabEditDialog> createState() => _TabEditDialogState();
}

class _TabEditDialogState extends State<TabEditDialog> {
  late final TextEditingController _labelCtrl;
  bool _isTag = false;
  bool _inboxSelected = false;
  String? _folderId;
  String? _tag;

  @override
  void initState() {
    super.initState();
    final t = widget.tab;
    _labelCtrl = TextEditingController(text: t?.label ?? '');
    if (t != null) {
      _isTag = t.isTag;
      if (t.isTag) {
        _tag = t.tag;
      } else {
        _inboxSelected = t.folderId == null;
        _folderId = t.folderId;
      }
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_labelCtrl.text.trim().isEmpty) return false;
    return _inboxSelected || _folderId != null;
  }

  QuickTab _buildTab() => QuickTab(
    id: widget.tab?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    label: _labelCtrl.text.trim(),
    isTag: false,
    folderId: _inboxSelected ? null : _folderId,
    tag: null,
  );

  @override
  Widget build(BuildContext context) {
    final isAdd = widget.tab == null;

    return Dialog(
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 300,
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────
            Text(
              isAdd ? 'ADD TAB' : 'EDIT TAB',
              style: mono(color: kMint, fontSize: 13, letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: kBorder),
            const SizedBox(height: 14),

            // ── Label ────────────────────────────────
            Text(
              'label',
              style: mono(color: kDim, fontSize: 10, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _labelCtrl,
              style: mono(color: kText, fontSize: 12),
              cursorColor: kMint,
              maxLength: 10,
              inputFormatters: [LengthLimitingTextInputFormatter(10)],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                filled: true,
                fillColor: kBg,
                hintText: 'tab name...',
                hintStyle: mono(color: kDim, fontSize: 11),
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
            const SizedBox(height: 16),

            // ── Folder target ─────────────────────────
            Text(
              'folder',
              style: mono(color: kDim, fontSize: 10, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: kBorder.withValues(alpha: 0.7)),
                  ),
                  child: _buildFolderList(),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Container(height: 1, color: kBorder),
            const SizedBox(height: 12),

            // ── Actions ──────────────────────────────
            Row(
              children: [
                if (widget.onDelete != null)
                  _ActionBtn(
                    label: '삭제',
                    color: Colors.red.shade400,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onDelete!();
                    },
                  ),
                const Spacer(),
                _ActionBtn(
                  label: '취소',
                  color: kDim,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  label: '저장',
                  color: _canSave ? kMint : kDim.withValues(alpha: 0.35),
                  onTap: _canSave
                      ? () {
                          widget.onSave(_buildTab());
                          Navigator.pop(context);
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderList() {
    final items = <Widget>[
      _TargetItem(
        label: 'inbox',
        isSelected: _inboxSelected,
        onTap: () => setState(() {
          _inboxSelected = true;
          _folderId = null;
        }),
      ),
      ...widget.folders.map(
        (f) => _TargetItem(
          label: f.name,
          isSelected: !_inboxSelected && _folderId == f.id,
          onTap: () => setState(() {
            _inboxSelected = false;
            _folderId = f.id;
          }),
        ),
      ),
    ];
    return ListView(shrinkWrap: true, children: items);
  }

  Widget _buildTagList() {
    if (widget.allTags.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'no tags yet',
            style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 11),
          ),
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: widget.allTags
          .map(
            (tag) => _TargetItem(
              label: '#$tag',
              isSelected: _tag == tag,
              onTap: () => setState(() => _tag = tag),
            ),
          )
          .toList(),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Dialog sub-widgets
// ──────────────────────────────────────────────────────────────

class _TypeBtn extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _TypeBtn({required this.label, required this.isSelected, this.onTap});

  @override
  State<_TypeBtn> createState() => _TypeBtnState();
}

class _TypeBtnState extends State<_TypeBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null;
    final fg = widget.isSelected
        ? kMint
        : (active ? (_hovered ? kText : kDim) : kDim.withValues(alpha: 0.35));

    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? kMint.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Text(widget.label, style: mono(color: fg, fontSize: 11)),
        ),
      ),
    );
  }
}

class _TargetItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TargetItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TargetItem> createState() => _TargetItemState();
}

class _TargetItemState extends State<_TargetItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.isSelected ? kMint : (_hovered ? kText : kDim);
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
                  widget.label,
                  style: mono(color: fg, fontSize: 11),
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

class _ActionBtn extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionBtn({required this.label, required this.color, this.onTap});

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active && _hovered
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
