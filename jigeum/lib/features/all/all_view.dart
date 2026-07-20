import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../today/today_view.dart';

/// 전체 탭 — 모든 항목을 세 묶음으로만: 할 일 / 나중에 / 완료.
/// 세분화 없음. "나중에" 항목은 꺼내기(↑)로 오늘로 이동.
class AllView extends ConsumerWidget {
  const AllView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final all = ref.watch(allNodesProvider).valueOrNull ?? const [];

    final open = all
        .where((n) =>
            n.status == NodeStatus.open && n.type != NodeType.folder)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final later =
        all.where((n) => n.status == NodeStatus.drawer).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final doneList =
        all.where((n) => n.status == NodeStatus.done).toList()
          ..sort((a, b) => (b.doneAt ?? b.updatedAt)
              .compareTo(a.doneAt ?? a.updatedAt));

    Widget header(String t) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text(t, style: theme.textTheme.bodySmall),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        header('할 일 · ${open.length}'),
        if (open.isEmpty)
          Text('없어요', style: theme.textTheme.bodySmall)
        else
          for (final n in open) SimpleTile(node: n),

        header('나중에 · ${later.length}'),
        if (later.isEmpty)
          Text('없어요', style: theme.textTheme.bodySmall)
        else
          for (final n in later) _LaterTile(node: n),

        // 완료 모아보기: 전부, 날짜별 묶음.
        header('완료 · ${doneList.length}'),
        ..._doneGrouped(context, doneList),
      ],
    );
  }

  List<Widget> _doneGrouped(BuildContext context, List<Node> doneList) {
    final theme = Theme.of(context);
    final byDate = <DateTime, List<Node>>{};
    for (final n in doneList) {
      final d = dateOnly(n.doneAt ?? n.updatedAt);
      byDate.putIfAbsent(d, () => []).add(n);
    }
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return [
      for (final d in dates) ...[
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 2),
          child: Text(DateFormat('M월 d일 (E)', 'ko').format(d),
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
        ),
        for (final n in byDate[d]!) SimpleTile(node: n, showStar: false),
      ],
    ];
  }
}

/// "나중에" 항목: 제목 + ↑(오늘로 꺼내기) + 스와이프 좌 삭제.
class _LaterTile extends ConsumerWidget {
  const _LaterTile({required this.node});
  final Node node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(nodeRepoProvider);

    return Dismissible(
      key: ValueKey('later_${node.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete_outline,
            color: theme.textTheme.bodySmall?.color),
      ),
      confirmDismiss: (_) async {
        await repo.deleteNode(node.id);
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(Icons.inbox_outlined,
                size: 18, color: theme.textTheme.bodySmall?.color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(node.title,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            // ↑ 오늘로 꺼내기 (compact)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(Icons.north,
                    size: 16, color: theme.textTheme.bodySmall?.color),
              ),
              onTap: () async {
                await repo.setDate(node.id, todayDate());
                await repo.setMatrix(node.id, urgent: node.urgent);
                // 서랍 → open 복귀는 날짜 부여로 충분: 상태 직접 갱신
                final fresh = await repo.findById(node.id);
                if (fresh != null && fresh.status == NodeStatus.drawer) {
                  await repo.updateNode(
                      fresh.copyWith(status: NodeStatus.open));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
