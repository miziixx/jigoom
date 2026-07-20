import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../today/node_detail_sheet.dart';
import '../today/today_view.dart';
import 'node_tile.dart';

/// 아웃라이너 뷰 — 무한 들여쓰기 트리 + 날짜 필터.
/// 필터: 전체(트리) / 오늘 / 7일 / 이번달 / 기간 직접 선택(하루~수개월).
/// 스와이프 우=완료, 좌=내일로. 타일 탭=상세(메모/폴더/날짜).
class OutlineView extends ConsumerStatefulWidget {
  const OutlineView({super.key});

  @override
  ConsumerState<OutlineView> createState() => _OutlineViewState();
}

class _OutlineViewState extends ConsumerState<OutlineView> {
  final Set<String> _expanded = {};

  /// null = 전체(트리 모드). 값이 있으면 기간 필터 모드.
  ({DateTime start, DateTime end, String label})? _range;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _filterBar(context),
        const Divider(height: 0.5),
        Expanded(child: _range == null ? _tree() : _filtered()),
      ],
    );
  }

  // ---------------------------------------------------------------- 필터바
  Widget _filterBar(BuildContext context) {
    final today = todayDate();
    Widget chip(String label, ({DateTime start, DateTime end})? r) {
      final selected =
          (_range == null && r == null) || (_range?.label == label);
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          selected: selected,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          onSelected: (_) => setState(() {
            _range = r == null
                ? null
                : (start: r.start, end: r.end, label: label);
          }),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          chip('전체', null),
          chip('오늘', (start: today, end: today.add(const Duration(days: 1)))),
          chip('7일', (start: today, end: today.add(const Duration(days: 7)))),
          chip(
              '이번달',
              (
                start: DateTime(today.year, today.month, 1),
                end: DateTime(today.year, today.month + 1, 1)
              )),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              avatar: const Icon(Icons.date_range, size: 14),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              label: Text(_range?.label.contains('~') == true
                  ? _range!.label
                  : '기간 선택',
                  style: const TextStyle(fontSize: 12)),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              onPressed: _pickRange,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: todayDate().add(const Duration(days: 730)),
      helpText: '볼 기간을 선택하세요 (하루도, 한 달도 가능)',
      cancelText: '취소',
      confirmText: '보기',
    );
    if (picked == null) return;
    final fmt = DateFormat('M/d');
    setState(() => _range = (
          start: picked.start,
          end: picked.end.add(const Duration(days: 1)),
          label: '${fmt.format(picked.start)}~${fmt.format(picked.end)}',
        ));
  }

  // ------------------------------------------------------- 기간 필터 모드
  Widget _filtered() {
    final r = _range!;
    final nodes = ref
            .watch(dateRangeNodesProvider((start: r.start, end: r.end)))
            .valueOrNull ??
        const [];
    if (nodes.isEmpty) {
      return Center(
          child: Text('이 기간엔 비어 있어요',
              style: Theme.of(context).textTheme.bodySmall));
    }

    // 날짜별 헤더로 묶어서 표시.
    final byDate = <DateTime, List<Node>>{};
    for (final n in nodes) {
      byDate.putIfAbsent(dateOnly(n.date!), () => []).add(n);
    }
    final dates = byDate.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        for (final d in dates) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 2),
            child: Text(DateFormat('M월 d일 (E)', 'ko').format(d),
                style: Theme.of(context).textTheme.bodySmall),
          ),
          for (final n in byDate[d]!) SimpleTile(node: n),
        ],
      ],
    );
  }

  // ------------------------------------------------------------ 트리 모드
  Widget _tree() {
    final roots = ref.watch(rootsProvider);
    return roots.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (nodes) {
        if (nodes.isEmpty) {
          return Center(
              child: Text('아직 아무것도 없어요',
                  style: Theme.of(context).textTheme.bodySmall));
        }
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [for (final n in nodes) ..._buildSubtree(n, 0)],
        );
      },
    );
  }

  List<Widget> _buildSubtree(Node node, int depth) {
    final children = ref.watch(childrenProvider(node.id)).valueOrNull ?? [];
    final hasChildren = children.isNotEmpty;
    final isFolder = node.type == NodeType.folder;
    final isExpanded = _expanded.contains(node.id);

    final rows = <Widget>[
      _swipeable(
        node,
        isFolder
            ? _folderTile(node, depth, children.length)
            : NodeTile(
                key: ValueKey(node.id),
                node: node,
                depth: depth,
                hasChildren: hasChildren,
                expanded: isExpanded,
                onToggleExpand: () => setState(() {
                  isExpanded
                      ? _expanded.remove(node.id)
                      : _expanded.add(node.id);
                }),
                onToggleDone: () => _toggleDone(node),
                onTap: () => showNodeDetailSheet(context, node),
              ),
      ),
    ];

    if (isExpanded) {
      for (final c in children) {
        rows.addAll(_buildSubtree(c, depth + 1));
      }
    }
    return rows;
  }

  Widget _folderTile(Node node, int depth, int childCount) {
    final theme = Theme.of(context);
    final open = _expanded.contains(node.id);
    return InkWell(
      onTap: () => setState(() {
        open ? _expanded.remove(node.id) : _expanded.add(node.id);
      }),
      onLongPress: () => showNodeDetailSheet(context, node),
      child: Padding(
        padding: EdgeInsets.only(
            left: 12.0 + depth * 20, right: 12, top: 6, bottom: 6),
        child: Row(
          children: [
            Icon(open ? Icons.folder_open_outlined : Icons.folder_outlined,
                size: 17, color: theme.textTheme.bodySmall?.color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(node.title, style: theme.textTheme.titleMedium),
            ),
            Text('$childCount', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _swipeable(Node node, Widget child) {
    final theme = Theme.of(context);
    if (node.type == NodeType.folder) return child; // 폴더는 스와이프 없음
    return Dismissible(
      key: ValueKey('dismiss_${node.id}'),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.check_circle, color: AppColors.done),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.east, color: theme.textTheme.bodySmall?.color),
      ),
      confirmDismiss: (dir) async {
        final repo = ref.read(nodeRepoProvider);
        if (dir == DismissDirection.startToEnd) {
          await repo.complete(node.id); // 우 = 완료
        } else {
          await repo.pushToTomorrow(node.id); // 좌 = 내일로
        }
        return false; // 리스트에서 실제로 제거하지 않음 (스트림이 갱신)
      },
      child: child,
    );
  }

  Future<void> _toggleDone(Node node) async {
    final repo = ref.read(nodeRepoProvider);
    if (node.status == NodeStatus.done) {
      await repo.reopen(node.id);
    } else {
      await repo.complete(node.id);
    }
  }
}
