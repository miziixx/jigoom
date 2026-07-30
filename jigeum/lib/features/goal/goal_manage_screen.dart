import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/dialogs.dart';
import '../../core/editorial.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../shell/app_drawer.dart';

/// 목표 관리 — 기간별(일주일/1개월/1년/직접) 목표를 담고 진행률로 추적한다.
/// 목표는 노드(type=goal)이며, 하위 할 일(자식 task)의 완료율이 진행률이다.
class GoalManageScreen extends ConsumerStatefulWidget {
  const GoalManageScreen({super.key});

  @override
  ConsumerState<GoalManageScreen> createState() => _GoalManageScreenState();
}

/// 기간 정의 — key(저장값) · 라벨 · 기본 마감일 계산.
const _horizons = <({String key, String label})>[
  (key: 'week', label: '일주일'),
  (key: 'month', label: '1개월'),
  (key: 'year', label: '1년'),
  (key: 'custom', label: '직접'),
];

DateTime? _defaultDeadline(String horizon) {
  final t = todayDate();
  return switch (horizon) {
    'week' => t.add(const Duration(days: 7)),
    'month' => DateTime(t.year, t.month + 1, t.day),
    'year' => DateTime(t.year + 1, t.month, t.day),
    _ => null, // custom: 사용자가 직접 고름
  };
}

class _GoalManageScreenState extends ConsumerState<GoalManageScreen> {
  int _tab = 0;

  String get _horizon => _horizons[_tab].key;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Masthead(
              eyebrow: 'GOALS',
              title: '목표 관리',
              onBack: () => Navigator.of(context).pop(),
              showMenu: true,
            ),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final tk = t(context);
    final goals = ref.watch(goalsProvider).valueOrNull ?? const <Node>[];
    final all = ref.watch(allNodesProvider).valueOrNull ?? const <Node>[];
    final list = goals
        .where((g) => (g.goalHorizon ?? 'custom') == _horizon)
        .toList();

    return Container(
      color: tk.paper,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          // 기간 탭.
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 2),
            child: EdTabs(
              labels: [for (final h in _horizons) h.label],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          _sectionHead(tk, '${_horizons[_tab].label} 목표', () => _addGoal()),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: emptyNote(context, '이 기간에 담은 목표가 없어요'),
            )
          else
            for (final g in list) _goalRow(context, tk, g, all),
        ],
      ),
    );
  }

  Widget _sectionHead(AppTokens tk, String title, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 18, kGutter, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('§ ', style: AppText.serif(tk.mark, size: 15)),
              Expanded(child: Text(title, style: AppText.serif(tk.ink, size: 16))),
              GestureDetector(
                onTap: onAdd,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 2),
                  child: Text('＋ 목표', style: AppText.meta(tk.mark, size: 11)),
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

  Widget _goalRow(
      BuildContext context, AppTokens tk, Node goal, List<Node> all) {
    final children = all
        .where((n) => n.parentId == goal.id && n.type == NodeType.task)
        .toList();
    final total = children.length;
    final done = children.where((n) => n.status == NodeStatus.done).length;
    final ratio = total == 0
        ? (goal.status == NodeStatus.done ? 1.0 : 0.0)
        : done / total;
    final complete = ratio >= 1.0 && (total > 0 || goal.status == NodeStatus.done);

    return GestureDetector(
      onTap: () => _openGoal(goal.id),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
        padding: const EdgeInsets.symmetric(horizontal: kGutter, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.serif(
                        complete ? tk.inkSoft : tk.ink,
                        size: 15,
                        height: 1.25),
                  ),
                ),
                if (goal.date != null) ...[
                  const SizedBox(width: 8),
                  Text(_dday(goal.date!),
                      style: AppText.meta(tk.mark, size: 10)),
                ],
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(child: _bar(tk, ratio)),
                const SizedBox(width: 10),
                Text(total == 0 ? (complete ? '완료' : '—') : '$done / $total',
                    style: AppText.meta(tk.inkSoft, size: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(AppTokens tk, double ratio) {
    return SizedBox(
      height: 5,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            Container(color: tk.line),
            FractionallySizedBox(
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(color: tk.ink),
            ),
          ],
        ),
      ),
    );
  }

  String _dday(DateTime date) {
    final diff = dateOnly(date).difference(todayDate()).inDays;
    if (diff == 0) return 'D-DAY';
    return diff > 0 ? 'D-$diff' : 'D+${-diff}';
  }

  Future<void> _addGoal() async {
    final title = await showInputDialog(
      context,
      title: '새 목표',
      subtitle: '${_horizons[_tab].label} 안에 이루고 싶은 것을 적어주세요.',
      fieldLabel: '목표',
      hint: '예: 앱 첫 출시하기',
      saveLabel: '담기',
    );
    if (title == null || title.trim().isEmpty) return;
    await ref.read(nodeRepoProvider).createGoal(
          title: title.trim(),
          horizon: _horizon,
          date: _defaultDeadline(_horizon),
        );
  }

  void _openGoal(String goalId) {
    showEditorialSheet(
      context,
      builder: (ctx) => _GoalDetail(goalId: goalId),
    );
  }
}

