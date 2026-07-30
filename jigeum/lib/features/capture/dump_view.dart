/// 쏟아내기(brain dump) 화면. 기획: "판단 끄고 다 뱉기 → 엔진이 미리 갈라 →
/// 확인(고치기) → 한 번에 담기".
///
/// 적고 엔터 → 같은 분류 엔진([VoiceController])이 **부작용 없이 미리 분류**해
/// 대기줄에 쌓는다(아직 안 담김). 잘못 갈린 건 버킷 태그를 탭해 바꾸고(학습 신호),
/// 다 되면 [담기]로 한 번에 실제로 담는다. 음성 없이 타이핑만으로.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../voice/models/intent_type.dart';
import '../voice/models/voice_result.dart';
import 'dump_staging.dart';

class DumpView extends ConsumerStatefulWidget {
  const DumpView({super.key});

  @override
  ConsumerState<DumpView> createState() => _DumpViewState();
}

/// 확인 단계에서 고를 수 있는 버킷들(흔한 순).
const _pickable = <RoutePoint>[
  RoutePoint.schedule,
  RoutePoint.quickCapture,
  RoutePoint.matrix,
  RoutePoint.logNow,
  RoutePoint.habit,
  RoutePoint.timeTrack,
  RoutePoint.inbox,
];

/// 분류 카드 아이콘 글리프 (레퍼런스 class-icon).
String _routeGlyph(RoutePoint rp) => switch (rp) {
      RoutePoint.quickCapture => '✓',
      RoutePoint.schedule => '▦',
      RoutePoint.matrix => '⊞',
      RoutePoint.logNow => '●',
      RoutePoint.habit => '◇',
      RoutePoint.timeTrack => '◷',
      RoutePoint.inbox => '□',
      _ => '·',
    };

/// 분류 카드 설명 (레퍼런스 class-card small).
String _routeHelp(RoutePoint rp) => switch (rp) {
      RoutePoint.quickCapture => '할 일로 담기',
      RoutePoint.schedule => '날짜와 시간 지정',
      RoutePoint.matrix => '중요도·긴급도 분류',
      RoutePoint.logNow => '지금 하는 일 기록',
      RoutePoint.habit => '매일 반복 습관',
      RoutePoint.timeTrack => '시간대별 기록',
      RoutePoint.inbox => '나중에 다시 보기',
      _ => '',
    };

class _MatrixTarget {
  const _MatrixTarget(this.label, this.help,
      {required this.important, required this.urgent, this.mark = false});

  final String label;
  final String help;
  final bool important;
  final bool urgent;
  final bool mark;
}

const _matrixTargets = [
  _MatrixTarget('URGENT+IMPORTANT', '오늘 바로 처리',
      important: true, urgent: true, mark: true),
  _MatrixTarget('IMPORTANT', '목표로 키우기', important: true, urgent: false),
  _MatrixTarget('URGENT', '빨리 비우기', important: false, urgent: true),
  _MatrixTarget('DRAWER', '언젠가 서랍', important: false, urgent: false),
];

