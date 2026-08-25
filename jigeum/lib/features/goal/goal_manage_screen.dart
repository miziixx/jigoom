import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/dialogs.dart';
import '../../core/editorial.dart';
import '../../core/journal.dart';
import '../../core/reference_tokens.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../shell/app_bottom_nav.dart';

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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Masthead(
              eyebrow: 'GOALS',
              title: '목표 관리',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(child: _body(context)),
            // 하단바 — 담기 = 현재 기간에 목표 추가(해당 메뉴 항목 담기).
            AppBottomNav(onQuickAdd: _addGoal),
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
          // 상단 metric 대시보드 + 30일 점 밀도 그래프(기준 4단계·목표 관리).
          _metricDashboard(tk, goals, all),
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
              padding: const EdgeInsets.only(top: 20),
              child: emptyStateBear(context, '이 기간에 담은 목표가 없어요'),
            )
          else
            for (final g in list) _goalRow(context, tk, g, all),
        ],
      ),
    );
  }

  /// 목표 진행률(자식 할 일 완료율). 하위가 없으면 완료 여부로 0/1.
  double _ratioOf(Node goal, List<Node> all) {
    final ch = all
        .where((n) => n.parentId == goal.id && n.type == NodeType.task)
        .toList();
    final total = ch.length;
    final done = ch.where((n) => n.status == NodeStatus.done).length;
    return total == 0
        ? (goal.status == NodeStatus.done ? 1.0 : 0.0)
        : done / total;
  }

  /// 상단 metric 대시보드 — 평균 진행률 + 진행중/완료 + 30일 점 밀도 그래프.
  /// 그래프는 실제 완료 활동(doneAt)에서 파생 — 임의 난수 없음.
  Widget _metricDashboard(AppTokens tk, List<Node> goals, List<Node> all) {
    var sum = 0.0;
    var inProgress = 0;
    var doneGoals = 0;
    for (final g in goals) {
      final r = _ratioOf(g, all);
      sum += r;
      if (r >= 1.0) {
        doneGoals++;
      } else {
        inProgress++;
      }
    }
    final avg = goals.isEmpty ? 0 : (sum / goals.length * 100).round();

    // 최근 30일 일별 완료 건수(모든 노드의 doneAt 기준).
    final now = todayDate();
    final values = List<int>.filled(30, 0);
    for (final n in all) {
      final da = n.doneAt;
      if (da == null) continue;
      final idx = 29 - now.difference(dateOnly(da)).inDays;
      if (idx >= 0 && idx < 30) values[idx]++;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 0),
      padding: const EdgeInsets.fromLTRB(18, 19, 18, 15),
      decoration: BoxDecoration(
        border: Border.all(color: tk.line),
        borderRadius: BorderRadius.circular(RefRadius.screen),
        color: mixOver(tk.paper2, 0.44, tk.paper),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('평균 진행률', style: AppText.meta(tk.inkSoft, size: 8)),
                    const SizedBox(height: 7),
                    Text('$avg%',
                        style: AppText.meta(tk.ink, size: 32)
                            .copyWith(letterSpacing: -1.5, height: 1)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('진행 중 $inProgress',
                      style: AppText.meta(tk.inkSoft, size: 9)),
                  const SizedBox(height: 5),
                  Text('완료 $doneGoals',
                      style: AppText.meta(tk.inkSoft, size: 9)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 13),
          _dotHistogram(tk, values),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${now.subtract(const Duration(days: 29)).month}월 '
                  '${now.subtract(const Duration(days: 29)).day}일',
                  style: AppText.meta(tk.inkSoft, size: 8)),
              Text('활동 ${values.fold<int>(0, (a, b) => a + b)}회',
                  style: AppText.meta(tk.inkSoft, size: 8)),
            ],
          ),
        ],
      ),
    );
  }

  /// 점 밀도 그래프 — 30열, 열마다 그날 완료 수만큼 작은 점을 아래에서 쌓음.
  /// 최근 12일은 강조색(node). 두꺼운 막대 금지(기준 4단계).
  Widget _dotHistogram(AppTokens tk, List<int> values) {
    const cap = 11; // 열당 최대 점(높이 112 / (3+3)에 대응).
    return SizedBox(
      height: 112,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var k = 0;
                      k < (values[i] > cap ? cap : values[i]);
                      k++) ...[
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i >= values.length - 12
                            ? tk.mark
                            : tk.inkSoft.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                ],
              ),
            ),
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
              Expanded(
                  child: Text(title,
                      style: AppText.body(tk.ink).copyWith(fontSize: 16))),
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

    final percent = (ratio * 100).round();
    final desc = goal.note.trim();

    // 기준 HTML .goal-card — 노드 + 제목/% + 설명 + 통계 + 경로선(progress-route).
    return GestureDetector(
      onTap: () => _openGoal(goal.id),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
        padding: const EdgeInsets.symmetric(horizontal: kGutter, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // goal-node — 좌측 경로 노드(완료 시 채움).
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 4, right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: complete ? tk.mark : Colors.transparent,
                border: Border.all(color: tk.mark, width: 1.5),
              ),
            ),
            Expanded(
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
                      const SizedBox(width: 8),
                      Text('$percent%',
                          style: AppText.meta(tk.ink, size: 11)),
                      if (goal.date != null) ...[
                        const SizedBox(width: 8),
                        Text(_dday(goal.date!),
                            style: AppText.meta(tk.mark, size: 10)),
                      ],
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta(tk.inkSoft, size: 10)),
                  ],
                  const SizedBox(height: 8),
                  Text('완료 $done개 · 단계 $total개',
                      style: AppText.meta(tk.inkSoft, size: 10)),
                  const SizedBox(height: 8),
                  _progressRoute(tk, ratio.clamp(0.0, 1.0)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 기준 HTML .progress-route — 트랙 + 채움 + 진행 지점 노드.
  Widget _progressRoute(AppTokens tk, double ratio) {
    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final x = (w * ratio).clamp(0.0, w);
          return Stack(
            children: [
              Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  child: Container(height: 2, color: tk.line)),
              Positioned(
                  top: 4,
                  left: 0,
                  child: Container(height: 2, width: x, color: tk.mark)),
              Positioned(
                top: 1,
                left: (x - 4).clamp(0.0, w - 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: tk.mark),
                ),
              ),
            ],
          );
        },
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

