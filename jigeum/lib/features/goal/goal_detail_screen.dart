import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/dialogs.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import 'goal_dashboard.dart';
import 'goal_manage_screen.dart';

/// 목표 상세 대시보드.
///
/// 정보 구조·레이아웃은 레퍼런스(v18 goal-detail)를 따르되, 스타일은 이 앱의
/// 공통 토큰·컴포넌트(Masthead · AppText · AppTokens · journal)만 사용한다.
/// 새 색/폰트/간격 체계를 만들지 않는다 → 테마가 자동 적용된다.
///
/// "단계" = 목표의 하위 할 일(자식 task). 목표 관리 목록의 진행률과 항상 일치한다.
/// 목표 이름/기간/마감/완료·삭제 같은 메타 편집은 기존 목표 편집 시트를 그대로
/// 재사용한다(헤더 "편집").
///
/// Navigator.push 로 열리므로 뒤로가기(←)는 진입했던 화면으로 돌아간다.
void openGoalDashboard(BuildContext context, Node goal) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: goal.id)),
  );
}

class GoalDetailScreen extends ConsumerStatefulWidget {
  const GoalDetailScreen({super.key, required this.goalId});
  final String goalId;

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  int _tab = 0; // 0 분석 · 1 단계 · 2 메모 · 3 기록
  GoalDashboardData? _data;
  final _noteCtrl = TextEditingController();
  bool _noteDirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(goalDashboardRepoProvider);
    final goal = await repo.nodes.findById(widget.goalId);
    if (goal == null) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    final data = await repo.load(goal);
    if (!mounted) return;
    setState(() {
      _data = data;
      if (!_noteDirty) _noteCtrl.text = data.note;
    });
  }

  GoalDashboardRepository get _repo => ref.read(goalDashboardRepoProvider);

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final data = _data;
    return Scaffold(
      backgroundColor: tk.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Masthead(
              eyebrow: 'GOAL DASHBOARD',
              title: data?.title ?? '목표',
              onBack: () => Navigator.of(context).pop(),
              actions: [
                GestureDetector(
                  onTap: () async {
                    await showGoalMetaSheet(context, widget.goalId);
                    await _load();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, top: 8, bottom: 8),
                    child: Text('편집', style: AppText.meta(tk.inkSoft, size: 11)),
                  ),
                ),
              ],
            ),
            Expanded(
              child: data == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding:
                          const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 32),
                      children: [
                        _overview(tk, data),
                        _statGrid(tk, data),
                        const SizedBox(height: 20),
                        EdTabsInline(
                          labels: const ['분석', '단계', '메모', '기록'],
                          index: _tab,
                          onChanged: (i) => setState(() => _tab = i),
                        ),
                        const SizedBox(height: 4),
                        _panel(tk, data),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 요약

  Widget _overview(AppTokens tk, GoalDashboardData d) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 16),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OVERALL PROGRESS',
                        style: AppText.meta(tk.mark, size: 10)
                            .copyWith(letterSpacing: 1.4)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('${d.progress}',
                            style:
                                AppText.serif(tk.ink, size: 46, height: 0.9)),
                        Text(' %', style: AppText.meta(tk.inkSoft, size: 16)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(d.ddayLabel, style: AppText.meta(tk.mark, size: 12)),
                  const SizedBox(height: 6),
                  Text(d.deadlineLabel,
                      style: AppText.meta(tk.inkSoft, size: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _progressBar(tk, d.progress / 100),
        ],
      ),
    );
  }

  Widget _progressBar(AppTokens tk, double f) => SizedBox(
        height: 6,
        child: Stack(
          children: [
            Container(color: tk.paper2),
            FractionallySizedBox(
              widthFactor: f.clamp(0.0, 1.0),
              child: Container(color: tk.mark),
            ),
          ],
        ),
      );

  Widget _statGrid(AppTokens tk, GoalDashboardData d) {
    Widget cell(String label, String value,
        {bool first = false, bool last = false}) {
      return Expanded(
        child: Container(
          padding:
              EdgeInsets.fromLTRB(first ? 0 : 10, 13, last ? 0 : 10, 13),
          decoration: BoxDecoration(
            border: Border(
              right: last ? BorderSide.none : BorderSide(color: tk.line),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.meta(tk.inkSoft, size: 9)),
              const SizedBox(height: 7),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.serif(tk.ink, size: 17)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cell('완료 단계', '${d.completedSteps} / ${d.totalSteps}', first: true),
          cell('이번 주 활동', '${d.weekActivityCount}회'),
          cell('예상 완료', d.forecastLabel, last: true),
        ],
      ),
    );
  }

  Widget _panel(AppTokens tk, GoalDashboardData d) {
    switch (_tab) {
      case 1:
        return _stepsPanel(tk, d);
      case 2:
        return _notePanel(tk, d);
      case 3:
        return _historyPanel(tk, d);
      default:
        return _analysisPanel(tk, d);
    }
  }

  // ---------------------------------------------------------------- 분석

  Widget _analysisPanel(AppTokens tk, GoalDashboardData d) {
    Widget insightCell(String kicker, GoalInsight ins,
        {bool right = false, bool bottom = false}) {
      return Container(
        constraints: const BoxConstraints(minHeight: 116),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          border: Border(
            right: right ? BorderSide.none : BorderSide(color: tk.line),
            bottom: bottom ? BorderSide.none : BorderSide(color: tk.line),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kicker,
                style: AppText.meta(tk.mark, size: 8)
                    .copyWith(letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Text(ins.title,
                style: AppText.serif(tk.ink, size: 15, height: 1.3)),
            const SizedBox(height: 6),
            Text(ins.text,
                style:
                    AppText.meta(tk.inkSoft, size: 9).copyWith(height: 1.55)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Container(
          decoration:
              BoxDecoration(border: Border(top: BorderSide(color: tk.line))),
          child: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: insightCell('PACE', d.pace)),
                    Expanded(
                        child: insightCell('CONSISTENCY', d.consistency,
                            right: true)),
                  ],
                ),
              ),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                        child: insightCell('RISK', d.risk, bottom: true)),
                    Expanded(
                        child: insightCell('FOCUS', d.focus,
                            right: true, bottom: true)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.fromLTRB(16, 15, 0, 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: tk.mark, width: 2),
              bottom: BorderSide(color: tk.line),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NEXT ACTION',
                  style: AppText.meta(tk.mark, size: 8)
                      .copyWith(letterSpacing: 1.4)),
              const SizedBox(height: 9),
              Text(d.nextAction,
                  style: AppText.body(tk.ink)
                      .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text('10분만 시작해도 오늘 진행 기록에 반영돼요.',
                  style: AppText.meta(tk.inkSoft, size: 9)
                      .copyWith(height: 1.5)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  await _repo.startFocus(widget.goalId, d.nextAction);
                  _toast('집중 기록을 시작했어요');
                  await _load();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  color: tk.ink,
                  child: Text('지금 시작',
                      style: AppText.body(tk.paper).copyWith(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Row(
            children: [
              Text('§ ', style: AppText.serif(tk.mark, size: 15)),
              Text('이번 주 활동', style: AppText.serif(tk.ink, size: 16)),
              const Spacer(),
              Text('7 DAYS', style: AppText.meta(tk.inkSoft, size: 10)),
            ],
          ),
        ),
        _activityChart(tk, d.activity),
      ],
    );
  }

  Widget _activityChart(AppTokens tk, List<int> values) {
    final maxV = values.fold<int>(1, (m, v) => v > m ? v : m);
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return Container(
      height: 140,
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 8 + (values[i] / maxV) * 86,
                      decoration: BoxDecoration(
                        color: values[i] == 0
                            ? tk.paper2
                            : tk.mark.withValues(alpha: 0.18),
                        border: Border(
                          top: BorderSide(
                              color: values[i] == 0 ? tk.line : tk.mark,
                              width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(labels[i],
                        style: AppText.meta(tk.inkSoft, size: 8)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 단계

  Widget _stepsPanel(AppTokens tk, GoalDashboardData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Text('§ ', style: AppText.serif(tk.mark, size: 15)),
              Text('진행 단계', style: AppText.serif(tk.ink, size: 16)),
              const Spacer(),
              GestureDetector(
                onTap: _addStep,
                behavior: HitTestBehavior.opaque,
                child: Text('＋ 단계', style: AppText.meta(tk.mark, size: 11)),
              ),
            ],
          ),
        ),
        if (d.steps.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('— 아직 단계가 없어요. 목표를 작은 단계로 나눠 봐요',
                style: AppText.meta(tk.inkSoft)),
          )
        else
          Container(
            decoration:
                BoxDecoration(border: Border(top: BorderSide(color: tk.ink))),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: d.steps.length,
              onReorder: (oldI, newI) async {
                final ids = [for (final s in d.steps) s.id];
                if (newI > oldI) newI -= 1;
                final moved = ids.removeAt(oldI);
                ids.insert(newI, moved);
                await _repo.reorderSteps(ids);
                await _load();
              },
              itemBuilder: (context, i) {
                final s = d.steps[i];
                return _stepRow(tk, s, i, key: ValueKey(s.id));
              },
            ),
          ),
      ],
    );
  }

  Widget _stepRow(AppTokens tk, Node s, int index, {required Key key}) {
    final done = s.status == NodeStatus.done;
    return Container(
      key: key,
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              await _repo.toggleStep(widget.goalId, s);
              await _load();
            },
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 22,
              child:
                  Text(done ? '■' : '□', style: AppText.glyph(tk.ink, size: 15)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _editStep(s),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title,
                      style: AppText.body(
                              done ? tk.ink.withValues(alpha: 0.5) : tk.ink)
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(done ? '완료' : '대기',
                      style: AppText.meta(tk.inkSoft, size: 8)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _stepActions(s),
            behavior: HitTestBehavior.opaque,
            child: Text('···', style: AppText.glyph(tk.inkSoft, size: 14)),
          ),
          const SizedBox(width: 6),
          ReorderableDragStartListener(
            index: index,
            child: Text('≡', style: AppText.glyph(tk.inkSoft, size: 14)),
          ),
        ],
      ),
    );
  }

  Future<void> _addStep() async {
    final name = await showInputDialog(context,
        title: '새 단계',
        subtitle: '목표를 이루기 위한 작은 단계 하나.',
        fieldLabel: '단계 이름',
        hint: '예: 1장 읽기',
        saveLabel: '추가');
    if (name == null || name.trim().isEmpty) return;
    await _repo.addStep(widget.goalId, name.trim());
    await _load();
  }

  Future<void> _editStep(Node s) async {
    final name = await showInputDialog(context,
        title: '단계 수정',
        initial: s.title,
        fieldLabel: '단계 이름',
        saveLabel: '저장');
    if (name == null || name.trim().isEmpty) return;
    await _repo.editStep(s.id, name.trim());
    await _load();
  }

  Future<void> _stepActions(Node s) async {
    final tk = t(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: tk.paper,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_outlined, color: tk.ink, size: 20),
              title: Text('단계 수정', style: AppText.body(tk.ink)),
              onTap: () {
                Navigator.of(ctx).pop();
                _editStep(s);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: tk.ink, size: 20),
              title: Text('단계 삭제', style: AppText.body(tk.ink)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final ok = await showConfirmDialog(context,
                    title: '단계를 삭제할까요?',
                    message: '"${s.title}"',
                    confirmLabel: '삭제',
                    danger: true);
                if (!ok) return;
                await _repo.deleteStep(widget.goalId, s.id);
                await _load();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 메모

  Widget _notePanel(AppTokens tk, GoalDashboardData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GOAL NOTE',
                  style: AppText.meta(tk.mark, size: 8)
                      .copyWith(letterSpacing: 1.3)),
              const SizedBox(height: 7),
              Text('목표 메모', style: AppText.serif(tk.ink, size: 16)),
            ],
          ),
        ),
        Container(height: 1, color: tk.ink),
        TextField(
          controller: _noteCtrl,
          minLines: 8,
          maxLines: null,
          onChanged: (_) => setState(() => _noteDirty = true),
          style: AppText.body(tk.ink).copyWith(fontSize: 14, height: 1.7),
          cursorColor: tk.mark,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            hintText: '생각, 계획, 막힌 점, 다음에 할 일을 자유롭게 적어요.',
            hintStyle: AppText.meta(tk.inkSoft, size: 13),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: tk.line)),
            focusedBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: tk.line)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(_noteDirty ? '저장하지 않은 변경' : d.noteSavedLabel,
                style: AppText.meta(tk.inkSoft, size: 9)),
            const Spacer(),
            Text('${_noteCtrl.text.length}자',
                style: AppText.meta(tk.inkSoft, size: 9)),
          ],
        ),
        const SizedBox(height: 13),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () {
                _noteCtrl.clear();
                setState(() => _noteDirty = true);
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Text('비우기',
                    style: AppText.body(tk.inkSoft).copyWith(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () async {
                await _repo.saveNote(widget.goalId, _noteCtrl.text);
                setState(() => _noteDirty = false);
                _toast('목표 메모를 저장했어요');
                await _load();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                color: tk.ink,
                child: Text('메모 저장',
                    style: AppText.body(tk.paper).copyWith(fontSize: 13)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- 기록

  Widget _historyPanel(AppTokens tk, GoalDashboardData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Text('§ ', style: AppText.serif(tk.mark, size: 15)),
              Text('진행 기록', style: AppText.serif(tk.ink, size: 16)),
              const Spacer(),
              Text('최근 활동', style: AppText.meta(tk.inkSoft, size: 10)),
            ],
          ),
        ),
        if (d.history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('— 아직 기록이 없어요', style: AppText.meta(tk.inkSoft)),
          )
        else
          Container(
            decoration:
                BoxDecoration(border: Border(top: BorderSide(color: tk.ink))),
            child: Column(
              children: [
                for (var i = 0; i < d.history.length; i++)
                  _historyRow(tk, d.history[i],
                      last: i == d.history.length - 1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _historyRow(AppTokens tk, GoalEvent e, {required bool last}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Text(goalEventTimeLabel(e.at),
                style:
                    AppText.meta(tk.inkSoft, size: 8).copyWith(height: 1.4)),
          ),
          SizedBox(
            width: 12,
            child: Column(
              children: [
                const SizedBox(height: 3),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tk.paper,
                    border: Border.all(color: tk.mark, width: 1),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                        width: 1,
                        margin: const EdgeInsets.only(top: 3),
                        color: tk.line),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    style: AppText.body(tk.ink)
                        .copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                if (e.detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(e.detail,
                        style: AppText.meta(tk.inkSoft, size: 9)
                            .copyWith(height: 1.55)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 세그먼트 탭 — 앱 공통 [EdTabs] 와 동일한 톤(밑줄 활성). 4개 탭을 가로 균등 분할.
class EdTabsInline extends StatelessWidget {
  const EdTabsInline({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == index ? tk.mark : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: AppText.meta(
                            i == index ? tk.ink : tk.inkSoft, size: 11)
                        .copyWith(letterSpacing: 0.4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
