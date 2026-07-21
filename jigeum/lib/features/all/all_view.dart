import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../today/today_view.dart';

/// 전체 탭 — 편집형 목차: TO-DO / LATER / DONE 을 라벨 + 규칙선으로 구분.
class AllView extends ConsumerWidget {
  const AllView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
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

    rows.add(SectionLabel('TO-DO', count: open.length));
    if (open.isEmpty) {
      rows.add(emptyNote(context, '담아둔 게 없어요'));
    } else {
      for (final n in open) {
        rows.add(SimpleTile(node: n));
      }
    }

    rows.add(SectionLabel('LATER', count: later.length));
    if (later.isEmpty) {
      rows.add(emptyNote(context, '나중으로 미뤄둔 게 없어요'));
    } else {
      for (final n in later) {
        rows.add(_LaterTile(node: n));
      }
    }

    rows.add(SectionLabel('DONE', count: doneList.length));
    if (doneList.isEmpty) {
      rows.add(emptyNote(context, '아직 완료한 일이 없어요'));
    } else {
      final byDate = <DateTime, List<Node>>{};
      for (final n in doneList) {
        byDate
            .putIfAbsent(dateOnly(n.doneAt ?? n.updatedAt), () => [])
            .add(n);
      }
      final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final d in dates) {
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 2),
          child: Text(DateFormat('M월 d일 (E)', 'ko').format(d),
              style: AppText.meta(tk.inkSoft)),
        ));
        for (final n in byDate[d]!) {
          rows.add(SimpleTile(node: n, showStar: false));
        }
      }
    }

    rows.add(const SizedBox(height: 16));

    return Container(
      color: tk.paper,
      child: ListView(padding: EdgeInsets.zero, children: rows),
    );
  }
}

/// "나중에" 항목: 제목 + ↑(오늘로 꺼내기). 좌 스와이프 삭제.
class _LaterTile extends ConsumerWidget {
  const _LaterTile({required this.node});
  final Node node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final repo = ref.read(nodeRepoProvider);

    return Dismissible(
      key: ValueKey('later_${node.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: tk.paper2,
        padding: const EdgeInsets.symmetric(horizontal: kGutter),
        child: Text('×', style: AppText.glyph(tk.inkSoft, size: 16)),
      ),
      confirmDismiss: (_) async {
        await repo.deleteNode(node.id);
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 7, kGutter, 7),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('·', style: AppText.glyph(tk.inkSoft, size: 16)),
            ),
            Expanded(
              child: Text(node.title,
                  style: AppText.body(tk.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                await repo.setDate(node.id, todayDate());
                final fresh = await repo.findById(node.id);
                if (fresh != null && fresh.status == NodeStatus.drawer) {
                  await repo
                      .updateNode(fresh.copyWith(status: NodeStatus.open));
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('↑ today', style: AppText.nav(tk.inkSoft)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
