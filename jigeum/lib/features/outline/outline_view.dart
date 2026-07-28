import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../today/node_detail_sheet.dart';

/// 아웃라이너 — 편집형 목차. 폴더/목표 = 섹션 라벨 + 규칙선, 할 일 = 글리프 줄.
/// 카드·레일 없음. 기간 필터는 대문자 모노 칩.
class OutlineView extends ConsumerStatefulWidget {
  const OutlineView({super.key});

  @override
  ConsumerState<OutlineView> createState() => _OutlineViewState();
}

class _OutlineViewState extends ConsumerState<OutlineView> {
  final Set<String> _collapsed = {}; // 기본 펼침, 접은 것만 기록

  /// null = 전체(트리 모드). 값이 있으면 기간 필터 모드.
  ({DateTime start, DateTime end, String label})? _range;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Container(
      color: tk.paper,
      child: Column(
        children: [
          _filterBar(context),
          Expanded(child: _range == null ? _tree() : _filtered()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 필터바
  Widget _filterBar(BuildContext context) {
    final today = todayDate();
    Widget chip(String label, ({DateTime start, DateTime end})? r) {
      final selected =
          (_range == null && r == null) || (_range?.label == label);
      return _MonoChip(
        label: label,
        selected: selected,
        onTap: () => setState(() {
          _range =
              r == null ? null : (start: r.start, end: r.end, label: label);
        }),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 6),
      child: Row(
        children: [
          chip('all', null),
          chip('today',
              (start: today, end: today.add(const Duration(days: 1)))),
          chip('7d', (start: today, end: today.add(const Duration(days: 7)))),
          chip(
              'month',
              (
                start: DateTime(today.year, today.month, 1),
                end: DateTime(today.year, today.month + 1, 1)
              )),
          _MonoChip(
            label: _range?.label.contains('~') == true
                ? _range!.label
                : 'range',
            selected: _range?.label.contains('~') == true,
            onTap: _pickRange,
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
    final tk = t(context);
    final r = _range!;
    final nodes = ref
            .watch(dateRangeNodesProvider((start: r.start, end: r.end)))
            .valueOrNull ??
        const [];
    if (nodes.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: emptyNote(context, '이 기간엔 담긴 게 없어요'),
      );
    }

    final byDate = <DateTime, List<Node>>{};
    for (final n in nodes) {
      byDate.putIfAbsent(dateOnly(n.date!), () => []).add(n);
    }
    final dates = byDate.keys.toList()..sort();

    final rows = <Widget>[];
    for (final d in dates) {
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 20, kGutter, 4),
        child: Text(DateFormat('M월 d일 (E)', 'ko').format(d),
            style: AppText.meta(tk.inkSoft)),
      ));
      for (final n in byDate[d]!) {
        rows.add(_TaskRow(node: n, showDeadline: false));
      }
    }
    rows.add(const SizedBox(height: 16));
    return ListView(padding: EdgeInsets.zero, children: rows);
  }

  // ------------------------------------------------------------ 트리 모드
  Widget _tree() {
    final roots = ref.watch(rootsProvider).valueOrNull ?? const [];
    if (roots.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: emptyNote(context, '아직 아무것도 없어요'),
      );
    }

    final sections = <Node>[];
    final loose = <Node>[];
    for (final n in roots) {
      if (n.type == NodeType.folder || n.type == NodeType.goal) {
        sections.add(n);
      } else {
        loose.add(n);
      }
    }

    final rows = <Widget>[];

    void addTasks(List<Node> list, int depth) {
      for (final n in list) {
        rows.add(_swipeable(n, _TaskRow(node: n, depth: depth)));
        final children =
            ref.watch(childrenProvider(n.id)).valueOrNull ?? const [];
        if (children.isNotEmpty && !_collapsed.contains(n.id)) {
          addTasks(children, depth + 1);
        }
      }
    }

    if (loose.isNotEmpty) {
      rows.add(SectionLabel('TASKS', count: loose.length));
      addTasks(loose, 0);
    }

    for (final s in sections) {
      final children =
          ref.watch(childrenProvider(s.id)).valueOrNull ?? const [];
      final open = !_collapsed.contains(s.id);
      rows.add(SectionLabel(
        s.type == NodeType.goal ? '★ ${s.title}' : s.title,
        count: children.length,
        onTap: () => setState(() {
          open ? _collapsed.add(s.id) : _collapsed.remove(s.id);
        }),
        onLongPress: () => showNodeDetailSheet(context, s),
        trailing: Text(open ? '−' : '+',
            style: AppText.meta(t(context).inkSoft, size: 13)),
      ));
      if (open) {
        if (children.isEmpty) {
          rows.add(emptyNote(context, '비어 있어요'));
        } else {
          addTasks(children, 0);
        }
      }
    }

    rows.add(const SizedBox(height: 16));
    return ListView(padding: EdgeInsets.zero, children: rows);
  }

  Widget _swipeable(Node node, Widget child) {
    final tk = t(context);
    Widget bg(Alignment a, String g) => Container(
          alignment: a,
          color: tk.paper2,
          padding: const EdgeInsets.symmetric(horizontal: kGutter),
          child: Text(g, style: AppText.glyph(tk.inkSoft, size: 16)),
        );
    return Dismissible(
      key: ValueKey('dismiss_${node.id}'),
      background: bg(Alignment.centerLeft, '■'),
      secondaryBackground: bg(Alignment.centerRight, '→'),
      confirmDismiss: (dir) async {
        final repo = ref.read(nodeRepoProvider);
        if (dir == DismissDirection.startToEnd) {
          await repo.complete(node.id); // 우 = 완료
        } else {
          await repo.pushToTomorrow(node.id); // 좌 = 내일로
        }
        return false;
      },
      child: child,
    );
  }
}

/// 대문자 모노 필터 칩 (각진 1px 규칙선, 선택 = 잉크 반전).
class _MonoChip extends StatelessWidget {
  const _MonoChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? tk.ink : Colors.transparent,
            border: Border.all(color: selected ? tk.ink : tk.line, width: 1),
          ),
          child:
              Text(label, style: AppText.chip(selected ? tk.paper : tk.inkSoft)),
        ),
      ),
    );
  }
}

