import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/editorial.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../capture/quick_capture_input.dart';
import 'quadrant_list.dart';

/// 사분면 메타 — 한글 제목 · 영문 서브라벨 · 저채도 틴트 · 점 색.
class _Quad {
  const _Quad(this.title, this.sub, this.tint, this.dot,
      {required this.important, required this.urgent, this.drawer = false});
  final String title;
  final String sub;
  final Color tint;
  final Color dot;
  final bool important;
  final bool urgent;
  final bool drawer;
}

// v17 레퍼런스 색(저채도): 긴급중요=적, 중요=녹, 긴급=금, 둘다아님=회.
const _cDanger = Color(0xFFA64E4E);
const _cDangerWeak = Color(0xFFF3E7E5);
const _cAccent = Color(0xFFB2854E);
const _cAccentWeak = Color(0xFFF4ECDD);

/// 아이젠하워 매트릭스 — 2×2. 각 영역 저채도 틴트 + 체크박스 할 일.
class MatrixView extends ConsumerWidget {
  const MatrixView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final quads = <_Quad>[
      const _Quad('긴급하고 중요', 'DO FIRST', _cDangerWeak, _cDanger,
          important: true, urgent: true),
      _Quad('중요하지만\n긴급하지 않음', 'SCHEDULE',
          tk.mark.withValues(alpha: 0.10), tk.mark,
          important: true, urgent: false),
      const _Quad('긴급하지만\n중요하지 않음', 'DELEGATE', _cAccentWeak, _cAccent,
          important: false, urgent: true),
      _Quad('둘 다 아님', 'DELETE', tk.line.withValues(alpha: 0.4), tk.inkSoft,
          important: false, urgent: false, drawer: true),
    ];

    return Container(
      color: tk.paper,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _header(context, ref, tk),
          const Padding(
            padding: EdgeInsets.fromLTRB(kGutter, 2, kGutter, 6),
            child: _RangeBar(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kGutter),
            child: Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _QuadCell(quad: quads[0])),
                      const SizedBox(width: 10),
                      Expanded(child: _QuadCell(quad: quads[1])),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _QuadCell(quad: quads[2])),
                      const SizedBox(width: 10),
                      Expanded(child: _QuadCell(quad: quads[3])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, AppTokens tk) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('§ ', style: AppText.hTitle(tk.mark).copyWith(fontSize: 15)),
              Text('아이젠하워 매트릭스',
                  style: AppText.hTitle(tk.ink).copyWith(fontSize: 16)),
              const Spacer(),
              GestureDetector(
                onTap: () => showQuickCaptureInput(context, ref),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 2),
                  child: Text('＋ 할 일', style: AppText.meta(tk.mark, size: 11)),
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

/// 사분면 셀 — 틴트 배경 + 제목/점 + 서브라벨 + 헤어라인 + 체크박스 할 일(상위 3).
class _QuadCell extends ConsumerWidget {
  const _QuadCell({required this.quad});
  final _Quad quad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final nodes = ref
            .watch(quadrantProvider(
                (important: quad.important, urgent: quad.urgent)))
            .valueOrNull ??
        const [];
    final top = nodes.take(3).toList();
    final more = nodes.length - top.length;

    // 다른 칸에서 끌어온 할 일을 이 칸의 중요/긴급 값으로 재분류.
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => ref.read(nodeRepoProvider).setMatrix(
            d.data,
            important: quad.important,
            urgent: quad.urgent,
          ),
      builder: (context, candidate, rejected) {
        final hover = candidate.isNotEmpty;
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => QuadrantListScreen(
                title: quad.sub,
                important: quad.important,
                urgent: quad.urgent),
          )),
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: 168),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: quad.tint,
              borderRadius: BorderRadius.circular(12),
              border: hover
                  ? Border.all(color: tk.mark, width: 1.5)
                  : Border.all(color: Colors.transparent, width: 1.5),
            ),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(quad.title,
                      // 레퍼런스 .quad h3 — 세리프 아닌 산세리프(inherit) 굵기 500.
                      style: AppText.body(tk.ink).copyWith(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w500)),
                ),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4, left: 6),
                  decoration:
                      BoxDecoration(color: quad.dot, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(quad.sub,
                style: AppText.meta(tk.inkSoft, size: 9)
                    .copyWith(letterSpacing: 1)),
            const SizedBox(height: 10),
            Container(height: 1, color: tk.ink.withValues(alpha: 0.10)),
            if (nodes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('지금은 비어 있어요.',
                    style: AppText.meta(tk.inkSoft, size: 10)),
              )
            else
              for (final n in top)
                _QuadTask(node: n, drawer: quad.drawer),
            if (more > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('+$more', style: AppText.meta(tk.inkSoft, size: 10)),
              ),
          ],
            ),
          ),
        );
      },
    );
  }
}

class _QuadTask extends ConsumerWidget {
  const _QuadTask({required this.node, required this.drawer});
  final dynamic node;
  final bool drawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final row = Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref.read(nodeRepoProvider).complete(node.id as String),
            child: const EdCheck(done: false, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(node.title as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(tk.ink).copyWith(fontSize: 12)),
          ),
        ],
      ),
    );
    // 길게 눌러 다른 칸으로 끌어 옮기기(중요/긴급 재분류). 짧게 탭은 완료.
    return LongPressDraggable<String>(
      data: node.id as String,
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: tk.paper,
            border: Border.all(color: tk.mark, width: 1.5),
          ),
          child: Text(node.title as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(tk.ink).copyWith(fontSize: 12)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: row),
      child: row,
    );
  }
}

/// 기간 선택 바 — 알약 칩. 기본값 "오늘". 날짜 없는 할 일은 늘 보인다.
class _RangeBar extends ConsumerWidget {
  const _RangeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final current = ref.watch(matrixRangeProvider);
    return Row(
      children: [
        for (final r in MatrixRange.values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: PillChip(
              label: r.label,
              selected: r == current,
              onTap: () => ref.read(matrixRangeProvider.notifier).state = r,
            ),
          ),
        const Spacer(),
        Text('날짜 없는 일 포함', style: AppText.meta(tk.inkSoft, size: 10)),
      ],
    );
  }
}
