import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../flavor.dart';
import '../models/changelog_data.dart';
import '../models/checklist_data.dart';
import '../models/dev_log_data.dart';
import '../models/folder.dart';
import '../models/memo.dart';
import '../models/qa_data.dart';
import '../services/storage_service.dart';

// ──────────────────────────────────────────────────────────────────
// Dev Center — nemo2test only
// ──────────────────────────────────────────────────────────────────

class DevCenterScreen extends StatefulWidget {
  const DevCenterScreen({super.key});

  @override
  State<DevCenterScreen> createState() => _DevCenterScreenState();
}

class _DevCenterScreenState extends State<DevCenterScreen> {
  int _tab = 0;
  static const _tabs = ['STATUS', 'CHANGELOG', 'QA', 'TOKENS', 'NOTES', 'CHECKS'];
  late final PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: themeNotifier,
      builder: (_, _, _) => Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Container(height: 1, color: kBorder),
              _buildTabBar(),
              Container(height: 1, color: kBorder),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 44,
      color: kBg,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text('←', style: mono(color: kDim, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'DEV CENTER',
              style: mono(color: kMint, fontSize: 13, letterSpacing: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 30),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final active = _tab == i;
          return GestureDetector(
            onTap: () {
              setState(() => _tab = i);
              _pageCtrl.jumpToPage(i);
            },
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? kMint.withValues(alpha: 0.08) : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: active ? kMint : Colors.transparent,
                    width: 2,
                  ),
                  right: i < _tabs.length - 1
                      ? BorderSide(color: kBorder)
                      : BorderSide.none,
                ),
              ),
              child: Text(
                _tabs[i],
                style: mono(
                  color: active ? kMint : kDim,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBody() {
    return PageView(
      controller: _pageCtrl,
      onPageChanged: (i) => setState(() => _tab = i),
      children: const [
        _StatusTab(),
        _ChangelogTab(),
        _QaTab(),
        _TokensTab(),
        _NotesTab(),
        _ChecksTab(),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// STATUS Tab
// ──────────────────────────────────────────────────────────────────

class _StatusTab extends StatefulWidget {
  const _StatusTab();

  @override
  State<_StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<_StatusTab> {
  int _memoCount = 0;
  int _folderCount = 0;
  int _tagCount = 0;
  int _todayCount = 0;
  bool _loaded = false;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final List<Memo> memos = await StorageService.loadMemos();
    final List<Folder> folders = await StorageService.loadFolders();
    final today = DateTime.now();
    if (mounted) {
      setState(() {
        _memoCount = memos.length;
        _folderCount = folders.length;
        _tagCount = {for (final m in memos) ...m.tags}.length;
        _todayCount = memos.where((m) {
          final c = m.createdAt;
          return c.year == today.year &&
              c.month == today.month &&
              c.day == today.day;
        }).length;
        _loaded = true;
      });
    }
  }

  String _fmtUptime() {
    final d = DateTime.now().difference(appStartTime);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: appInsetsSymmetric(horizontal: 20, vertical: 16),
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 24),
        _buildMilestonesSection(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: kMint.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kChangelog.last.version,
            style: mono(color: kMint, fontSize: 22, letterSpacing: 1),
          ),
          Text('현재 버전', style: mono(color: kDim, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 14),
          if (_loaded)
            _buildStatGrid()
          else
            Text('로딩 중...', style: mono(color: kDim, fontSize: 11)),
          const SizedBox(height: 12),
          Container(height: 1, color: kBorder.withValues(alpha: 0.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('앱 실행시간  ', style: mono(color: kDim, fontSize: 10)),
              Text(_fmtUptime(), style: mono(color: kText, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    final items = [
      ('메모', '$_memoCount'),
      ('폴더', '$_folderCount'),
      ('태그', '$_tagCount'),
      ('오늘 기록', '$_todayCount'),
    ];
    return Row(
      children: items
          .map(
            (e) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.$2, style: mono(color: kText, fontSize: 18)),
                  Text(e.$1, style: mono(color: kDim, fontSize: 10)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMilestonesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('개발 이력', style: mono(color: kDim, fontSize: 10, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        ...kDevMilestones.map(_buildMilestoneBlock),
      ],
    );
  }

  Widget _buildMilestoneBlock(DevMilestone milestone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            milestone.title,
            style: mono(color: kMint, fontSize: 11, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
          ...milestone.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('- ', style: mono(color: kDim, fontSize: 11)),
                  Expanded(
                    child: Text(item, style: mono(color: kText, fontSize: 11, height: 1.5)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: kBorder.withValues(alpha: 0.3)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// CHANGELOG Tab
// ──────────────────────────────────────────────────────────────────

class _ChangelogTab extends StatelessWidget {
  const _ChangelogTab();

  @override
  Widget build(BuildContext context) {
    final entries = kChangelog.reversed.toList();
    return ListView.builder(
      padding: appInsetsSymmetric(horizontal: 20, vertical: 16),
      itemCount: entries.length,
      itemBuilder: (_, i) => _ChangelogCard(entry: entries[i]),
    );
  }
}

class _ChangelogCard extends StatelessWidget {
  final ChangelogEntry entry;
  const _ChangelogCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(entry.date, style: mono(color: kDim, fontSize: 10)),
              const SizedBox(width: 10),
              Text(
                entry.version,
                style: mono(color: kMint, fontSize: 13, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (entry.features.isNotEmpty) _section('기능', entry.features),
          if (entry.fixes.isNotEmpty) _section('수정', entry.fixes),
          if (entry.design.isNotEmpty) _section('디자인', entry.design),
          const SizedBox(height: 4),
          Container(height: 1, color: kBorder.withValues(alpha: 0.4)),
        ],
      ),
    );
  }

  Widget _section(String label, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '[$label]',
            style: mono(color: kTeal, fontSize: 10, letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          ...items.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('- ', style: mono(color: kDim, fontSize: 11)),
                  Expanded(
                    child: Text(c, style: mono(color: kText, fontSize: 11, height: 1.5)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// QA Tab
// ──────────────────────────────────────────────────────────────────

class _QaTab extends StatefulWidget {
  const _QaTab();

  @override
  State<_QaTab> createState() => _QaTabState();
}

class _QaTabState extends State<_QaTab> {
  static const _prefix = 'nemo2test_qa_';
  Map<String, bool> _checks = {};
  bool _loaded = false;
  String _sessionDate = '';
  String _sessionTester = '';
  String _sessionResult = '-';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, bool>{};
    for (final cat in kQaCategories) {
      for (final item in cat.items) {
        map[item.id] = prefs.getBool('$_prefix${item.id}') ?? false;
      }
    }
    if (mounted) {
      setState(() {
        _checks = map;
        _sessionDate = prefs.getString('${_prefix}session_date') ?? '';
        _sessionTester = prefs.getString('${_prefix}session_tester') ?? '';
        _sessionResult = prefs.getString('${_prefix}session_result') ?? '-';
        _loaded = true;
      });
    }
  }

  Future<void> _toggle(String id) async {
    final next = !(_checks[id] ?? false);
    setState(() => _checks[id] = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$id', next);
  }

  Future<void> _saveSession({String? date, String? tester, String? result}) async {
    setState(() {
      if (date != null) _sessionDate = date;
      if (tester != null) _sessionTester = tester;
      if (result != null) _sessionResult = result;
    });
    final prefs = await SharedPreferences.getInstance();
    if (date != null) await prefs.setString('${_prefix}session_date', date);
    if (tester != null) await prefs.setString('${_prefix}session_tester', tester);
    if (result != null) await prefs.setString('${_prefix}session_result', result);
  }

  void _cycleResult() {
    const options = ['-', 'WIP', 'PASS', 'FAIL'];
    final idx = options.indexOf(_sessionResult);
    _saveSession(result: options[(idx + 1) % options.length]);
  }

  Future<void> _editTextField(
    String fieldLabel,
    String current,
    void Function(String) onSave,
  ) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kBg,
        title: Text(fieldLabel, style: mono(color: kMint, fontSize: 12, letterSpacing: 1)),
        content: TextField(
          controller: ctrl,
          style: mono(color: kText, fontSize: 12),
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: kBorder)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kMint)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: mono(color: kDim, fontSize: 11)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: Text('저장', style: mono(color: kMint, fontSize: 11)),
          ),
        ],
      ),
    );
    if (result != null) onSave(result);
  }

  Future<void> _resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final cat in kQaCategories) {
      for (final item in cat.items) {
        await prefs.remove('$_prefix${item.id}');
      }
    }
    if (mounted) setState(() => _checks = {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Center(child: Text('로딩 중...', style: mono(color: kDim, fontSize: 11)));
    }

    final allItems = [for (final c in kQaCategories) ...c.items];
    final doneCount = allItems.where((i) => _checks[i.id] == true).length;
    final total = allItems.length;

    return Column(
      children: [
        _buildSummaryBar(doneCount, total),
        Expanded(
          child: ListView.builder(
            padding: appInsetsSymmetric(horizontal: 20, vertical: 12),
            itemCount: kQaCategories.length + 2,
            itemBuilder: (_, i) {
              if (i == 0) return _buildSessionSection();
              if (i == kQaCategories.length + 1) return _buildResetBtn();
              return _QaCategorySection(
                category: kQaCategories[i - 1],
                checks: _checks,
                onToggle: _toggle,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar(int done, int total) {
    final pct = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$done / $total', style: mono(color: kMint, fontSize: 12)),
              const SizedBox(width: 8),
              Text('(${(pct * 100).round()}%)', style: mono(color: kDim, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: kBorder.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(kMint),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSection() {
    final resultColor = _sessionResult == 'PASS'
        ? kMint
        : _sessionResult == 'FAIL'
            ? Colors.redAccent
            : kDim;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QA SESSION', style: mono(color: kDim, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(border: Border.all(color: kBorder)),
            child: Column(
              children: [
                _sessionRow(
                  'DATE',
                  _sessionDate.isEmpty ? '-' : _sessionDate,
                  () => _editTextField('DATE', _sessionDate, (v) => _saveSession(date: v)),
                ),
                _sessionRow(
                  'TESTER',
                  _sessionTester.isEmpty ? '-' : _sessionTester,
                  () => _editTextField('TESTER', _sessionTester, (v) => _saveSession(tester: v)),
                ),
                GestureDetector(
                  onTap: _cycleResult,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text('RESULT', style: mono(color: kDim, fontSize: 11)),
                        ),
                        Expanded(
                          child: Text(
                            _sessionResult,
                            style: mono(color: resultColor, fontSize: 11),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('↺', style: mono(color: kDim, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionRow(String key, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            SizedBox(width: 80, child: Text(key, style: mono(color: kDim, fontSize: 11))),
            Expanded(
              child: Text(value, style: mono(color: kText, fontSize: 11), textAlign: TextAlign.right),
            ),
            const SizedBox(width: 6),
            Text('›', style: mono(color: kDim, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildResetBtn() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: GestureDetector(
        onTap: _resetAll,
        child: Text('전체 초기화', style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 10)),
      ),
    );
  }
}

class _QaCategorySection extends StatelessWidget {
  final QaCategory category;
  final Map<String, bool> checks;
  final void Function(String) onToggle;

  const _QaCategorySection({
    required this.category,
    required this.checks,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category.label, style: mono(color: kDim, fontSize: 10, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          ...category.items.map(
            (item) => _QaCheckRow(
              item: item,
              checked: checks[item.id] ?? false,
              onToggle: () => onToggle(item.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _QaCheckRow extends StatelessWidget {
  final QaItem item;
  final bool checked;
  final VoidCallback onToggle;

  const _QaCheckRow({required this.item, required this.checked, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Text(
              checked ? '[x]' : '[ ]',
              style: mono(color: checked ? kMint : kDim, fontSize: 11, letterSpacing: 0.5),
            ),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: mono(color: checked ? kText : kDim.withValues(alpha: 0.8), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// TOKENS Tab
// ──────────────────────────────────────────────────────────────────

class _TokensTab extends StatelessWidget {
  const _TokensTab();

  String _hex(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    final a = (c.a * 255).round().toRadixString(16).padLeft(2, '0');
    return a == 'ff' ? '#$r$g$b' : '#$a$r$g$b';
  }

  @override
  Widget build(BuildContext context) {
    final groups = [
      ('ACCENT', [('kAccent', kAccent)]),
      ('BACKGROUND', [
        ('kBg2', kBg2),
        ('kBg3', kBg3),
        ('kBg4', kBg4),
        ('kBg5', kBg5),
      ]),
      ('TEXT', [
        ('kText2', kText2),
        ('kText3', kText3),
        ('kText4', kText4),
      ]),
      ('TIMELINE', [
        ('kTlLine', kTlLine),
        ('kTlDot', kTlDot),
      ]),
    ];

    return ListView(
      padding: appInsetsSymmetric(horizontal: 20, vertical: 16),
      children: [
        for (final group in groups) ...[
          Text(group.$1, style: mono(color: kDim, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          for (final token in group.$2)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: token.$2,
                      border: Border.all(color: kBorder.withValues(alpha: 0.5)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 80,
                    child: Text(token.$1, style: mono(color: kText, fontSize: 11)),
                  ),
                  Text(_hex(token.$2), style: mono(color: kDim, fontSize: 11)),
                ],
              ),
            ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// NOTES Tab
// ──────────────────────────────────────────────────────────────────

class _NotesTab extends StatefulWidget {
  const _NotesTab();

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  static const _key = 'devcenter_notes';
  late final TextEditingController _ctrl;
  Timer? _debounce;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _loadNotes();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_key) ?? '';
    if (mounted) {
      _ctrl.text = text;
      _ctrl.selection = TextSelection.collapsed(offset: text.length);
      setState(() => _loaded = true);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Center(child: Text('로딩 중...', style: mono(color: kDim, fontSize: 11)));
    }
    return Padding(
      padding: appInsetsSymmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NOTES', style: mono(color: kDim, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: _onChanged,
              style: mono(color: kText, fontSize: 12, height: 1.6),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
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
                  borderSide: BorderSide(color: kMint.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.zero,
                ),
                contentPadding: const EdgeInsets.all(12),
                hintText: '개발 메모...',
                hintStyle: mono(color: kDim.withValues(alpha: 0.4), fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// CHECKS Tab — 개발 관리 체크리스트 3종
// ──────────────────────────────────────────────────────────────────

String _clKey(String listId, String itemId, String field) =>
    'devcenter_cl_${listId}_${itemId}_$field';

String _clListKey(String listId, String field) =>
    'devcenter_cl_${listId}_$field';

String _fmtTime(DateTime dt) {
  final y = dt.year.toString();
  final mo = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final mi = dt.minute.toString().padLeft(2, '0');
  final s = dt.second.toString().padLeft(2, '0');
  return '$y-$mo-$d $h:$mi:$s';
}

class _ChecksTab extends StatefulWidget {
  const _ChecksTab();

  @override
  State<_ChecksTab> createState() => _ChecksTabState();
}

class _ChecksTabState extends State<_ChecksTab> {
  Map<String, bool> _checked = {};
  Map<String, String> _checkedAt = {};
  Map<String, String> _memos = {};
  Map<String, String> _createdAt = {};
  Map<String, String> _updatedAt = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final now = _fmtTime(DateTime.now());
    final checked = <String, bool>{};
    final checkedAt = <String, String>{};
    final memos = <String, String>{};
    final createdAt = <String, String>{};
    final updatedAt = <String, String>{};

    for (final list in kChecklists) {
      final ca = prefs.getString(_clListKey(list.id, 'createdAt'));
      if (ca == null) {
        await prefs.setString(_clListKey(list.id, 'createdAt'), now);
        createdAt[list.id] = now;
      } else {
        createdAt[list.id] = ca;
      }
      updatedAt[list.id] = prefs.getString(_clListKey(list.id, 'updatedAt')) ?? createdAt[list.id]!;

      for (final item in list.items) {
        final k = '${list.id}/${item.id}';
        checked[k] = prefs.getBool(_clKey(list.id, item.id, 'checked')) ?? false;
        checkedAt[k] = prefs.getString(_clKey(list.id, item.id, 'checkedAt')) ?? '';
        memos[k] = prefs.getString(_clKey(list.id, item.id, 'memo')) ?? '';
      }
    }

    if (mounted) {
      setState(() {
        _checked = checked;
        _checkedAt = checkedAt;
        _memos = memos;
        _createdAt = createdAt;
        _updatedAt = updatedAt;
        _loaded = true;
      });
    }
  }

  Future<void> _toggle(String listId, String itemId) async {
    final k = '$listId/$itemId';
    final next = !(_checked[k] ?? false);
    final now = _fmtTime(DateTime.now());
    setState(() {
      _checked[k] = next;
      if (next) _checkedAt[k] = now;
      _updatedAt[listId] = now;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clKey(listId, itemId, 'checked'), next);
    if (next) await prefs.setString(_clKey(listId, itemId, 'checkedAt'), now);
    await prefs.setString(_clListKey(listId, 'updatedAt'), now);
  }

  Future<void> _editMemo(String listId, String itemId) async {
    final k = '$listId/$itemId';
    final ctrl = TextEditingController(text: _memos[k] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kBg,
        title: Text('메모', style: mono(color: kMint, fontSize: 12, letterSpacing: 1)),
        content: TextField(
          controller: ctrl,
          style: mono(color: kText, fontSize: 12),
          maxLines: 5,
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: kBorder)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kMint)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: mono(color: kDim, fontSize: 11)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: Text('저장', style: mono(color: kMint, fontSize: 11)),
          ),
        ],
      ),
    );
    if (result == null) return;
    final now = _fmtTime(DateTime.now());
    setState(() {
      _memos[k] = result;
      _updatedAt[listId] = now;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clKey(listId, itemId, 'memo'), result);
    await prefs.setString(_clListKey(listId, 'updatedAt'), now);
  }

  Future<void> _resetWorkflow() async {
    const listId = 'workflow';
    final list = kChecklists.firstWhere((l) => l.id == listId);
    final now = _fmtTime(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    for (final item in list.items) {
      final k = '$listId/${item.id}';
      await prefs.remove(_clKey(listId, item.id, 'checked'));
      await prefs.remove(_clKey(listId, item.id, 'checkedAt'));
      await prefs.remove(_clKey(listId, item.id, 'memo'));
      if (mounted) {
        setState(() {
          _checked[k] = false;
          _checkedAt[k] = '';
          _memos[k] = '';
        });
      }
    }
    await prefs.setString(_clListKey(listId, 'updatedAt'), now);
    if (mounted) setState(() => _updatedAt[listId] = now);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Center(child: Text('로딩 중...', style: mono(color: kDim, fontSize: 11)));
    }
    return ListView.builder(
      padding: appInsetsSymmetric(horizontal: 20, vertical: 16),
      itemCount: kChecklists.length,
      itemBuilder: (_, i) {
        final list = kChecklists[i];
        final items = list.items;
        final totalDone = items.where((it) => _checked['${list.id}/${it.id}'] == true).length;
        final requiredItems = items.where((it) => it.isRequired).toList();
        final requiredDone = requiredItems.where((it) => _checked['${list.id}/${it.id}'] == true).length;
        final canClose = requiredItems.isNotEmpty && requiredDone == requiredItems.length;

        return _ChecklistSection(
          list: list,
          totalDone: totalDone,
          requiredDone: requiredDone,
          requiredTotal: requiredItems.length,
          canClose: canClose,
          createdAt: _createdAt[list.id] ?? '',
          updatedAt: _updatedAt[list.id] ?? '',
          checked: _checked,
          checkedAt: _checkedAt,
          memos: _memos,
          onToggle: (itemId) => _toggle(list.id, itemId),
          onMemoEdit: (itemId) => _editMemo(list.id, itemId),
          onResetWorkflow: list.id == 'workflow' ? _resetWorkflow : null,
        );
      },
    );
  }
}

class _ChecklistSection extends StatelessWidget {
  final ChecklistList list;
  final int totalDone;
  final int requiredDone;
  final int requiredTotal;
  final bool canClose;
  final String createdAt;
  final String updatedAt;
  final Map<String, bool> checked;
  final Map<String, String> checkedAt;
  final Map<String, String> memos;
  final void Function(String itemId) onToggle;
  final void Function(String itemId) onMemoEdit;
  final VoidCallback? onResetWorkflow;

  const _ChecklistSection({
    required this.list,
    required this.totalDone,
    required this.requiredDone,
    required this.requiredTotal,
    required this.canClose,
    required this.createdAt,
    required this.updatedAt,
    required this.checked,
    required this.checkedAt,
    required this.memos,
    required this.onToggle,
    required this.onMemoEdit,
    this.onResetWorkflow,
  });

  @override
  Widget build(BuildContext context) {
    final total = list.items.length;
    final groups = <String, List<ChecklistItem>>{};
    for (final item in list.items) {
      groups.putIfAbsent(item.category, () => []).add(item);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(list.label, style: mono(color: kDim, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          // Progress row
          Row(
            children: [
              Text(
                '전체 $totalDone/$total',
                style: mono(color: totalDone == total ? kMint : kText, fontSize: 10),
              ),
              Text('  ·  ', style: mono(color: kDim, fontSize: 10)),
              Text(
                '필수 $requiredDone/$requiredTotal',
                style: mono(color: requiredDone == requiredTotal ? kMint : kDim, fontSize: 10),
              ),
              Text('  ·  ', style: mono(color: kDim, fontSize: 10)),
              Text(
                canClose ? '마감 가능' : '아직 마감 불가',
                style: mono(
                  color: canClose ? kMint : kDim.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Progress bar
          ClipRRect(
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : totalDone / total,
              backgroundColor: kBorder.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(totalDone == total ? kMint : kMint.withValues(alpha: 0.5)),
              minHeight: 2,
            ),
          ),
          const SizedBox(height: 4),
          // Meta
          if (createdAt.isNotEmpty)
            Text('생성 $createdAt', style: mono(color: kDim.withValues(alpha: 0.4), fontSize: 9)),
          if (updatedAt.isNotEmpty)
            Text('수정 $updatedAt', style: mono(color: kDim.withValues(alpha: 0.4), fontSize: 9)),
          const SizedBox(height: 12),
          // Items by category
          ...groups.entries.map((entry) => _CategoryGroup(
            category: entry.key,
            items: entry.value,
            listId: list.id,
            checked: checked,
            checkedAt: checkedAt,
            memos: memos,
            onToggle: onToggle,
            onMemoEdit: onMemoEdit,
          )),
          // WORKFLOW reset button
          if (onResetWorkflow != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: onResetWorkflow,
                child: Text(
                  'WORKFLOW 초기화',
                  style: mono(color: kDim.withValues(alpha: 0.4), fontSize: 9),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Container(height: 1, color: kBorder.withValues(alpha: 0.2)),
        ],
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  final String category;
  final String listId;
  final List<ChecklistItem> items;
  final Map<String, bool> checked;
  final Map<String, String> checkedAt;
  final Map<String, String> memos;
  final void Function(String itemId) onToggle;
  final void Function(String itemId) onMemoEdit;

  const _CategoryGroup({
    required this.category,
    required this.listId,
    required this.items,
    required this.checked,
    required this.checkedAt,
    required this.memos,
    required this.onToggle,
    required this.onMemoEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category, style: mono(color: kDim.withValues(alpha: 0.6), fontSize: 9, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          ...items.map((item) {
            final k = '$listId/${item.id}';
            return _ChecklistItemRow(
              item: item,
              isChecked: checked[k] ?? false,
              checkedAt: checkedAt[k] ?? '',
              memo: memos[k] ?? '',
              onToggle: () => onToggle(item.id),
              onMemoEdit: () => onMemoEdit(item.id),
            );
          }),
        ],
      ),
    );
  }
}

class _ChecklistItemRow extends StatelessWidget {
  final ChecklistItem item;
  final bool isChecked;
  final String checkedAt;
  final String memo;
  final VoidCallback onToggle;
  final VoidCallback onMemoEdit;

  const _ChecklistItemRow({
    required this.item,
    required this.isChecked,
    required this.checkedAt,
    required this.memo,
    required this.onToggle,
    required this.onMemoEdit,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isChecked ? kDim.withValues(alpha: 0.55) : kText;
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox indicator
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                isChecked ? '[x]' : '[ ]',
                style: mono(color: isChecked ? kMint : kDim, fontSize: 11, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.label, style: mono(color: labelColor, fontSize: 11)),
                      ),
                      if (item.isRequired)
                        Text(' *', style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 9)),
                    ],
                  ),
                  Text(
                    item.description,
                    style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 9, height: 1.4),
                  ),
                  if (isChecked && checkedAt.isNotEmpty)
                    Text(
                      '체크 $checkedAt',
                      style: mono(color: kDim.withValues(alpha: 0.4), fontSize: 9),
                    ),
                  if (memo.isNotEmpty)
                    Text(
                      memo,
                      style: mono(color: kDim.withValues(alpha: 0.7), fontSize: 10, height: 1.4),
                    ),
                ],
              ),
            ),
            // Memo edit button
            GestureDetector(
              onTap: onMemoEdit,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text(
                  memo.isEmpty ? '…' : '›',
                  style: mono(color: kDim.withValues(alpha: 0.35), fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