class _DumpViewState extends ConsumerState<DumpView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _focus.requestFocus();
    // 부작용 없이 분류만(담기는 나중에 한꺼번에). 대기줄은 화면 밖 provider 가
    // 들고 있어 탭 이동·앱 재시작에도 안 사라진다.
    final results = ref.read(voiceControllerProvider).classifyMany(text);
    final staging = ref.read(dumpStagingProvider.notifier);
    for (final r in results) {
      staging.addResult(r);
    }
  }

  Future<void> _pickBucket(int i) async {
    final tk = t(context);
    final pending = ref.read(dumpStagingProvider);
    if (i >= pending.length) return;
    final rawText = pending[i].rawText;
    final current = pending[i].routedTo;
    final chosen = await showModalBottomSheet<RoutePoint>(
      context: context,
      backgroundColor: tk.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter, 12, AppSpace.gutter, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                      color: tk.line, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 18),
              // 레퍼런스 sheet-head: 제목 + "항목" + ✕
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('어디로 보낼까요?',
                            style:
                                AppText.hTitle(tk.ink).copyWith(fontSize: 20)),
                        const SizedBox(height: 5),
                        Text('“$rawText”',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.meta(tk.inkSoft, size: 11)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetCtx),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: tk.line)),
                      child: Text('✕', style: AppText.glyph(tk.ink, size: 15)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 레퍼런스 class-grid: 2열 카드(아이콘 + 이름 + 설명).
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.9,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                children: [
                  for (final rp in _pickable)
                    GestureDetector(
                      onTap: () => Navigator.pop(sheetCtx, rp),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: current == rp ? tk.mark : tk.line,
                              width: current == rp ? 1.5 : 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  border: Border.all(color: tk.line)),
                              child: Text(_routeGlyph(rp),
                                  style: AppText.glyph(
                                      current == rp ? tk.mark : tk.inkSoft,
                                      size: 14)),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(rp.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.body(tk.ink)
                                          .copyWith(fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text(_routeHelp(rp),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          AppText.meta(tk.inkSoft, size: 8)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    final cur = ref.read(dumpStagingProvider);
    if (i >= cur.length) return;
    final rerouted = ref.read(voiceControllerProvider).reroute(cur[i], chosen);
    ref.read(dumpStagingProvider.notifier).replaceAt(i, rerouted);
  }

  void _moveToQuadrant(int i, _MatrixTarget target) {
    final pending = ref.read(dumpStagingProvider);
    if (i < 0 || i >= pending.length) return;
    final rerouted = ref.read(voiceControllerProvider).rerouteToMatrixQuadrant(
          pending[i],
          important: target.important,
          urgent: target.urgent,
        );
    ref.read(dumpStagingProvider.notifier).replaceAt(i, rerouted);
  }

  Future<void> _commitAll() async {
    final pending = ref.read(dumpStagingProvider);
    if (pending.isEmpty) return;
    final n = pending.length;
    final ctrl = ref.read(voiceControllerProvider);
    for (final r in pending) {
      await ctrl.commit(r);
    }
    ref.read(dumpStagingProvider.notifier).clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t(context).ink,
        content: Text('$n개 정리 완료', style: AppText.body(t(context).paper)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final pending = ref.watch(dumpStagingProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FREE NOTE 카드 — 지금 떠오르는 걸 전부 적고 '쏟아내기'.
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter, 10, AppSpace.gutter, 4),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: tk.line)),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('FREE NOTE',
                    style: AppText.meta(tk.inkSoft, size: 9)
                        .copyWith(letterSpacing: 1.4)),
                const SizedBox(height: 8),
                Center(
                    child: Text('BRAIN DUMP',
                        style: AppText.meta(tk.inkSoft, size: 10)
                            .copyWith(letterSpacing: 2))),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  textAlign: TextAlign.center,
                  cursorColor: tk.mark,
                  style: AppText.hTitle(tk.ink).copyWith(fontSize: 17, height: 1.4),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '지금 떠오르는 걸 전부 적어요.\n정리는 나중에 하면 돼요.',
                    hintStyle: AppText.hTitle(tk.inkSoft)
                        .copyWith(fontSize: 16, height: 1.4),
                    hintMaxLines: 2,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: tk.line),
                const SizedBox(height: 12),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _focus.requestFocus(),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Icon(Icons.mic_none, size: 17, color: tk.inkSoft),
                          const SizedBox(width: 6),
                          Text('말로 적기',
                              style: AppText.meta(tk.inkSoft, size: 11)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _submit,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        color: tk.mark,
                        child: Text('쏟아내기',
                            style: AppText.body(tk.paper).copyWith(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 대기줄 — 엔진이 갈라놓은 버킷. 탭해서 고칠 수 있음.
        Expanded(
          child: pending.isEmpty
              ? _empty(tk)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.gutter, 18, AppSpace.gutter, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('§ ',
                              style: AppText.hTitle(tk.mark)
                                  .copyWith(fontSize: 15)),
                          Text('아직 분류하지 않음',
                              style: AppText.hTitle(tk.ink)
                                  .copyWith(fontSize: 16)),
                          const Spacer(),
                          Text('${pending.length}개',
                              style: AppText.meta(tk.inkSoft, size: 11)),
                        ],
                      ),
                    ),
                    _matrixDropBoard(tk),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.gutter, vertical: 8),
                        itemCount: pending.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: tk.line),
                        itemBuilder: (_, i) => _row(tk, pending[i], i),
                      ),
                    ),
                  ],
                ),
        ),

        // 담기 바 — 대기 중일 때만.
        if (pending.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: tk.paper,
              border: Border(top: BorderSide(color: tk.ink, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter, 10, AppSpace.gutter, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('길게 눌러 매트릭스에 놓거나, 태그를 탭해 바꿔요',
                          style: AppText.meta(tk.inkSoft, size: 11)),
                    ),
                    GestureDetector(
                      onTap: _commitAll,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: tk.ink,
                        child: Text('${pending.length}개 담기',
                            style: AppText.nav(tk.paper, active: true)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _row(AppTokens tk, VoiceResult r, int i) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.rawText, style: AppText.body(tk.ink)),
                const SizedBox(height: 4),
                Text('→ ${r.routedTo.label}',
                    style: AppText.meta(tk.inkSoft, size: 10)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 분류하기 — 탭해서 버킷 선택/재분류.
          GestureDetector(
            onTap: () => _pickBucket(i),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('분류하기', style: AppText.meta(tk.mark, size: 11)),
                const SizedBox(width: 3),
                Text('›', style: AppText.glyph(tk.mark, size: 14)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(dumpStagingProvider.notifier).removeAt(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.close, size: 16, color: tk.inkSoft),
            ),
          ),
        ],
      ),
    );
    return LongPressDraggable<int>(
      data: i,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: tk.paper,
            border: Border.all(color: tk.ink, width: 1),
          ),
          child: Text(r.rawText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(tk.ink)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: child),
      child: child,
    );
  }

  Widget _matrixDropBoard(AppTokens tk) {
    Widget lineH() => Container(height: 1, color: tk.line);
    Widget lineV() => Container(width: 1, color: tk.line);

    return Container(
      margin:
          const EdgeInsets.fromLTRB(AppSpace.gutter, 10, AppSpace.gutter, 8),
      decoration: BoxDecoration(
        border: Border.all(color: tk.line, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _dropCell(tk, _matrixTargets[0])),
              lineV(),
              Expanded(child: _dropCell(tk, _matrixTargets[1])),
            ],
          ),
          lineH(),
          Row(
            children: [
              Expanded(child: _dropCell(tk, _matrixTargets[2])),
              lineV(),
              Expanded(child: _dropCell(tk, _matrixTargets[3])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropCell(AppTokens tk, _MatrixTarget target) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => _moveToQuadrant(details.data, target),
      builder: (context, candidates, rejected) {
        final active = candidates.isNotEmpty;
        final color =
            target.mark ? tk.mark : (target.important ? tk.ink : tk.inkSoft);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 74,
          padding: const EdgeInsets.all(10),
          color: active ? tk.paper2 : tk.paper,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(target.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sec(active ? tk.ink : color)),
              const SizedBox(height: 6),
              Text(target.help,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta(tk.inkSoft, size: 10)),
            ],
          ),
        );
      },
    );
  }

  Widget _empty(AppTokens tk) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.gutter),
          child: Text(
            '떠오르는 대로 적고 엔터.\n엔진이 미리 갈라두면, 확인하고 한 번에 담아요.',
            textAlign: TextAlign.center,
            style: AppText.meta(tk.inkSoft, size: 13),
          ),
        ),
      );
}
