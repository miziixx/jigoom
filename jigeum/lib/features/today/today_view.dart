import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../outline/node_tile.dart';

/// 오늘 뷰 (홈).
/// 상단 "오늘"+날짜 → 포커스 카드 1개 → 오전/오후/저녁 섹션 → 오늘의 승리 스택.
class TodayView extends ConsumerWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final focus = ref.watch(focusProvider);
    final today = ref.watch(todayNodesProvider).valueOrNull ?? const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text('오늘', style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(DateFormat('M월 d일 EEEE', 'ko').format(DateTime.now()),
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),

        // 포커스 카드 (유일하게 시각적 무게 있음)
        focus.when(
          loading: () => const SizedBox(height: 72),
          error: (_, __) => const SizedBox.shrink(),
          data: (node) => _FocusCard(node: node),
        ),
        const SizedBox(height: 20),

        // 오전/오후/저녁 섹션
        for (final slot in Slot.all)
          _SlotSection(
            slot: slot,
            nodes: today
                .where((n) => n.slot == slot && n.status == NodeStatus.open)
                .toList(),
          ),

        // 구간 미지정 오늘 항목
        _SlotSection(
          slot: null,
          nodes: today
              .where((n) => n.slot == null && n.status == NodeStatus.open)
              .toList(),
        ),

        const SizedBox(height: 12),
        const _WinsStack(),
      ],
    );
  }
}

class _FocusCard extends ConsumerWidget {
  const _FocusCard({required this.node});
  final Node? node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (node == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12, width: 0.5),
        ),
        child: Text('지금은 비어 있어요', style: theme.textTheme.bodyMedium),
      );
    }
    final n = node!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.textTheme.bodyLarge?.color ?? Colors.black,
            width: 1.2),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ref.read(nodeRepoProvider).complete(n.id),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: theme.textTheme.bodyLarge?.color ?? Colors.black,
                    width: 1.6),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('지금 이것부터', style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(n.title, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotSection extends ConsumerWidget {
  const _SlotSection({required this.slot, required this.nodes});
  final String? slot;
  final List<Node> nodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // 구간 미지정이고 비어있으면 섹션 자체를 숨김.
    if (slot == null && nodes.isEmpty) return const SizedBox.shrink();
    final label = slot == null ? '그 외' : Slot.label(slot!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        if (nodes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text('지금은 비어 있어요',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.textTheme.bodySmall?.color)),
          )
        else
          for (final n in nodes)
            NodeTile(
              node: n,
              onToggleDone: () => ref.read(nodeRepoProvider).complete(n.id),
            ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// "오늘의 승리 · N" 접힌 스택. 탭하면 펼침.
class _WinsStack extends ConsumerStatefulWidget {
  const _WinsStack();
  @override
  ConsumerState<_WinsStack> createState() => _WinsStackState();
}

class _WinsStackState extends ConsumerState<_WinsStack> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wins = ref.watch(todayWinsProvider).valueOrNull ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    size: 16, color: AppColors.done),
                const SizedBox(width: 6),
                Text('오늘의 승리 · ${wins.length}',
                    style: theme.textTheme.bodyMedium),
                const Spacer(),
                AnimatedRotation(
                  duration: kAnimDuration,
                  turns: _open ? 0.5 : 0,
                  child: Icon(Icons.expand_more,
                      size: 18, color: theme.textTheme.bodySmall?.color),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: kAnimDuration,
          crossFadeState:
              _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Column(
            children: [
              for (final n in wins)
                NodeTile(
                  node: n,
                  showUrgentBolt: false,
                  onToggleDone: () => ref.read(nodeRepoProvider).reopen(n.id),
                ),
            ],
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
