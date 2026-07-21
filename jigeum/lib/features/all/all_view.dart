import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../today/today_view.dart';

/// 전체 탭 — 저널형 타임라인: [할 일] [나중에] [완료] 배지로 구분.
class AllView extends ConsumerWidget {
  const AllView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final all = ref.watch(allNodesProvider).valueOrNull ?? const [];

    final open = all
        .where(
            (n) => n.status == NodeStatus.open && n.type != NodeType.folder)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final later = all.where((n) => n.status == NodeStatus.drawer).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final doneList = all.where((n) => n.status == NodeStatus.done).toList()
      ..sort((a, b) =>
          (b.doneAt ?? b.updatedAt).compareTo(a.doneAt ?? a.updatedAt));

    final rows = <Widget>[];

    Widget emptyNote() => Padding(
          padding: const EdgeInsets.only(left: Journal.rowLeft, bottom: 6),
          child: Text('없어요',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
        );

    rows.add(Journal.pill(context, '할 일 · ${open.length}'));
    if (open.isEmpty) {
      rows.add(emptyNote());
    } else {
      for (var i = 0; i < open.length; i++) {
        rows.add(SimpleTile(node: open[i]));
        if (i != open.length - 1) rows.add(Journal.divider(context));
      }
    }

    rows.add(Journal.pill(context, '나중에 · ${later.length}'));
    if (later.isEmpty) {
      rows.add(emptyNote());
    } else {
      for (var i = 0; i < later.length; i++) {
        rows.add(_LaterTile(node: later[i]));
        if (i != later.length - 1) rows.add(Journal.divider(context));
      }
    }

    // 완료 모아보기: 전부, 날짜별 묶음.
    rows.add(Journal.pill(context, '완료 · ${doneList.length}'));
    final byDate = <DateTime, List<Node>>{};
    for (final n in doneList) {
      byDate.putIfAbsent(dateOnly(n.doneAt ?? n.updatedAt), () => []).add(n);
    }
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final d in dates) {
      rows.add(Padding(
        padding: const EdgeInsets.only(
            left: Journal.rowLeft, top: 8, bottom: 2),
        child: Text(DateFormat('M월 d일 (E)', 'ko').format(d),
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
      ));
      for (final n in byDate[d]!) {
        rows.add(SimpleTile(node: n, showStar: false));
      }
    }

    return Container(
      color: Journal.pageBg(context),
      child:
          Journal.card(context, child: Journal.timeline(context, rows)),
    );
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
        padding: const EdgeInsets.only(
            left: Journal.rowLeft, right: 4, top: 6, bottom: 6),
        child: Row(
          children: [
            Icon(Icons.inbox_outlined,
                size: 16, color: theme.textTheme.bodySmall?.color),
            const SizedBox(width: 11),
            Expanded(
              child: Text(node.title,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            // ↑ 오늘로 꺼내기
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(Icons.north,
                    size: 15, color: theme.textTheme.bodySmall?.color),
              ),
              onTap: () async {
                await repo.setDate(node.id, todayDate());
                final fresh = await repo.findById(node.id);
                if (fresh != null && fresh.status == NodeStatus.drawer) {
                  await repo
                      .updateNode(fresh.copyWith(status: NodeStatus.open));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
