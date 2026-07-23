import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/dialogs.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../focus/focus_timer_view.dart';

/// "막혔어" 시트 — 판단·죄책감 없이 다음 한 걸음을 아주 작게 제안.
/// ADHD의 진짜 장벽은 '시작'이라, 더 작게 쪼개거나 부담 없이 미루는 탈출구를 준다.
Future<void> showStuckSheet(BuildContext context, WidgetRef ref, Node node) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => _StuckSheet(node: node),
  );
}

class _StuckSheet extends ConsumerWidget {
  const _StuckSheet({required this.node});
  final Node node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    return Container(
      color: tk.paper,
      padding: EdgeInsets.only(
        left: kGutter,
        right: kGutter,
        top: 18,
        bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('막혔어도 괜찮아요',
              style: AppText.meta(tk.inkSoft, size: 10)
                  .copyWith(letterSpacing: 1.4)),
          const SizedBox(height: 6),
          Container(height: 1, color: tk.ink),
          const SizedBox(height: 14),
          Text(node.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(tk.ink)),
          const SizedBox(height: 4),
          Text('시작이 안 될 땐, 더 작게 쪼개면 돼요.',
              style: AppText.meta(tk.inkSoft, size: 12)),
          const SizedBox(height: 16),
          _option(
            context,
            glyph: '▷',
            title: '딱 1분만 열어보기',
            sub: '완성 말고, 그냥 손만 대보기',
            onTap: () {
              Navigator.of(context).pop();
              openFocusTimer(context, node: node, autoStartMinutes: 1);
            },
          ),
          _option(
            context,
            glyph: '·',
            title: '다음 한 걸음만 정하기',
            sub: '지금 할 딱 하나를 적어두기',
            onTap: () async {
              final v = await showInputDialog(context,
                  title: '다음 한 걸음', kicker: 'NEXT', hint: '예: 파일 열기');
              if (v == null) return;
              await ref
                  .read(nodeRepoProvider)
                  .setNextStep(node.id, v.trim().isEmpty ? null : v.trim());
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          _option(
            context,
            glyph: '→',
            title: '오늘은 쉬고 내일로',
            sub: '미뤄도 괜찮아요. 벌점 없어요',
            onTap: () async {
              await ref.read(nodeRepoProvider).pushToTomorrow(node.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _option(BuildContext context,
      {required String glyph,
      required String title,
      required String sub,
      required VoidCallback onTap}) {
    final tk = t(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tk.line)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 22,
                child: Text(glyph, style: AppText.glyph(tk.mark, size: 15))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body(tk.ink)),
                  const SizedBox(height: 2),
                  Text(sub, style: AppText.meta(tk.inkSoft)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