/// 목표 상세 시트 — 기준 HTML 4-렌즈(요약/구조/여정/기록). 편집 기능 전부 유지.
class _GoalDetail extends ConsumerStatefulWidget {
  const _GoalDetail({required this.goalId});
  final String goalId;

  @override
  ConsumerState<_GoalDetail> createState() => _GoalDetailState();
}

class _GoalDetailState extends ConsumerState<_GoalDetail> {
  int _lens = 0; // 0 요약 · 1 구조 · 2 여정 · 3 기록

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final goalId = widget.goalId;
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
    final children = all
        .where((n) => n.parentId == goalId && n.type == NodeType.task)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final total = children.length;
    final doneCount = children.where((n) => n.status == NodeStatus.done).length;
    final percent = total == 0
        ? (g.status == NodeStatus.done ? 100 : 0)
        : (doneCount * 100 / total).round();
    final openChildren =
        children.where((n) => n.status != NodeStatus.done).toList();
    final currentStep = openChildren.isNotEmpty ? openChildren.first.title : null;
    final completedChildren =
        children.where((n) => n.status == NodeStatus.done).toList()
          ..sort((a, b) =>
              (a.doneAt ?? a.createdAt).compareTo(b.doneAt ?? b.createdAt));
    final journey = <_GJEvent>[
      _GJEvent(_GJKind.done, '목표 시작', dateOnly(g.createdAt)),
      for (final c in completedChildren)
        _GJEvent(_GJKind.done, c.title, dateOnly(c.doneAt ?? c.createdAt)),
      if (currentStep != null) _GJEvent(_GJKind.current, currentStep, null),
      if (g.status == NodeStatus.done)
        _GJEvent(_GJKind.done, '목표 완료',
            g.doneAt != null ? dateOnly(g.doneAt!) : null)
      else
        _GJEvent(_GJKind.upcoming, '목표 완료', g.date),
    ];

