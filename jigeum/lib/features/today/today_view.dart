import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import 'node_detail_sheet.dart';

/// 오늘 뷰 (홈) — 편집(에디토리얼) 목차형.
/// 큰 날짜(Sans) → NOW(포커스) → TO-DO → DONE, 규칙선으로 구분. 카드 없음.
class TodayView extends ConsumerStatefulWidget {
  const TodayView({super.key});

  @override
  ConsumerState<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends ConsumerState<TodayView> {
  bool _winsOpen = false;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final focus = ref.watch(focusProvider);
    final today = ref.watch(todayNodesProvider).valueOrNull ?? const [];
    final wins = ref.watch(todayWinsProvider).valueOrNull ?? const [];
    final now = DateTime.now();

    final children = <Widget>[
      // 큰 날짜 (Sans) + 요일 (Mono meta)
      Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(DateFormat('M월 d일', 'ko').format(now),
                style: AppText.hTitle(tk.ink)),
            const SizedBox(width: 10),
            Text(DateFormat('EEEE', 'ko').format(now),
                style: AppText.meta(tk.inkSoft)),
          ],
        ),
      ),

      // NOW — 지금 이것부터
      focus.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (node) => node == null
            ? const SizedBox.shrink()
            : _FocusBlock(node: node),
      ),

      // TO-DO
      SectionLabel('TO-DO', count: today.length),
      if (today.isEmpty)
        emptyNote(context, '아래 프롬프트에 적으면 여기 쌓여요')
      else
        for (final n in today) SimpleTile(node: n),

      // DONE (오늘의 승리)
      if (wins.isNotEmpty) ...[
        SectionLabel(
          'DONE',
          count: wins.length,
          onTap: () => setState(() => _winsOpen = !_winsOpen),
          trailing: Text(_winsOpen ? '−' : '+',
              style: AppText.meta(tk.inkSoft, size: 13)),
        ),
        if (_winsOpen)
          for (final n in wins) SimpleTile(node: n),
      ],

      const SizedBox(height: 16),
    ];

    return Container(
      color: tk.paper,
      child: ListView(
        padding: EdgeInsets.zero,
        children: children,
      ),
    );
  }
}

/// 포커스 블록 — 카드가 아니라 라벨 + 규칙선 + 한 줄. mark 캐럿으로 강조.
class _FocusBlock extends ConsumerWidget {
  const _FocusBlock({required this.node});
  final Node node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 26, kGutter, 12),
          child: Row(
            children: [
              Text('› NOW',
                  style: AppText.sec(tk.mark)),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 1, color: tk.line)),
            ],
          ),
        ),
        InkWell(
          onTap: () => showNodeDetailSheet(context, node),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlyphCheck(
                  done: false,
                  onTap: () => ref.read(nodeRepoProvider).complete(node.id),
                ),
                Expanded(
                  child: Text(node.title, style: AppText.body(tk.ink)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 편집형 할 일 줄: 글리프 체크 · 제목(한글 Sans) · 메타(메모/마감) · 우선순위 라벨.
/// 완료 = 글리프 ■ + 제목 inkSoft + 취소선. 스와이프 우=완료, 좌=삭제.
class SimpleTile extends ConsumerWidget {
  const SimpleTile({super.key, required this.node, this.showStar = true});

  final Node node;
  final bool showStar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final repo = ref.read(nodeRepoProvider);
    final done = node.status == NodeStatus.done;
    final showDeadline =
        node.date != null && node.date != todayDate() && !done;
    final pri = done
        ? null
        : priorityLabel(context,
            urgent: node.urgent, important: node.important);

    final tile = InkWell(
      onTap: () => showNodeDetailSheet(context, node),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 11, kGutter, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlyphCheck(
              done: done,
              onTap: () =>
                  done ? repo.reopen(node.id) : repo.complete(node.id),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.title,
                      style: AppText.body(done ? tk.inkSoft : tk.ink).copyWith(
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          decorationColor: tk.inkSoft),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (node.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(node.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.meta(tk.inkSoft)),
                    ),
                ],
              ),
            ),
            if (showDeadline) ...[
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: deadlineLabel(context, node.date!),
              ),
            ],
            if (pri != null) ...[
              const SizedBox(width: 10),
              Padding(padding: const EdgeInsets.only(top: 2), child: pri),
            ],
          ],
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('tile_${node.id}'),
      background: _swipeBg(tk, Alignment.centerLeft, done ? '□' : '■'),
      secondaryBackground: _swipeBg(tk, Alignment.centerRight, '×'),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          done ? await repo.reopen(node.id) : await repo.complete(node.id);
          return false;
        }
        await repo.deleteNode(node.id);
        return false;
      },
      child: tile,
    );
  }

  Widget _swipeBg(AppTokens tk, Alignment align, String glyph) => Container(
        alignment: align,
        color: tk.paper2,
        padding: const EdgeInsets.symmetric(horizontal: kGutter),
        child: Text(glyph, style: AppText.glyph(tk.inkSoft, size: 16)),
      );
}
