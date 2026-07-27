import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/dashboard_item.dart';
import '../models/memo.dart';

/// 개인 대시보드 화면.
///
/// 하나의 [ReorderableListView] 안에 "대시보드 카드들 → 구분선 → 더보기 행들"을
/// 담는다. 길게 눌러 드래그하면 순서가 바뀌고, 구분선을 넘나들면 카드↔더보기로
/// 자리를 옮긴다. 구분선의 최종 위치를 기준으로 두 목록을 나눠 저장한다.
class DashboardScreen extends StatefulWidget {
  final List<Memo> memos;
  final int streak;

  /// 카드/행을 탭했을 때 호출. menuId 는 home_screen 의 _selectBottomMenu 케이스.
  final void Function(String menuId) onOpen;

  const DashboardScreen({
    super.key,
    required this.memos,
    required this.streak,
    required this.onOpen,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _divider = '__divider__';

  DashboardConfig? _cfg;
  List<String> _items = []; // 카드 + [_divider] + 더보기, 통합 순서

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final cfg = await DashboardConfig.load();
    if (!mounted) return;
    setState(() {
      _cfg = cfg;
      _items = [...cfg.dashboard, _divider, ...cfg.more];
    });
  }

  void _persist() {
    final idx = _items.indexOf(_divider);
    final dash = _items.sublist(0, idx);
    final more = _items.sublist(idx + 1);
    final cfg = _cfg;
    if (cfg == null) return;
    cfg.dashboard = dash;
    cfg.more = more;
    cfg.save();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = _items.removeAt(oldIndex);
      _items.insert(newIndex, moved);
    });
    _persist();
  }

  // ── 요약 계산 ────────────────────────────────────────────────
  DateTime get _todayStart {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  int get _taskCount => widget.memos.where((m) => m.isChecklist).length;
  int get _habitCount =>
      widget.memos.where((m) => m.tags.contains('habit')).length;
  int get _goalCount =>
      widget.memos.where((m) => m.tags.contains('goal')).length;

  List<Memo> get _upcomingEvents {
    final start = _todayStart;
    final list =
        widget.memos
            .where(
              (m) =>
                  m.scheduledAt != null && !m.scheduledAt!.isBefore(start),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    return list;
  }

  /// 최근 7일(오늘 포함) 작성 개수 — 월→오늘 순.
  List<int> get _weekCounts {
    final start = _todayStart;
    final counts = List<int>.filled(7, 0);
    for (final m in widget.memos) {
      final d = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      final diff = start.difference(d).inDays; // 0 = 오늘
      if (diff >= 0 && diff < 7) counts[6 - diff]++;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    if (_cfg == null) {
      return const SizedBox.shrink();
    }
    final dividerIndex = _items.indexOf(_divider);

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      itemCount: _items.length,
      onReorder: _onReorder,
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        child: child,
      ),
      itemBuilder: (context, index) {
        final id = _items[index];
        if (id == _divider) {
          return _MoreDivider(key: const ValueKey(_divider));
        }
        final item = dashboardItemById(id);
        if (item == null) {
          return SizedBox.shrink(key: ValueKey('missing_$id'));
        }
        final inDashboard = index < dividerIndex;
        return Padding(
          key: ValueKey(id),
          padding: EdgeInsets.only(bottom: inDashboard ? 12 : 0),
          child: inDashboard
              ? _DashboardCard(
                  item: item,
                  onTap: () => widget.onOpen(item.id),
                  child: _summaryFor(item.id),
                )
              : _MoreRow(item: item, onTap: () => widget.onOpen(item.id)),
        );
      },
    );
  }

  /// 카드 본문(요약). summary 항목이 아니면 null → 카드가 라벨만 보여준다.
  Widget? _summaryFor(String id) {
    switch (id) {
      case 'TASKS':
        return _BigStat(value: '$_taskCount', unit: '건', note: '체크리스트');
      case 'HABITS':
        return _BigStat(
          value: '$_habitCount',
          unit: '개',
          note: widget.streak > 0 ? '연속 ${widget.streak}일 🔥' : '#habit',
        );
      case 'GOALS':
        return _BigStat(value: '$_goalCount', unit: '개', note: '#goal');
      case 'EVENTS':
        return _EventsSummary(events: _upcomingEvents);
      case 'STATS':
        return _WeekSpark(counts: _weekCounts);
      default:
        return null;
    }
  }
}

