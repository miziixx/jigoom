import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/dialogs.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../today/distraction_review_sheet.dart';
import 'focus_session_controller.dart';

/// 집중 타이머 화면을 연다. [node] 가 있으면 그 노드를 들고 시작.
/// [autoStartMinutes] 를 주면 화면 진입 즉시 그 길이로 시작(3분만 시작 등).
/// autoStartMinutes 에 -1 을 주면 몰입모드로 자동 시작.
Future<void> openFocusTimer(
  BuildContext context, {
  Node? node,
  int? autoStartMinutes,
}) async {
  await Navigator.of(context).push<void>(MaterialPageRoute<void>(
    builder: (_) =>
        FocusTimerView(node: node, autoStartMinutes: autoStartMinutes),
    fullscreenDialog: true,
  ));
}

/// 집중 시간 선택지. minutes=null → 몰입모드(무제한).
const _durationOptions = <({int? minutes, String label, String desc})>[
  (minutes: 3, label: '3분', desc: '시동 걸기'),
  (minutes: 10, label: '10분', desc: '짧게'),
  (minutes: 20, label: '20분', desc: '한 판'),
  (minutes: null, label: '몰입', desc: '무제한'),
];

class FocusTimerView extends ConsumerStatefulWidget {
  const FocusTimerView({super.key, this.node, this.autoStartMinutes});

  final Node? node;

  /// null=자동시작 안 함, -1=몰입 자동시작, 그 외 양수=해당 분 자동시작.
  final int? autoStartMinutes;

  @override
  ConsumerState<FocusTimerView> createState() => _FocusTimerViewState();
}

class _FocusTimerViewState extends ConsumerState<FocusTimerView> {
  late final FocusSessionController _ctrl;
  int _selIndex = 0; // 선택된 시간(pre-start)

