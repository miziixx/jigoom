import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../capture/quick_capture_input.dart';
import 'quadrant_list.dart';

/// 매트릭스 뷰 — 2×2. 카드가 아니라 1px 규칙선 십자로 나눈다.
/// 각 칸: 대문자 모노 라벨 + 카운트 + 상위 3개. Q4(서랍)는 개수만.
class MatrixView extends ConsumerWidget {
  const MatrixView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    Widget vline() => Container(width: 1, color: tk.line);
    Widget hline() => Container(height: 1, color: tk.line);

    return Container(
      color: tk.paper,
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 8),
      child: Column(
        children: [
          const _RangeBar(),
          Expanded(
            child: Row(
              children: [
                const Expanded(
                    child: _Cell(
                        label: 'URGENT+IMPORTANT',
                        important: true,
                        urgent: true,
                        mark: true)),
                vline(),
                const Expanded(
                    child: _Cell(
                        label: 'IMPORTANT',
                        important: true,
                        urgent: false,
                        emphasis: true)),
              ],
            ),
          ),
          hline(),
          Expanded(
            child: Row(
              children: [
                const Expanded(
                    child: _Cell(
                        label: 'URGENT',
                        important: false,
                        urgent: true)),
                vline(),
                const Expanded(child: _DrawerCell()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 맨 위 기간 선택 바 — 알약 칩. 기본값은 "오늘".
/// 날짜 없는 할 일은 기간과 상관없이 늘 보인다(언제든 할 수 있는 일).
class _RangeBar extends ConsumerWidget {
  const _RangeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final current = ref.watch(matrixRangeProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (final r in MatrixRange.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: PillChip(
                label: r.label,
                selected: r == current,
                onTap: () =>
                    ref.read(matrixRangeProvider.notifier).state = r,
              ),
            ),
          const Spacer(),
          Text('날짜 없는 일 포함', style: AppText.meta(tk.inkSoft, size: 10)),
        ],
      ),
    );
  }
}

class _Cell extends ConsumerWidget {
  const _Cell({
    required this.label,
    required this.important,
    required this.urgent,
    this.emphasis = false,
    this.mark = false,
  });

  final String label;
  final bool important;
  final bool urgent;
  final bool emphasis;
  final bool mark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final nodes = ref
            .watch(quadrantProvider((important: important, urgent: urgent)))
            .valueOrNull ??
        const [];
    final top = nodes.take(3).toList();
    final more = nodes.length - top.length;
    final labelColor = mark ? tk.mark : (emphasis ? tk.ink : tk.inkSoft);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuadrantListScreen(
            title: label, important: important, urgent: urgent),
      )),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(label,
                        style: AppText.sec(labelColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Text('${nodes.length}', style: AppText.meta(tk.inkSoft)),
                GestureDetector(
                  onTap: () => showQuickCaptureInput(context, ref,
                      presetImportant: important,
                      presetUrgent: urgent,
                      quadrantLabel: important && urgent
                          ? '긴급·중요'
                          : (important ? '중요' : '긴급')),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('＋', style: AppText.glyph(tk.mark, size: 17)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final n in top)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(tk.ink)),
                    ),
                  if (more > 0)
                    Text('+$more', style: AppText.meta(tk.inkSoft)),
                  if (nodes.isEmpty)
                    Text('— 비어 있어요', style: AppText.meta(tk.inkSoft)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Q4: 개수만.
class _DrawerCell extends ConsumerWidget {
  const _DrawerCell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final nodes = ref
            .watch(quadrantProvider((important: false, urgent: false)))
            .valueOrNull ??
        const [];
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const QuadrantListScreen(
            title: 'DRAWER', important: false, urgent: false),
      )),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Text('DRAWER', style: AppText.sec(tk.inkSoft)),
                const Spacer(),
                GestureDetector(
                  onTap: () => showQuickCaptureInput(context, ref,
                      quadrantLabel: '서랍', toDrawer: true),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('＋', style: AppText.glyph(tk.mark, size: 17)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${nodes.length}', style: AppText.hTitle(tk.ink)),
                const SizedBox(width: 6),
                Text('미분류', style: AppText.meta(tk.inkSoft)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final n in nodes.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(tk.ink)),
                    ),
                  if (nodes.length > 3)
                    Text('+${nodes.length - 3}',
                        style: AppText.meta(tk.inkSoft)),
                  if (nodes.isEmpty)
                    Text('— 비어 있어요', style: AppText.meta(tk.inkSoft)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
