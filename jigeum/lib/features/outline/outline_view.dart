import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import 'node_tile.dart';

/// 아웃라이너 뷰 — 무한 들여쓰기 트리. 기본 1단계만 펼침.
/// 스와이프 우=완료, 좌=내일로.
class OutlineView extends ConsumerStatefulWidget {
  const OutlineView({super.key});

  @override
  ConsumerState<OutlineView> createState() => _OutlineViewState();
}

class _OutlineViewState extends ConsumerState<OutlineView> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final roots = ref.watch(rootsProvider);
    return roots.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (nodes) {
        if (nodes.isEmpty) {
          return _empty(context, '아직 아무것도 없어요');
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
    final isExpanded = _expanded.contains(node.id);

    final rows = <Widget>[
      _swipeable(
        node,
        NodeTile(
          key: ValueKey(node.id),
          node: node,
          depth: depth,
          hasChildren: hasChildren,
          expanded: isExpanded,
          onToggleExpand: () => setState(() {
            isExpanded ? _expanded.remove(node.id) : _expanded.add(node.id);
          }),
          onToggleDone: () => _toggleDone(node),
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

  Widget _swipeable(Node node, Widget child) {
    final theme = Theme.of(context);
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

  Widget _empty(BuildContext context, String msg) {
    return Center(
      child: Text(msg,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color)),
    );
  }
}
