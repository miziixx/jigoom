import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../flavor.dart';
import '../models/entry_display_mode.dart';
import '../models/memo.dart';
import '../models/memo_actions.dart';
import '../models/today_tab.dart';
import '../utils/logroom_entries.dart';
import '../widgets/input_bar.dart';
import '../widgets/logroom_entry_tile.dart';
import '../widgets/today_tab_config_sheet.dart';

const _kTodayTabsKey = 'today_tabs_v1';
const _kTimelogKey = 'today_timelog_entries_v1';

// 날짜 key: yyyy-MM-dd
String _dateKey(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

Color _todayDoneTextColor() => Color.lerp(kText, kDim, 0.55) ?? kDim;

Color _todayDoneAccentColor() => Color.lerp(kMint, kDim, 0.62) ?? kDim;

// SharedPreferences에서 전체 timelog map 읽기: { "yyyy-MM-dd": { "06": "text", ... } }
Future<Map<String, Map<String, String>>> _loadAllTimelogs() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTimelogKey);
    if (raw == null) return {};
    final outer = jsonDecode(raw) as Map<String, dynamic>;
    return outer.map((date, inner) {
      final hours = (inner as Map<String, dynamic>).map(
        (h, v) => MapEntry(h, v as String),
      );
      return MapEntry(date, hours);
    });
  } catch (_) {
    return {};
  }
}