// ──────────────────────────────────────────────────────────────
// 대시보드 카드
// ──────────────────────────────────────────────────────────────
class _DashboardCard extends StatelessWidget {
  final DashboardItem item;
  final Widget? child;
  final VoidCallback onTap;

  const _DashboardCard({required this.item, required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
              child: Row(
                children: [
                  Container(width: 3, height: 13, color: kMint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.label,
                      style: monoLabel(color: kText, fontSize: 11, letterSpacing: 1.5),
                    ),
                  ),
                  Text('›', style: mono(color: kDim, fontSize: 15)),
                ],
              ),
            ),
            if (child != null) ...[
              Container(height: 1, color: kBorder),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: child,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 큰 숫자 요약 (할 일 / 습관 / 목표)
class _BigStat extends StatelessWidget {
  final String value;
  final String unit;
  final String note;
  const _BigStat({required this.value, required this.unit, required this.note});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value, style: mono(color: kMint, fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(width: 3),
        Text(unit, style: mono(color: kDim, fontSize: 12)),
        const Spacer(),
        Text(note, style: mono(color: kDim, fontSize: 11)),
      ],
    );
  }
}

// 다가오는 일정 요약
class _EventsSummary extends StatelessWidget {
  final List<Memo> events;
  const _EventsSummary({required this.events});

  String _fmt(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    final hm =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return '오늘 $hm';
    if (diff == 1) return '내일 $hm';
    return '${d.month}/${d.day} $hm';
  }

  String _title(Memo m) {
    final t = m.content.trim().split('\n').first;
    return t.isEmpty ? '(제목 없음)' : t;
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text('예정된 일정 없음', style: mono(color: kDim, fontSize: 12));
    }
    final shown = events.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 62,
                child: Text(
                  _fmt(shown[i].scheduledAt!),
                  style: mono(color: kMint, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _title(shown[i]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mono(color: kText, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
        if (events.length > shown.length) ...[
          const SizedBox(height: 8),
          Text('+${events.length - shown.length}건 더', style: mono(color: kDim, fontSize: 11)),
        ],
      ],
    );
  }
}

// 주간 기록 스파크라인
class _WeekSpark extends StatelessWidget {
  final List<int> counts; // 7개, 월→오늘
  const _WeekSpark({required this.counts});

  @override
  Widget build(BuildContext context) {
    final maxV = counts.fold<int>(1, (p, c) => c > p ? c : p);
    final total = counts.fold<int>(0, (p, c) => p + c);
    const labels = ['', '', '', '', '', '', '오늘'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 54,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < counts.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: 4 + 42 * (counts[i] / maxV),
                        decoration: BoxDecoration(
                          color: i == counts.length - 1
                              ? kMint
                              : kMint.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[i],
                        style: mono(color: kDim, fontSize: 8),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('이번 주 $total건', style: mono(color: kDim, fontSize: 11)),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 더보기 구분선 + 행
// ──────────────────────────────────────────────────────────────
class _MoreDivider extends StatelessWidget {
  const _MoreDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        children: [
          Text('더보기', style: monoLabel(color: kDim, fontSize: 10, letterSpacing: 2)),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: kBorder)),
          const SizedBox(width: 10),
          Text('≡ 드래그로 이동', style: mono(color: kDim.withValues(alpha: 0.6), fontSize: 9)),
        ],
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  final DashboardItem item;
  final VoidCallback onTap;
  const _MoreRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        child: Row(
          children: [
            Text('·', style: mono(color: kDim, fontSize: 13)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(item.label, style: mono(color: kText, fontSize: 13)),
            ),
            Text('›', style: mono(color: kDim, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