/// 목표 상세 시트 — 제목·마감일·기간 변경 + 하위 할 일 관리 + 삭제.
class _GoalDetail extends ConsumerWidget {
  const _GoalDetail({required this.goalId});
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final all = ref.watch(allNodesProvider).valueOrNull ?? const <Node>[];
    Node? goal;
    for (final n in all) {
      if (n.id == goalId) {
        goal = n;
        break;
      }
    }
    if (goal == null) return const SizedBox.shrink();
    final g = goal;
    final repo = ref.read(nodeRepoProvider);
    final children = all
        .where((n) => n.parentId == goalId && n.type == NodeType.task)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final horizon = g.goalHorizon ?? 'custom';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 제목 (탭하면 이름 수정).
        GestureDetector(
          onTap: () async {
            final v = await showInputDialog(
              context,
              title: '목표 이름',
              fieldLabel: '목표',
              initial: g.title,
              saveLabel: '저장',
            );
            if (v != null && v.trim().isNotEmpty) {
              await repo.setTitle(goalId, v.trim());
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Text(g.title, style: AppText.serif(tk.ink, size: 20)),
        ),
        const SizedBox(height: 10),
        // 기간 세그먼트.
        Row(
          children: [
            for (final h in _horizons)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => repo.setGoalHorizon(goalId, h.key),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: horizon == h.key ? tk.ink : tk.line),
                      color: horizon == h.key ? tk.ink : Colors.transparent,
                    ),
                    child: Text(h.label,
                        style: AppText.meta(
                            horizon == h.key ? tk.paper : tk.inkSoft,
                            size: 10)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // 마감일 (탭하면 날짜 선택).
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: g.date ?? todayDate(),
              firstDate: DateTime(todayDate().year - 1),
              lastDate: DateTime(todayDate().year + 5),
            );
            if (picked != null) await repo.setDate(goalId, picked);
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Text('마감', style: AppText.meta(tk.inkSoft, size: 11)),
              const SizedBox(width: 10),
              Text(
                g.date == null
                    ? '없음 (탭해서 지정)'
                    : DateFormat('yyyy.MM.dd (E)', 'ko').format(g.date!),
                style: AppText.body(tk.ink).copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: tk.ink),
        // 하위 할 일.
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text('하위 할 일',
              style: AppText.meta(tk.inkSoft, size: 10)
                  .copyWith(letterSpacing: 1)),
        ),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('아직 없어요. 아래에서 작은 할 일로 쪼개보세요.',
                style: AppText.meta(tk.inkSoft, size: 11)),
          )
        else
          for (final c in children)
            EdTaskRow(
              title: c.title,
              done: c.status == NodeStatus.done,
              onToggle: () => c.status == NodeStatus.done
                  ? repo.reopen(c.id)
                  : repo.complete(c.id),
            ),
        // 하위 할 일 추가.
        GestureDetector(
          onTap: () async {
            final v = await showInputDialog(
              context,
              title: '하위 할 일',
              subtitle: '목표를 이루기 위한 작은 한 걸음.',
              fieldLabel: '할 일',
              saveLabel: '추가',
            );
            if (v != null && v.trim().isNotEmpty) {
              await repo.create(
                parentId: goalId,
                type: NodeType.task,
                title: v.trim(),
                important: true,
              );
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('＋ 하위 할 일',
                style: AppText.meta(tk.ink, size: 11)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: EdButton(
                label: g.status == NodeStatus.done ? '진행중으로' : '목표 완료',
                filled: g.status != NodeStatus.done,
                onTap: () async {
                  g.status == NodeStatus.done
                      ? await repo.reopen(goalId)
                      : await repo.complete(goalId);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
            const SizedBox(width: 10),
            EdButton(
              label: '삭제',
              danger: true,
              onTap: () async {
                await repo.deleteNode(goalId);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ],
    );
  }
}