Future<void> _saveTimelog(String dateKey, Map<int, String> entries) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTimelogKey);
    final all = <String, dynamic>{};
    if (raw != null) {
      try {
        all.addAll(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    // 시간 key는 2자리 문자열로 저장 ("06", "14" 등)
    all[dateKey] = entries.map(
      (h, v) => MapEntry(h.toString().padLeft(2, '0'), v),
    );
    await prefs.setString(_kTimelogKey, jsonEncode(all));
  } catch (_) {}
}

class TodayScreen extends StatefulWidget {
  final List<Memo> memos;
  final int streak;
  final void Function(Memo memo, String newContent) onUpdateMemo;
  final void Function(
    Memo memo,
    String content,
    bool isChecklist,
    DateTime? reminderAt,
    String? folderId,
    List<String> imagePaths,
    String reminderRepeat,
    DateTime? scheduledAt,
    DateTime? rangeEndDate,
    String scheduleRepeat,
    String repeatEndType,
    int repeatEndCount,
    DateTime? repeatEndDate,
  )?
  onEditMemo;
  final MemoActions? actions;

  const TodayScreen({
    super.key,
    required this.memos,
    required this.streak,
    required this.onUpdateMemo,
    this.onEditMemo,
    this.actions,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late List<TodayTab> _tabs;
  late String _activeTabId;
  bool _editing = false;
  Memo? _editingMemo;

  @override
  void initState() {
    super.initState();
    _tabs = defaultTodayTabs();
    _activeTabId = _tabs.first.id;
    _loadTabs();
  }

  Future<void> _loadTabs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTodayTabsKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(TodayTab.fromJson)
          .toList();
      if (list.isEmpty) return;
      if (mounted) {
        setState(() {
          _tabs = list;
          _activeTabId = _tabs.first.id;
        });
      }
    } catch (_) {
      // 파싱 실패 시 기본값 유지
    }
  }

  Future<void> _saveTabs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_tabs.map((t) => t.toJson()).toList());
      await prefs.setString(_kTodayTabsKey, json);
    } catch (_) {}
  }

  // ── helpers ──────────────────────────────────────────────

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  DateTime _todayBasis(Memo memo) {
    if (isNemo2Test && memo.scheduledAt != null) return memo.scheduledAt!;
    return memo.createdAt;
  }

  List<Memo> get _todayMemos =>
      widget.memos.where((m) => _isToday(_todayBasis(m))).toList();

  List<Memo> get _todayNonChecklist => _todayMemos
      .where(
        (m) =>
            !m.isChecklist &&
            m.scheduledAt == null &&
            !m.tags.contains('habit') &&
            !m.tags.contains('goal'),
      )
      .toList();

  List<Memo> get _todayChecklists =>
      _todayMemos.where((m) => m.isChecklist).toList();

  List<Memo> get _todayHabits => widget.memos
      .where((m) => m.tags.contains('habit') && _isToday(_todayBasis(m)))
      .toList();

  List<Memo> get _todayGoals => widget.memos
      .where((m) => m.tags.contains('goal') && _isToday(_todayBasis(m)))
      .toList();

  List<Memo> get _upcomingToday =>
      widget.memos
          .where((m) => m.scheduledAt != null && _isToday(m.scheduledAt!))
          .toList()
        ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

  TodayTab get _activeTab => _tabs.firstWhere((t) => t.id == _activeTabId);

  MemoActions? get _localActions => widget.actions?.copyWith(
    onEditRequest: (memo) => setState(() => _editingMemo = memo),
  );

  void _submitEdit(
    String content,
    bool isChecklist,
    DateTime? reminderAt,
    String? folderId,
    List<String> imagePaths,
    String reminderRepeat,
    DateTime? scheduledAt,
    DateTime? rangeEndDate,
    String scheduleRepeat,
    String repeatEndType,
    int repeatEndCount,
    DateTime? repeatEndDate,
  ) {
    final editing = _editingMemo;
    if (editing == null || widget.onEditMemo == null) return;
    widget.onEditMemo!(
      editing,
      content,
      isChecklist,
      reminderAt,
      folderId,
      imagePaths,
      reminderRepeat,
      scheduledAt,
      rangeEndDate,
      scheduleRepeat,
      repeatEndType,
      repeatEndCount,
      repeatEndDate,
    );
    setState(() => _editingMemo = null);
  }

  String _dateStr() {
    final now = DateTime.now();
    final weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final wd = weekdays[now.weekday - 1];
    final y = now.year;
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d  $wd';
  }

  // ── tab actions ───────────────────────────────────────────

  void _onTabTap(String tabId) {
    if (_editing) {
      _showConfigSheet(tabId);
    } else {
      setState(() => _activeTabId = tabId);
    }
  }

  void _showConfigSheet(String tabId) {
    final tab = _tabs.firstWhere((t) => t.id == tabId);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TodayTabConfigSheet(
        tab: tab,
        onConfirm: (updated) {
          setState(() {
            final idx = _tabs.indexWhere((t) => t.id == updated.id);
            if (idx != -1) {
              _tabs[idx] = updated;
              _activeTabId = updated.id;
            }
          });
          _saveTabs();
        },
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDateHero(),
          Container(height: 1, color: kBorder),
          if (_editing && !isLogroomUi)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              color: kSurface,
              child: Text(
                '탭을 눌러 섹션 구성을 바꾸세요',
                style: mono(color: kMint, fontSize: 10, letterSpacing: 0.5),
              ),
            ),
          if (!isLogroomUi) ...[
            _buildInnerTabs(),
            Container(height: 1, color: kBorder),
            Expanded(child: _buildPanel()),
          ] else
            Expanded(child: _buildLogroomPanel()),
          if (_editingMemo != null && widget.onEditMemo != null) ...[
            Container(height: 1, color: kBorder),
            InputBar(
              onSubmit: _submitEdit,
              editingMemo: _editingMemo,
              onCancelEdit: () => setState(() => _editingMemo = null),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      color: kSurface,
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'TODAY',
                    style: mono(
                      color: kMint,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  TextSpan(
                    text: '  ${_dateStr()}',
                    style: mono(color: kDim, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          if (!isLogroomUi)
            GestureDetector(
              onTap: () => setState(() => _editing = !_editing),
              child: Text(
                _editing ? '완료' : '편집',
                style: mono(
                  color: _editing ? kMint : kDim,
                  fontSize: 11,
                  fontWeight: _editing ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInnerTabs() {
    return SizedBox(
      height: 28,
      child: Row(
        children: _tabs.asMap().entries.map((e) {
          final i = e.key;
          final tab = e.value;
          final isActive = tab.id == _activeTabId;
          return Expanded(
            child: _InnerTabBtn(
              label: tab.name,
              isActive: isActive,
              editing: _editing,
              hasDot: _editing,
              onTap: () => _onTabTap(tab.id),
              showDivider: i < _tabs.length - 1,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPanel() {
    final sections = _activeTab.sections;
    if (sections.isEmpty) {
      return Center(
        child: Text(
          '섹션 없음 — 편집에서 추가하세요',
          style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 11),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: sections.asMap().entries.map((e) {
        return _buildSection(e.value, isFirst: e.key == 0);
      }).toList(),
    );
  }

  Widget _buildLogroomPanel() {
    final open = _todayMemos
        .where(
          (m) =>
              !m.isChecklist &&
              m.scheduledAt == null &&
              !m.tags.contains('habit') &&
              !m.tags.contains('goal'),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        _LogroomTodaySection(
          label: 'OPEN',
          memos: open,
          actions: _localActions,
          isFirst: true,
        ),
        _LogroomTodaySection(
          label: 'EVENTS',
          memos: _upcomingToday,
          actions: _localActions,
        ),
        _LogroomTodoSection(
          todos: _todayChecklists,
          actions: _localActions,
          onUpdate: widget.onUpdateMemo,
        ),
        _LogroomTodaySection(
          label: 'HABITS',
          memos: _todayHabits,
          actions: _localActions,
        ),
        _LogroomTodaySection(
          label: 'GOALS',
          memos: _todayGoals,
          actions: _localActions,
        ),
        _LogroomTodaySection(
          label: 'ENTRIES',
          memos: _todayNonChecklist,
          actions: _localActions,
        ),
        const _TimelogSection(isFirst: false),
      ],
    );
  }

  Widget _buildSection(TodaySection section, {required bool isFirst}) {
    switch (section) {
      case TodaySection.stats:
        return _StatsSection(
          memos: widget.memos,
          streak: widget.streak,
          isFirst: isFirst,
        );
      case TodaySection.habits:
        return _HabitsSection(habits: _todayHabits, isFirst: isFirst);
      case TodaySection.upcoming:
        return _UpcomingSection(events: _upcomingToday, isFirst: isFirst);
      case TodaySection.memos:
        return _MemosSection(memos: _todayNonChecklist, isFirst: isFirst);
      case TodaySection.todo:
        return _TodoSection(
          todos: _todayChecklists,
          isFirst: isFirst,
          onUpdate: widget.onUpdateMemo,
        );
      case TodaySection.timelog:
        return _TimelogSection(isFirst: isFirst);
    }
  }
}

// ── Inner tab button ──────────────────────────────────────────────────────────

class _InnerTabBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool editing;
  final bool hasDot;
  final VoidCallback onTap;
  final bool showDivider;

  const _InnerTabBtn({
    required this.label,
    required this.isActive,
    required this.editing,
    required this.hasDot,
    required this.onTap,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          // 활성: 폰트색 기반 옅은 배경 / 편집모드: surface / 비활성: 투명
          color: isActive && !editing
              ? kText.withValues(alpha: 0.08)
              : (editing ? kSurface : Colors.transparent),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                label,
                style: mono(
                  color: isActive ? kText : kDim,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasDot)
              Positioned(
                top: 4,
                right: 6,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: kMint,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (showDivider)
              Positioned(
                top: 6,
                bottom: 6,
                right: 0,
                child: Container(
                  width: 1,
                  color: kBorder.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isFirst;

  const _SectionHeader({required this.label, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 5),
      decoration: BoxDecoration(
        border: isFirst ? null : Border(top: BorderSide(color: kBorder)),
      ),
      child: Text(
        label,
        style: mono(
          color: kText,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _LogroomTodaySection extends StatelessWidget {
  final String label;
  final List<Memo> memos;
  final MemoActions? actions;
  final bool isFirst;

  const _LogroomTodaySection({
    required this.label,
    required this.memos,
    this.actions,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(label: label, isFirst: isFirst),
        if (memos.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Text(
              '비어 있음',
              style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 11),
            ),
          )
        else
          ...memos.map(
            (m) => actions == null
                ? _LogroomTodayRow(memo: m)
                : LogroomEntryTile(memo: m, actions: actions!),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _LogroomTodayRow extends StatelessWidget {
  final Memo memo;

  const _LogroomTodayRow({required this.memo});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: entryDisplayModeNotifier,
      builder: (context, mode, _) {
        final tags = memo.tags
            .where((t) => t != 'habit' && t != 'goal')
            .toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: mode == EntryDisplayMode.text ? 58 : 64,
                child: Text(
                  logroomPrefix(memo, mode),
                  style: mono(color: kText, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      logroomTitle(memo),
                      style: mono(color: kText, fontSize: 12, height: 1.35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 3,
                      children: [
                        Text(
                          logroomTime(memo.createdAt),
                          style: mono(color: kDim, fontSize: 10),
                        ),
                        if (tags.isNotEmpty)
                          Text(
                            tags.map((t) => '#$t').join(' '),
                            style: mono(color: kDim, fontSize: 10),
                          ),
                        if (memo.scheduledAt != null)
                          Text('일정 있음', style: mono(color: kDim, fontSize: 10)),
                        if (memo.appendNotes.isNotEmpty)
                          Text(
                            '댓글 ${memo.appendNotes.length}',
                            style: mono(color: kDim, fontSize: 10),
                          ),
                        if (memo.imagePaths.isNotEmpty)
                          Text(
                            '첨부 ${memo.imagePaths.length}',
                            style: mono(color: kDim, fontSize: 10),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LogroomTodoSection extends StatelessWidget {
  final List<Memo> todos;
  final MemoActions? actions;
  final void Function(Memo, String) onUpdate;

  const _LogroomTodoSection({
    required this.todos,
    required this.onUpdate,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(label: 'TASKS', isFirst: false),
        if (todos.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Text(
              '비어 있음',
              style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 11),
            ),
          )
        else
          ...todos.map(
            (m) => actions == null
                ? _LogroomTodoRow(memo: m, onUpdate: onUpdate)
                : LogroomEntryTile(memo: m, actions: actions!),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _LogroomTodoRow extends StatelessWidget {
  final Memo memo;
  final void Function(Memo, String) onUpdate;

  const _LogroomTodoRow({required this.memo, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final items = _parseChecklistItems(memo.content);
    if (items.isEmpty) return _LogroomTodayRow(memo: memo);
    return ValueListenableBuilder(
      valueListenable: entryDisplayModeNotifier,
      builder: (context, mode, _) {
        return Column(
          children: items.map((item) {
            return GestureDetector(
              onTap: () =>
                  onUpdate(memo, _toggleLine(memo.content, item.lineIndex)),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: mode == EntryDisplayMode.text ? 58 : 64,
                      child: Text(
                        logroomPrefix(memo, mode),
                        style: mono(
                          color: item.done ? _todayDoneTextColor() : kText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.text,
                        style: mono(
                          color: item.done ? _todayDoneTextColor() : kText,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── STATS section ─────────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  final List<Memo> memos;
  final int streak;
  final bool isFirst;

  const _StatsSection({
    required this.memos,
    required this.streak,
    required this.isFirst,
  });

  int get _todayCount {
    final now = DateTime.now();
    return memos.where((m) {
      final d = m.createdAt;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;
  }

  int get _todayWords {
    final now = DateTime.now();
    int total = 0;
    for (final m in memos) {
      final d = m.createdAt;
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        total += m.content
            .trim()
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .length;
      }
    }
    return total;
  }

  int get _todoCount => memos.where((m) => m.isChecklist).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(label: 'STATS', isFirst: isFirst),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(
            children: [
              _StatCell(label: 'STREAK', value: '$streak', unit: 'd'),
              Container(width: 1, color: kBorder.withValues(alpha: 0.5)),
              _StatCell(label: 'TODAY', value: '$_todayCount'),
              Container(width: 1, color: kBorder.withValues(alpha: 0.5)),
              _StatCell(label: 'WORDS', value: '$_todayWords'),
              Container(width: 1, color: kBorder.withValues(alpha: 0.5)),
              _StatCell(label: 'TODO', value: '$_todoCount'),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;

  const _StatCell({required this.label, required this.value, this.unit});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              label,
              style: mono(color: kDim, fontSize: 9, letterSpacing: 0.5),
            ),
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: mono(
                      color: kText,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (unit != null)
                    TextSpan(
                      text: unit,
                      style: mono(color: kDim, fontSize: 9),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── HABITS section ────────────────────────────────────────────────────────────

class _HabitsSection extends StatelessWidget {
  final List<Memo> habits;
  final bool isFirst;

  const _HabitsSection({required this.habits, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(label: 'HABITS', isFirst: isFirst),
        if (habits.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Text(
              '오늘 #habit 메모 없음',
              style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 11),
            ),
          )
        else
          ...habits.map((m) => _HabitRow(content: m.content)),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _HabitRow extends StatelessWidget {
  final String content;

  const _HabitRow({required this.content});

  @override
  Widget build(BuildContext context) {
    final display = content.replaceAll(RegExp(r'\s*#habit\s*'), ' ').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Row(
        children: [
          Text('· ', style: mono(color: kDim, fontSize: 12)),
          Expanded(
            child: Text(
              display,
              style: mono(color: kDim, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── UPCOMING section ──────────────────────────────────────────────────────────

class _UpcomingSection extends StatelessWidget {
  final List<Memo> events;
  final bool isFirst;

  const _UpcomingSection({required this.events, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(label: 'UPCOMING', isFirst: isFirst),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Text(
              '오늘 일정 없음',
              style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 11),
            ),
          )
        else
          ...events.map((m) => _EventRow(memo: m)),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  final Memo memo;

  const _EventRow({required this.memo});

  @override
  Widget build(BuildContext context) {
    final t = memo.scheduledAt!;
    final timeStr =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              timeStr,
              style: mono(color: kDim, fontSize: 10),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
          Container(width: 2, height: 20, color: kMint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              memo.content,
              style: mono(color: kText, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── MEMOS section ─────────────────────────────────────────────────────────────

class _MemosSection extends StatelessWidget {
  final List<Memo> memos;
  final bool isFirst;

  const _MemosSection({required this.memos, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(label: 'MEMOS', isFirst: isFirst),
        if (memos.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Text(
              '오늘 메모 없음',
              style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 11),
            ),
          )
        else
          ...memos.take(5).map((m) => _MemoRow(memo: m)),
        if (memos.length > 5)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
            child: Text(
              '+ ${memos.length - 5}개 더',
              style: mono(color: kDim, fontSize: 10),
            ),
          )
        else
          const SizedBox(height: 4),
      ],
    );
  }
}

class _MemoRow extends StatelessWidget {
  final Memo memo;

  const _MemoRow({required this.memo});

  @override
  Widget build(BuildContext context) {
    final t = memo.createdAt;
    final timeStr =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(timeStr, style: mono(color: kDim, fontSize: 10)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: kBorder, width: 2)),
            ),
            child: Text(
              memo.content,
              style: mono(color: kText, fontSize: 12, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── TODO section ──────────────────────────────────────────────────────────────

class _TodoSection extends StatelessWidget {
  final List<Memo> todos;
  final bool isFirst;
  final void Function(Memo, String) onUpdate;

  const _TodoSection({
    required this.todos,
    required this.isFirst,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(label: 'TODO', isFirst: isFirst),
        if (todos.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Text(
              '오늘 할일 없음',
              style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 11),
            ),
          )
        else
          ...todos.map((m) => _TodoRow(memo: m, onUpdate: onUpdate)),
        const SizedBox(height: 4),
      ],
    );
  }
}

// 체크리스트 마크다운 문법(- [ ], - [x], * [ ], * [x])을 파싱해
// 체크 상태·텍스트·원본 줄 인덱스를 반환. 원본 Memo 데이터는 변경하지 않음.
List<({bool done, String text, int lineIndex})> _parseChecklistItems(
  String content,
) {
  final lines = content.split('\n');
  final result = <({bool done, String text, int lineIndex})>[];
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trimLeft();
    if (line.startsWith('- [x] ') || line.startsWith('* [x] ')) {
      result.add((done: true, text: line.substring(6).trim(), lineIndex: i));
    } else if (line.startsWith('- [ ] ') || line.startsWith('* [ ] ')) {
      result.add((done: false, text: line.substring(6).trim(), lineIndex: i));
    } else if (line.isNotEmpty) {
      result.add((done: false, text: line.trim(), lineIndex: i));
    }
  }
  return result;
}

// 특정 줄의 체크 상태를 반전시킨 새 content 반환. 원본은 변경하지 않음.
String _toggleLine(String content, int lineIndex) {
  final lines = content.split('\n');
  if (lineIndex < 0 || lineIndex >= lines.length) return content;
  final line = lines[lineIndex];
  if (line.contains('- [ ] ') || line.contains('* [ ] ')) {
    lines[lineIndex] = line
        .replaceFirst('- [ ] ', '- [x] ')
        .replaceFirst('* [ ] ', '* [x] ');
  } else if (line.contains('- [x] ') || line.contains('* [x] ')) {
    lines[lineIndex] = line
        .replaceFirst('- [x] ', '- [ ] ')
        .replaceFirst('* [x] ', '* [ ] ');
  }
  return lines.join('\n');
}

class _TodoRow extends StatelessWidget {
  final Memo memo;
  final void Function(Memo, String) onUpdate;

  const _TodoRow({required this.memo, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final items = _parseChecklistItems(memo.content);
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: items.map((item) {
        return GestureDetector(
          onTap: () {
            final newContent = _toggleLine(memo.content, item.lineIndex);
            onUpdate(memo, newContent);
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // fontSize:12 noScaling 환경에서 라인높이(≈17px) 대비
                // 체크박스(11px)를 시각적으로 첫 줄에 맞추기 위한 top 오프셋
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: item.done ? _todayDoneAccentColor() : kBorder,
                      ),
                      color: item.done
                          ? _todayDoneAccentColor().withValues(alpha: 0.15)
                          : Colors.transparent,
                    ),
                    alignment: Alignment.center,
                    child: item.done
                        ? Text(
                            '✓',
                            style: mono(
                              color: _todayDoneAccentColor(),
                              fontSize: 8,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.text,
                    style: mono(
                      color: item.done ? _todayDoneTextColor() : kText,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── TIMELOG section ───────────────────────────────────────────────────────────

class _TimelogSection extends StatefulWidget {
  final bool isFirst;

  const _TimelogSection({required this.isFirst});

  @override
  State<_TimelogSection> createState() => _TimelogSectionState();
}

class _TimelogSectionState extends State<_TimelogSection> {
  final Map<int, String> _entries = {};
  final Map<int, TextEditingController> _ctrls = {};
  late final String _todayKey;

  static const _startHour = 6;
  static const _endHour = 22;

  @override
  void initState() {
    super.initState();
    _todayKey = _dateKey(DateTime.now());
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final all = await _loadAllTimelogs();
    final dayData = all[_todayKey] ?? {};
    if (mounted) {
      setState(() {
        _entries.clear();
        dayData.forEach((hStr, text) {
          final h = int.tryParse(hStr);
          if (h != null && text.isNotEmpty) _entries[h] = text;
        });
      });
    }
  }

  Future<void> _persist() async {
    await _saveTimelog(_todayKey, Map.from(_entries));
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _currentHour => DateTime.now().hour;

  @override
  Widget build(BuildContext context) {
    final now = _currentHour;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(label: 'TIMELOG', isFirst: widget.isFirst),
        for (int h = _startHour; h <= _endHour; h++) ...[
          _TimeRow(
            hour: h,
            isNow: h == now,
            text: _entries[h],
            onTap: () => _startEdit(h),
          ),
          if (h == now)
            Container(
              height: 1,
              color: kMint.withValues(alpha: 0.5),
              margin: const EdgeInsets.symmetric(horizontal: 14),
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  void _startEdit(int hour) {
    final ctrl = _ctrls.putIfAbsent(
      hour,
      () => TextEditingController(text: _entries[hour] ?? ''),
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: kSurface,
                border: Border(top: BorderSide(color: kBorder)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: mono(color: kDim, fontSize: 10, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: mono(color: kText, fontSize: 12),
                    cursorColor: kMint,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      filled: true,
                      fillColor: kBg,
                      hintText: '이 시간에 뭘 했나요...',
                      hintStyle: mono(
                        color: kDim.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
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
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          '취소',
                          style: mono(color: kDim, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            final v = ctrl.text.trim();
                            if (v.isEmpty) {
                              _entries.remove(hour);
                            } else {
                              _entries[hour] = v;
                            }
                          });
                          _persist();
                          Navigator.pop(context);
                        },
                        child: Text(
                          '저장',
                          style: mono(
                            color: kMint,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
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
      },
    );
  }
}

class _TimeRow extends StatelessWidget {
  final int hour;
  final bool isNow;
  final String? text;
  final VoidCallback onTap;

  const _TimeRow({
    required this.hour,
    required this.isNow,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final has = text != null && text!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 72,
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: mono(color: kDim, fontSize: 10),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
              ),
              // timeline line
              SizedBox(
                width: 20,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1,
                        color: kBorder.withValues(alpha: 0.5),
                      ),
                    ),
                    Positioned(
                      top: 9,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isNow ? kMint : (has ? kText : kBg),
                          border: Border.all(
                            color: isNow ? kMint : (has ? kText : kBorder),
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
                  padding: const EdgeInsets.fromLTRB(4, 5, 0, 5),
                  child: Text(
                    has ? text! : '...',
                    style: mono(
                      color: has ? kText : kDim.withValues(alpha: 0.35),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
