import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import 'node_detail_sheet.dart';

/// 오늘 뷰 (홈) — 단순 모드.
/// 큰 날짜 → 포커스 카드 → 오늘 할 일(flat) → 오늘의 승리.
/// 분류·세분화 강요 없음: 적으면 오늘 목록에 들어오고, ⭐ 만 누르면 됨.
class TodayView extends ConsumerWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final focus = ref.watch(focusProvider);
    final today = ref.watch(todayNodesProvider).valueOrNull ?? const [];
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // 큰 날짜
        Text(DateFormat('M월 d일', 'ko').format(now),
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 30)),
        const SizedBox(height: 2),
        Text(DateFormat('EEEE', 'ko').format(now),
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 15)),
        const SizedBox(height: 18),

        focus.when(
          loading: () => const SizedBox(height: 60),
          error: (_, __) => const SizedBox.shrink(),
          data: (node) =>
              node == null ? const SizedBox.shrink() : _FocusCard(node: node),
        ),
        const SizedBox(height: 14),

        if (today.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('아래 입력창에 적으면 여기에 쌓여요',
                style: theme.textTheme.bodySmall),
          )
        else
          for (final n in today) SimpleTile(node: n),

        const SizedBox(height: 16),
        const _WinsStack(),
      ],
    );
  }
}

/// 단순 타일: 체크 · 제목 · 마감칩 · ⭐ · 📅
/// 스와이프 우=완료, 좌=삭제.
class SimpleTile extends ConsumerWidget {
  const SimpleTile({super.key, required this.node, this.showStar = true});

  final Node node;
  final bool showStar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(nodeRepoProvider);
    final done = node.status == NodeStatus.done;

    final tile = Opacity(
      opacity: done ? 0.45 : 1,
      child: InkWell(
        onTap: () => showNodeDetailSheet(context, node), // 메모/폴더/날짜 상세
        child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            // 체크
            GestureDetector(
              onTap: () =>
                  done ? repo.reopen(node.id) : repo.complete(node.id),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: done
                    ? const Icon(Icons.check_circle,
                        size: 22, color: AppColors.done)
                    : Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.textTheme.bodySmall?.color ??
                                Colors.grey,
                            width: 1.5,
                          ),
                        ),
                      ),
              ),
            ),
            // 제목 + 마감칩
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.title,
                      style: theme.textTheme.bodyLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (node.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.sticky_note_2_outlined,
                              size: 12,
                              color: theme.textTheme.bodySmall?.color),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              node.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (node.date != null && node.date != todayDate() && !done)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${DateFormat('M/d (E)', 'ko').format(node.date!)} 까지',
                        style:
                            theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            if (!done) ...[
              // ⭐ 중요 토글 → 포커스 후보
              if (showStar)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    node.important ? Icons.star : Icons.star_border,
                    size: 20,
                    color: node.important
                        ? theme.textTheme.bodyLarge?.color
                        : theme.textTheme.bodySmall?.color,
                  ),
                  onPressed: () =>
                      repo.setMatrix(node.id, important: !node.important),
                ),
              // 📅 날짜/마감 설정
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.calendar_today_outlined,
                    size: 17, color: theme.textTheme.bodySmall?.color),
                onPressed: () => _pickDate(context, ref),
              ),
            ],
          ],
        ),
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('tile_${node.id}'),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Icon(Icons.check_circle, color: AppColors.done),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete_outline,
            color: Theme.of(context).textTheme.bodySmall?.color),
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          done ? await repo.reopen(node.id) : await repo.complete(node.id);
          return false; // 스트림 갱신에 맡김
        }
        await repo.deleteNode(node.id); // 좌 = 삭제
        return false;
      },
      child: tile,
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(nodeRepoProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: node.date ?? todayDate(),
      firstDate: todayDate(),
      lastDate: todayDate().add(const Duration(days: 365)),
      helpText: '언제까지 할까요?',
      cancelText: '취소',
      confirmText: '설정',
    );
    if (picked != null) {
      await repo.setDate(node.id, picked);
    }
  }
}

class _FocusCard extends ConsumerWidget {
  const _FocusCard({required this.node});
  final Node node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.textTheme.bodyLarge?.color ?? Colors.black,
            width: 1.2),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ref.read(nodeRepoProvider).complete(node.id),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('지금 이것부터', style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(node.title, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "오늘의 승리 · N" 접힌 스택.
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
    if (wins.isEmpty) return const SizedBox.shrink();
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
                const Icon(Icons.check_circle, size: 16, color: AppColors.done),
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
              for (final n in wins) SimpleTile(node: n, showStar: false),
            ],
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