    Widget panel;
    switch (_lens) {
      case 1:
        panel = _structure(tk, children);
        break;
      case 2:
        panel = _goalJourney(tk, journey);
        break;
      case 3:
        panel = _record(tk, completedChildren);
        break;
      default:
        panel = _summary(tk, g, percent, doneCount, total, currentStep);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () async {
            final v = await showInputDialog(context,
                title: '목표 이름',
                fieldLabel: '목표',
                initial: g.title,
                saveLabel: '저장');
            if (v != null && v.trim().isNotEmpty) {
              await ref.read(nodeRepoProvider).setTitle(goalId, v.trim());
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Text(g.title, style: AppText.serif(tk.ink, size: 20)),
        ),
        const SizedBox(height: 12),
        _lensTabs(tk),
        const SizedBox(height: 14),
        panel,
      ],
    );
  }

  Widget _lensTabs(AppTokens tk) {
    const labels = ['요약', '구조', '여정', '기록'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          border: Border.all(color: tk.line),
          borderRadius: BorderRadius.circular(999)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _lens = i),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 32,
                alignment: Alignment.center,
                decoration: _lens == i
                    ? BoxDecoration(
                        color: tk.paper,
                        borderRadius: BorderRadius.circular(999))
                    : null,
                child: Text(labels[i],
                    style: AppText.body(_lens == i ? tk.ink : tk.inkSoft)
                        .copyWith(fontSize: 11)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _summary(AppTokens tk, Node g, int percent, int doneCount, int total,
      String? currentStep) {
    final horizon = g.goalHorizon ?? 'custom';
    final goalId = widget.goalId;
    final repo = ref.read(nodeRepoProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
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
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(h.label,
                      style: AppText.meta(
                          horizon == h.key ? tk.paper : tk.inkSoft,
                          size: 10)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
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
          child: Row(children: [
            Text('마감', style: AppText.meta(tk.inkSoft, size: 11)),
            const SizedBox(width: 10),
            Text(
              g.date == null
                  ? '없음 (탭해서 지정)'
                  : DateFormat('yyyy.MM.dd (E)', 'ko').format(g.date!),
              style: AppText.body(tk.ink).copyWith(fontSize: 13),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$percent%', style: AppText.serif(tk.ink, size: 26)),
            const SizedBox(width: 8),
            Text('$doneCount / $total 단계',
                style: AppText.meta(tk.inkSoft, size: 11)),
          ],
        ),
        if (currentStep != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('현재 단계 · $currentStep',
                style: AppText.meta(tk.inkSoft, size: 11)),
          ),
        const SizedBox(height: 16),
        Row(children: [
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
        ]),
      ],
    );
  }

  Widget _structure(AppTokens tk, List<Node> children) {
    final goalId = widget.goalId;
    final repo = ref.read(nodeRepoProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        GestureDetector(
          onTap: () async {
            final v = await showInputDialog(context,
                title: '하위 할 일',
                subtitle: '목표를 이루기 위한 작은 한 걸음.',
                fieldLabel: '할 일',
                saveLabel: '추가');
            if (v != null && v.trim().isNotEmpty) {
              await repo.create(
                  parentId: goalId,
                  type: NodeType.task,
                  title: v.trim(),
                  important: true);
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('＋ 하위 할 일', style: AppText.meta(tk.ink, size: 11)),
          ),
        ),
      ],
    );
  }

  Widget _record(AppTokens tk, List<Node> completed) {
    if (completed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child:
            Text('완료한 단계가 아직 없어요.', style: AppText.meta(tk.inkSoft, size: 11)),
      );
    }
    final df = DateFormat('M.d');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in completed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(c.doneAt != null ? df.format(c.doneAt!) : '',
                      style: AppText.meta(tk.inkSoft, size: 9)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(c.title,
                      style: AppText.body(tk.ink).copyWith(fontSize: 12)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 목표 여정 노드 성격 — 완료 / 현재 단계 / 예정.
enum _GJKind { done, current, upcoming }

class _GJEvent {
  const _GJEvent(this.kind, this.label, this.date);
  final _GJKind kind;
  final String label;
  final DateTime? date; // 예정이면 null 가능
}

/// 목표 여정 타임라인 — 얇은 세로선 + 원형 노드 + 날짜/라벨(습관 여정과 동일 언어).
Widget _goalJourney(AppTokens tk, List<_GJEvent> events) {
  final df = DateFormat('yyyy.M.d');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < events.length; i++)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 16,
                child: Column(
                  children: [
                    const SizedBox(height: 3),
                    _gjNode(tk, events[i].kind),
                    if (i != events.length - 1)
                      Expanded(child: Container(width: 1, color: tk.line)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(events[i].date != null ? df.format(events[i].date!) : '예정',
                          style: AppText.meta(tk.inkSoft, size: 9)),
                      const SizedBox(height: 1),
                      Text(events[i].label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(events[i].kind == _GJKind.upcoming
                                  ? tk.inkSoft
                                  : tk.ink)
                              .copyWith(
                                  fontSize: 12,
                                  fontWeight: events[i].kind == _GJKind.current
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

Widget _gjNode(AppTokens tk, _GJKind kind) {
  switch (kind) {
    case _GJKind.current:
      return Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tk.mark,
          border: Border.all(color: tk.mark.withValues(alpha: 0.28), width: 3),
        ),
      );
    case _GJKind.upcoming:
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: tk.line, width: 1.4),
        ),
      );
    case _GJKind.done:
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: tk.ink),
      );
  }
}
