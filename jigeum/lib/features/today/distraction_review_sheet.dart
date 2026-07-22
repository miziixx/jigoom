import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';

/// 집중 세션 종료 후, 그 세션 중 담아둔 방해요소(생각)들을 정리하는 시트.
/// 항목별 지금 처리(→ 오늘 할 일) / 일정 지정(→ 날짜) / 삭제.
Future<void> showDistractionReviewSheet(
  BuildContext context,
  List<Node> distractions,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => _DistractionReviewSheet(initial: distractions),
  );
}

class _DistractionReviewSheet extends ConsumerStatefulWidget {
  const _DistractionReviewSheet({required this.initial});
  final List<Node> initial;

  @override
  ConsumerState<_DistractionReviewSheet> createState() =>
      _DistractionReviewSheetState();
}

class _DistractionReviewSheetState
    extends ConsumerState<_DistractionReviewSheet> {
  late final List<Node> _items = [...widget.initial];

  void _remove(String id) {
    setState(() => _items.removeWhere((n) => n.id == id));
  }

  Future<void> _doNow(Node n) async {
    final repo = ref.read(nodeRepoProvider);
    await repo.setType(n.id, NodeType.task);
    await repo.setMatrix(n.id, important: true); // 오늘 할 일로 노출
    _remove(n.id);
  }

  Future<void> _schedule(Node n) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: todayDate().add(const Duration(days: 1)),
      firstDate: todayDate(),
      lastDate: todayDate().add(const Duration(days: 730)),
      helpText: '언제 할까요?',
      cancelText: '취소',
      confirmText: '설정',
    );
    if (picked == null) return;
    final repo = ref.read(nodeRepoProvider);
    await repo.setType(n.id, NodeType.task);
    await repo.setDate(n.id, picked);
    _remove(n.id);
  }

  Future<void> _delete(Node n) async {
    await ref.read(nodeRepoProvider).deleteNode(n.id);
    _remove(n.id);
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('보관함', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('집중하는 동안 담아둔 생각들 — 지금 정리해요',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),

          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('— 다 정리했어요', style: AppText.meta(tk.inkSoft)),
            )
          else
            ..._items.map((n) => _row(context, n)),

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_items.isEmpty ? '닫기' : '나중에'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Node n) {
    final tk = t(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Text('·', style: AppText.glyph(tk.inkSoft, size: 14)),
              ),
              Expanded(
                child: Text(n.title, style: AppText.body(tk.ink)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _action(context, '지금 처리', () => _doNow(n), strong: true),
                _action(context, '일정 지정', () => _schedule(n)),
                _action(context, '삭제', () => _delete(n)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, String label, VoidCallback onTap,
      {bool strong = false}) {
    final tk = t(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: strong ? tk.ink : Colors.transparent,
          border: Border.all(color: strong ? tk.ink : tk.line, width: 1),
        ),
        child: Text(label, style: AppText.chip(strong ? tk.paper : tk.inkSoft)),
      ),
    );
  }
}
