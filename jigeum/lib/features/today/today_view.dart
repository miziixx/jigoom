import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import 'node_detail_sheet.dart';

/// 오늘 뷰 (홈) — 저널형 타임라인.
/// 페이지 배경 위 큰 날짜 + 포커스 카드, 아래 카드 안에
/// 레일 + [오늘] 배지 + 할 일 + [오늘의 승리] 배지.
class TodayView extends ConsumerStatefulWidget {
  const TodayView({super.key});

  @override
  ConsumerState<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends ConsumerState<TodayView> {
  bool _winsOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focus = ref.watch(focusProvider);
    final today = ref.watch(todayNodesProvider).valueOrNull ?? const [];
    final wins = ref.watch(todayWinsProvider).valueOrNull ?? const [];
    final now = DateTime.now();

    // 카드 안 타임라인 rows.
    final rows = <Widget>[];
    rows.add(Journal.pill(context, '오늘'));
    if (today.isEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.only(left: Journal.rowLeft, bottom: 6),
        child: Text('아래 입력창에 적으면 여기에 쌓여요',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
      ));
    } else {
      for (var i = 0; i < today.length; i++) {
        rows.add(SimpleTile(node: today[i]));
        if (i != today.length - 1) rows.add(Journal.divider(context));
      }
    }

    if (wins.isNotEmpty) {
      rows.add(Journal.pill(
        context,
        '오늘의 승리 · ${wins.length}',
        onTap: () => setState(() => _winsOpen = !_winsOpen),
        trailing: Icon(_winsOpen ? Icons.expand_less : Icons.expand_more,
            size: 12, color: theme.textTheme.bodySmall?.color),
      ));
      if (_winsOpen) {
        for (final n in wins) {
          rows.add(SimpleTile(node: n, showStar: false));
        }
      }
    }

    return Container(
      color: Journal.pageBg(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 큰 날짜 (페이지 배경 위)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('M월 d일', 'ko').format(now),
                    style:
                        theme.textTheme.titleLarge?.copyWith(fontSize: 28)),
                Text(DateFormat('EEEE', 'ko').format(now),
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          // 포커스 카드
          focus.when(
            loading: () => const SizedBox(height: 8),
            error: (_, __) => const SizedBox.shrink(),
            data: (node) => node == null
                ? const SizedBox(height: 8)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: _FocusCard(node: node),
                  ),
          ),
          Expanded(
            child: Journal.card(context,
                child: Journal.timeline(context, rows)),
          ),
        ],
      ),
    );
  }
}

/// 저널형 할 일 타일: 둥근 사각 체크 · 제목 · 메모 미리보기 · 마감 pill · "!"
/// 스와이프 우=완료, 좌=삭제. 탭=상세.
class SimpleTile extends ConsumerWidget {
  const SimpleTile({super.key, required this.node, this.showStar = true});

  final Node node;
  final bool showStar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(nodeRepoProvider);
    final done = node.status == NodeStatus.done;
    final showDeadline =
        node.date != null && node.date != todayDate() && !done;

    final tile = Opacity(
      opacity: done ? 0.45 : 1,
      child: InkWell(
        onTap: () => showNodeDetailSheet(context, node),
        child: Padding(
          padding: const EdgeInsets.only(
              left: Journal.rowLeft, right: 4, top: 7, bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SquareCheck(
                done: done,
                onTap: () =>
                    done ? repo.reopen(node.id) : repo.complete(node.id),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (node.urgent && !done) ...[
                          Icon(Icons.bolt,
                              size: 13,
                              color: theme.textTheme.bodySmall?.color),
                          const SizedBox(width: 2),
                        ],
                        Flexible(
                          child: Text(node.title,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    if (node.note.isNotEmpty)
                      Text(node.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 11)),
                    if (showDeadline)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: deadlinePill(context, node.date!),
                      ),
                  ],
                ),
              ),
              // "!" 중요 토글 → 포커스 후보
              if (!done && showStar)
                GestureDetector(
                  onTap: () =>
                      repo.setMatrix(node.id, important: !node.important),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    child: Text(
                      '!',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        height: 1.2,
                        color: node.important
                            ? theme.textTheme.bodyLarge?.color
                            : (theme.textTheme.bodySmall?.color ??
                                    Colors.grey)
                                .withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
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
}

class _FocusCard extends ConsumerWidget {
  const _FocusCard({required this.node});
  final Node node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.textTheme.bodyLarge?.color ?? Colors.black,
            width: 1.2),
      ),
      child: Row(
        children: [
          SquareCheck(
            done: false,
            size: 20,
            onTap: () => ref.read(nodeRepoProvider).complete(node.id),
          ),
          const SizedBox(width: 4),
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
