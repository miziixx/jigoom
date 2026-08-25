/// 완료 기록 화면 — 기준 HTML `data-screen="completed"`.
///
/// ⚠️ 위젯 레이어 — 이 환경(Flutter 없음)에서 컴파일 검증 못 함. 기기 확인 필요.
/// 완료(status=done)된 할 일을 thread-list(채운 노드 · 이름 · 시각 · "완료")로
/// 최근 완료순 표시. 데이터는 allNodesProvider(검증됨) 재사용.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../shell/app_bottom_nav.dart';

class CompletedScreen extends ConsumerWidget {
  const CompletedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final all = ref.watch(allNodesProvider).valueOrNull ?? const <Node>[];
    final done = all
        .where((n) => n.type == NodeType.task && n.status == NodeStatus.done)
        .toList()
      ..sort((a, b) {
        final ad = a.doneAt ?? a.createdAt;
        final bd = b.doneAt ?? b.createdAt;
        return bd.compareTo(ad); // 최근 완료 먼저
      });

    return Scaffold(
      backgroundColor: tk.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Masthead(
              eyebrow: 'COMPLETED',
              title: '완료 기록',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: done.isEmpty
                  ? emptyStateBear(context, '완료한 일이 없어요')
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: done.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: tk.line),
                      itemBuilder: (_, i) => _row(tk, done[i]),
                    ),
            ),
            const AppBottomNav(showQuickAdd: false),
          ],
        ),
      ),
    );
  }

  // 기준 HTML .thread-item — 채운 노드 · 이름 · 시각(desc) · 우측 "완료".
  Widget _row(AppTokens tk, Node n) {
    final meta = <String>[
      _when(n.doneAt),
      if (n.note.isNotEmpty) n.note,
    ].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // node filled — 채운 작은 노드.
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(shape: BoxShape.circle, color: tk.inkSoft),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(tk.ink)),
                if (meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta(tk.inkSoft, size: 10)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('완료', style: AppText.meta(tk.inkSoft, size: 9)),
        ],
      ),
    );
  }

  String _when(DateTime? dt) {
    if (dt == null) return '';
    final d = dateOnly(dt);
    final today = todayDate();
    final diff = today.difference(d).inDays;
    final hm = DateFormat('HH:mm').format(dt);
    if (diff == 0) return '오늘 $hm';
    if (diff == 1) return '어제 $hm';
    return '${DateFormat('M월 d일').format(dt)} $hm';
  }
}