/// 편집형 할 일 줄 (아웃라인): 글리프 체크 + 제목 + 마감/하위진행 메타 + 우선순위.
class _TaskRow extends ConsumerWidget {
  const _TaskRow(
      {required this.node, this.depth = 0, this.showDeadline = true});

  final Node node;
  final int depth;
  final bool showDeadline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final repo = ref.read(nodeRepoProvider);
    final done = node.status == NodeStatus.done;
    final children =
        ref.watch(childrenProvider(node.id)).valueOrNull ?? const [];
    final doneCount =
        children.where((c) => c.status == NodeStatus.done).length;
    final pri = done
        ? null
        : priorityLabel(context,
            urgent: node.urgent, important: node.important);

    return InkWell(
      onTap: () => showNodeDetailSheet(context, node),
      child: Padding(
        padding: EdgeInsets.fromLTRB(kGutter + depth * 18, 7, kGutter, 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlyphCheck(
              done: done,
              onTap: () =>
                  done ? repo.reopen(node.id) : repo.complete(node.id),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.title,
                      style: AppText.body(done ? tk.inkSoft : tk.ink).copyWith(
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          decorationColor: tk.inkSoft),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (children.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('$doneCount/${children.length}',
                          style: AppText.meta(tk.inkSoft)),
                    ),
                ],
              ),
            ),
            if (showDeadline && node.date != null && !done) ...[
              const SizedBox(width: 10),
              Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: deadlineLabel(context, node.date!)),
            ],
            if (pri != null) ...[
              const SizedBox(width: 10),
              Padding(padding: const EdgeInsets.only(top: 2), child: pri),
            ],
          ],
        ),
      ),
    );
  }
}