  @override
  void initState() {
    super.initState();
    _ctrl = FocusSessionController(ref.read(focusSessionRepoProvider));
    final auto = widget.autoStartMinutes;
    if (auto != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ctrl.start(
          nodeId: widget.node?.id,
          plannedMinutes: auto == -1 ? null : auto,
        );
      });
    }
  }

  @override
  void dispose() {
    // 실행 중 화면을 벗어나면 조용히 종료만 기록.
    _ctrl.endSilently();
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _saveThought() async {
    final text = await showInputDialog(
      context,
      kicker: '생각',
      title: '잠깐 떠오른 것',
      hint: '예: 엄마한테 전화, 이거 사두기',
    );
    if (text == null || text.trim().isEmpty) return;
    await ref.read(nodeRepoProvider).create(
          type: NodeType.memo,
          title: text.trim(),
          focusSessionId: _ctrl.sessionId,
        );
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('보관함에 담았어요 · 계속 집중'),
          duration: Duration(milliseconds: 1400),
        ));
    }
  }

  /// 종료 → 방해요소 리뷰 → 다음 시작점 → 닫기.
  Future<void> _finish() async {
    final sid = await _ctrl.stop();
    if (!mounted) {
      return;
    }
    final repo = ref.read(nodeRepoProvider);

    // 이 세션 중 담아둔 방해요소가 있으면 리뷰.
    if (sid != null) {
      final distractions = await repo.distractionsForSession(sid);
      if (mounted && distractions.isNotEmpty) {
        await showDistractionReviewSheet(context, distractions);
      }
    }

    // 노드가 연결돼 있으면 다음 시작점 한 줄(건너뛰기 가능).
    final nodeId = _ctrl.nodeId;
    if (mounted && nodeId != null) {
      final next = await showInputDialog(
        context,
        kicker: '다음',
        title: '다음엔 어디부터?',
        hint: '건너뛰어도 괜찮아요 · 예: 3장부터',
      );
      if (next != null && next.trim().isNotEmpty) {
        await repo.setNextStep(nodeId, next.trim());
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_ctrl.running) {
              _finish();
            } else {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            body: SafeArea(
              child: _ctrl.running ? _buildRunning() : _buildPreStart(),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------ pre-start
  Widget _buildPreStart() {
    final tk = t(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 8, AppSpace.gutter, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.close, color: tk.inkSoft),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(height: 8),
          Text('› 집중', style: AppText.sec(tk.mark)),
          const SizedBox(height: 10),
          if (widget.node != null)
            Text(widget.node!.title, style: AppText.hTitle(tk.ink))
          else
            Text('지금 조금만 시작해요', style: AppText.hTitle(tk.ink)),
          const SizedBox(height: 6),
          Text('완벽하게 말고, 딱 시작만.', style: AppText.meta(tk.inkSoft)),

          const SizedBox(height: 28),
          Text('얼마나', style: AppText.sec(tk.ink)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _durationOptions.length; i++)
                _durationChip(i),
            ],
          ),

          const SizedBox(height: 16),
          // 최근 평균 힌트 (표본 충분할 때만). 버튼 시간은 바꾸지 않음.
          FutureBuilder<double?>(
            future: ref.read(focusSessionRepoProvider).averageActualMinutes(),
            builder: (context, snap) {
              final avg = snap.data;
              if (avg == null) return const SizedBox.shrink();
              return Text('— 요즘 평균 ${avg.round()}분쯤 집중했어요',
                  style: AppText.meta(tk.inkSoft));
            },
          ),

          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _ctrl.start(
                nodeId: widget.node?.id,
                plannedMinutes: _durationOptions[_selIndex].minutes,
              ),
              child: const Text('지금 시작'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _durationChip(int i) {
    final tk = t(context);
    final o = _durationOptions[i];
    final sel = i == _selIndex;
    return GestureDetector(
      onTap: () => setState(() => _selIndex = i),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? tk.ink : Colors.transparent,
          border: Border.all(color: sel ? tk.ink : tk.line, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(o.label,
                style: AppText.body(sel ? tk.paper : tk.ink)),
            const SizedBox(height: 2),
            Text(o.desc,
                style: AppText.meta(sel ? tk.paper : tk.inkSoft, size: 10)),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- running
  Widget _buildRunning() {
    final tk = t(context);
    final reached = _ctrl.reachedPlan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 8, AppSpace.gutter, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.close, color: tk.inkSoft),
              onPressed: _finish,
            ),
          ),
          const SizedBox(height: 8),
          Text('› 집중 중', style: AppText.sec(tk.mark)),
          const SizedBox(height: 10),
          if (widget.node != null)
            Text(widget.node!.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(tk.ink)),

          const Spacer(),
          // 큰 경과 시간 (count-up).
          Center(
            child: Text(_fmt(_ctrl.elapsedSeconds),
                style: AppText.glyph(tk.ink, size: 64)),
          ),
          const SizedBox(height: 12),
          if (!_ctrl.isImmersive) ...[
            // 계획 시간 대비 진행 라인.
            Stack(
              children: [
                Container(height: 3, color: tk.line),
                FractionallySizedBox(
                  widthFactor: _ctrl.plannedSeconds == 0
                      ? 0
                      : (_ctrl.elapsedSeconds / _ctrl.plannedSeconds)
                          .clamp(0.0, 1.0),
                  child: Container(height: 3, color: tk.ink),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                  reached
                      ? '시간을 채웠어요 · 이어가도, 마무리해도 좋아요'
                      : '${_ctrl.plannedMinutes}분 중 · 남은 ${_fmt(_ctrl.remainingSeconds)}',
                  style: AppText.meta(reached ? tk.mark : tk.inkSoft)),
            ),
          ] else
            Center(
                child: Text('몰입모드 · 준비되면 마무리해요',
                    style: AppText.meta(tk.inkSoft))),

          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saveThought,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tk.ink,
                    side: BorderSide(color: tk.line),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('생각 저장'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _finish,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('그만하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
