import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/editorial.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../capture/quick_capture_input.dart';
import '../today/today_view.dart';

/// 전체 탭 — 편집형 목차: 전체 할 일(날짜 필터) / LATER / DONE.
class AllView extends ConsumerStatefulWidget {
  const AllView({super.key});

  @override
  ConsumerState<AllView> createState() => _AllViewState();
}

class _AllViewState extends ConsumerState<AllView> {
  /// 0 전체 · 1 오늘 · 2 7일 · 3 이번 달.
  int _range = 0;

  bool _inRange(Node n) {
    if (_range == 0) return true;
    final d = n.date;
    if (d == null) return false; // 날짜 없는 일은 '전체'에서만.
    final today = todayDate();
    return switch (_range) {
      1 => dateOnly(d) == today,
      2 => !dateOnly(d).isBefore(today) &&
          dateOnly(d).isBefore(today.add(const Duration(days: 7))),
      3 => d.year == today.year && d.month == today.month,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final all = ref.watch(allNodesProvider).valueOrNull ?? const [];

    final openAll = all
        .where(
            (n) => n.status == NodeStatus.open && n.type != NodeType.folder)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final open = openAll.where(_inRange).toList();
    final later = all.where((n) => n.status == NodeStatus.drawer).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final doneList = all.where((n) => n.status == NodeStatus.done).toList()
      ..sort((a, b) =>
          (b.doneAt ?? b.updatedAt).compareTo(a.doneAt ?? a.updatedAt));

    final rows = <Widget>[];

    // ── 종합 대시보드 ──────────────────────────────────────────
    final today = todayDate();
    int doneOn(DateTime day) =>
        doneList.where((n) => dateOnly(n.doneAt ?? n.updatedAt) == day).length;
    final week = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final weekCounts = [for (final d in week) doneOn(d)];
    final weekTotal = weekCounts.fold<int>(0, (a, b) => a + b);
    final maxC = weekCounts.fold<int>(1, (a, b) => b > a ? b : a);
    const wd = ['일', '월', '화', '수', '목', '금', '토'];

    // ── § 전체 할 일 + 날짜 필터(전체/오늘/7일/이번 달/기간) ──────────
    rows.add(_sectionHead(tk, '전체 할 일', '＋ 할 일',
        () => showQuickCaptureInput(context, ref)));
    rows.add(Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 4),
      child: EdTabs(
        labels: const ['전체', '오늘', '7일', '이번 달', '기간'],
        index: _range,
        onChanged: (i) => setState(() => _range = i),
      ),
    ));
    if (open.isEmpty) {
      rows.add(emptyNote(
          context, _range == 0 ? '담아둔 게 없어요' : '이 기간엔 할 일이 없어요'));
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

    // ── 종합 대시보드 (맨 아래) ──────────────────────────────
    rows.add(const SectionLabel('OVERVIEW'));
    rows.add(Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 0),
      child: Text(
          '진행 ${openAll.length} · 나중 ${later.length} · 오늘 완료 ${doneOn(today)}',
          style: AppText.body(tk.ink)),
    ));
    rows.add(Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 3, kGutter, 0),
      child: Text('이번주 완료 $weekTotal', style: AppText.meta(tk.inkSoft)),
    ));
    rows.add(Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 4 + 40 * weekCounts[i] / maxC,
                      color: weekCounts[i] > 0 ? tk.mark : tk.line,
                    ),
                    const SizedBox(height: 3),
                    Text(wd[week[i].weekday % 7],
                        style: AppText.meta(tk.inkSoft, size: 9)),
                  ],
                ),
              ),
            ),
        ],
      ),
    ));

    rows.add(const SizedBox(height: 16));

    return Container(
      color: tk.paper,
      child: ListView(padding: EdgeInsets.zero, children: rows),
    );
  }

  /// § 세리프 섹션 제목 + 우측 액션 + 하단 헤어라인.
  Widget _sectionHead(
      AppTokens tk, String title, String action, VoidCallback onAction) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 18, kGutter, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('§ ', style: AppText.hTitle(tk.mark).copyWith(fontSize: 15)),
              Text(title, style: AppText.hTitle(tk.ink).copyWith(fontSize: 18)),
              const Spacer(),
              GestureDetector(
                onTap: onAction,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 2),
                  child: Text(action, style: AppText.meta(tk.mark, size: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: tk.line),
        ],
      ),
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
