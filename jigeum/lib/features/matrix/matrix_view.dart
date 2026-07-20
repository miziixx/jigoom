import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'quadrant_list.dart';

/// 매트릭스 뷰 — 2×2 그리드. 각 칸 상위 3개 + "N개 더".
/// Q2 칸에만 액센트 테두리. Q4 는 "언젠가 서랍 · 숨김"으로 개수만.
class MatrixView extends ConsumerWidget {
  const MatrixView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _Cell(
                    title: '중요·긴급',
                    important: true,
                    urgent: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Cell(
                    title: '중요·비긴급',
                    important: true,
                    urgent: false,
                    accent: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _Cell(
                    title: '비중요·긴급',
                    important: false,
                    urgent: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DrawerCell(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends ConsumerWidget {
  const _Cell({
    required this.title,
    required this.important,
    required this.urgent,
    this.accent = false,
  });

  final String title;
  final bool important;
  final bool urgent;
  final bool accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final nodes = ref
            .watch(quadrantProvider((important: important, urgent: urgent)))
            .valueOrNull ??
        const [];
    final top = nodes.take(3).toList();
    final more = nodes.length - top.length;

    return GestureDetector(
      onTap: () => _openList(context, title, important, urgent),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accent
                ? (theme.textTheme.bodyLarge?.color ?? Colors.black)
                : (theme.dividerTheme.color ?? Colors.black12),
            width: accent ? 1.2 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final n in top)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  if (more > 0)
                    Text('$more개 더', style: theme.textTheme.bodySmall),
                  if (nodes.isEmpty)
                    Text('비어 있어요', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openList(
      BuildContext context, String title, bool important, bool urgent) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuadrantListScreen(
          title: title, important: important, urgent: urgent),
    ));
  }
}

/// Q4: 개수만 표시.
class _DrawerCell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final nodes = ref
            .watch(quadrantProvider((important: false, urgent: false)))
            .valueOrNull ??
        const [];
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const QuadrantListScreen(
            title: '언젠가 서랍', important: false, urgent: false),
      )),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('언젠가 서랍 · 숨김', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text('${nodes.length}개', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
