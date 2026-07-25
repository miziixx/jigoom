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

class _DumpViewState extends ConsumerState<DumpView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  // 대기줄 — 아직 안 담은, 미리 분류된 것들(최신 위).
  final List<VoiceResult> _pending = [];

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
    // 부작용 없이 분류만(담기는 나중에 한꺼번에).
    final r = ref.read(voiceControllerProvider).classify(text);
    setState(() => _pending.insert(0, r));
  }

  Future<void> _pickBucket(int i) async {
    final tk = t(context);
    final chosen = await showModalBottomSheet<RoutePoint>(
      context: context,
      backgroundColor: tk.paper,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 16, AppSpace.gutter, 6),
              child: Text('어디로 보낼까요?',
                  style: AppText.meta(tk.inkSoft, size: 11)),
            ),
            for (final rp in _pickable)
              ListTile(
                title: Text(rp.label, style: AppText.body(tk.ink)),
                trailing: _pending[i].routedTo == rp
                    ? Icon(Icons.check, color: tk.mark, size: 18)
                    : null,
                onTap: () => Navigator.pop(context, rp),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    final rerouted =
        ref.read(voiceControllerProvider).reroute(_pending[i], chosen);
    setState(() => _pending[i] = rerouted);
  }

  Future<void> _commitAll() async {
    if (_pending.isEmpty) return;
    final n = _pending.length;
    final ctrl = ref.read(voiceControllerProvider);
    for (final r in _pending) {
      await ctrl.commit(r);
    }
    if (!mounted) return;
    setState(_pending.clear);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t(context).ink,
        content: Text('$n개 정리 완료',
            style: AppText.body(t(context).paper)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더.
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 14, AppSpace.gutter, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('판단은 나중에 · 생각나는 대로',
                        style: AppText.meta(tk.inkSoft, size: 11)),
                    const SizedBox(height: 2),
                    Text('머릿속을 비워요', style: AppText.hTitle(tk.ink)),
                  ],
                ),
              ),
              if (_pending.isNotEmpty)
                Text('${_pending.length}개 대기',
                    style: AppText.meta(tk.mark, size: 11)),
            ],
          ),
        ),

        // 입력 — 칩 없이 프롬프트 한 줄.
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: tk.ink, width: 1),
              bottom: BorderSide(color: tk.line, width: 1),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 12, AppSpace.gutter, 12),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: Text('›', style: AppText.glyph(tk.mark, size: 16)),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  cursorColor: tk.mark,
                  style: AppText.body(tk.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '적고 엔터 · 또 적고 엔터_',
                    hintStyle: AppText.meta(tk.inkSoft, size: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _submit,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text('쏟기', style: AppText.nav(tk.ink, active: true)),
                ),
              ),
            ],
          ),
        ),

        // 대기줄 — 엔진이 갈라놓은 버킷. 탭해서 고칠 수 있음.
        Expanded(
          child: _pending.isEmpty
              ? _empty(tk)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.gutter, vertical: 8),
                  itemCount: _pending.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: tk.line),
                  itemBuilder: (_, i) => _row(tk, i),
                ),
        ),

        // 담기 바 — 대기 중일 때만.
        if (_pending.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: tk.paper,
              border: Border(top: BorderSide(color: tk.ink, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 10, AppSpace.gutter, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('태그를 탭하면 다른 곳으로 옮겨요',
                          style: AppText.meta(tk.inkSoft, size: 11)),
                    ),
                    GestureDetector(
                      onTap: _commitAll,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: tk.ink,
                        child: Text('${_pending.length}개 담기',
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

  Widget _row(AppTokens tk, int i) {
    final r = _pending[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(r.rawText, style: AppText.body(tk.ink))),
          const SizedBox(width: 10),
          // 버킷 태그 — 탭해서 재분류.
          GestureDetector(
            onTap: () => _pickBucket(i),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(border: Border.all(color: tk.mark)),
              child: Text(r.routedTo.label,
                  style: AppText.meta(tk.mark, size: 11)),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _pending.removeAt(i)),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.close, size: 16, color: tk.inkSoft),
            ),
          ),
        ],
      ),
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
