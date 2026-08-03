import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

/// 첫 2분 행동 저장 직후의 선택적 미니 시트 (WOOP 경량화).
/// 필드 2개 — 실행의도(트리거) / 장애물 한 줄. 둘 다 비워도 됨(건너뛰기).
/// goal 노드에 setTriggerAndObstacle 로 저장.
Future<void> showIntentionSheet(
  BuildContext context,
  WidgetRef ref, {
  required String goalId,
  required String goalTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => _IntentionSheet(goalId: goalId, goalTitle: goalTitle),
  );
}

class _IntentionSheet extends ConsumerStatefulWidget {
  const _IntentionSheet({required this.goalId, required this.goalTitle});
  final String goalId;
  final String goalTitle;

  @override
  ConsumerState<_IntentionSheet> createState() => _IntentionSheetState();
}

class _IntentionSheetState extends ConsumerState<_IntentionSheet> {
  final _trigger = TextEditingController();
  final _obstacle = TextEditingController();

  @override
  void dispose() {
    _trigger.dispose();
    _obstacle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(nodeRepoProvider).setTriggerAndObstacle(
          widget.goalId,
          _trigger.text,
          _obstacle.text,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
          Text('언제 시작할까요', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('정해두면 훨씬 쉽게 시작해요. 비워둬도 괜찮아요.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),

          Text('시작 신호', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          TextField(
            controller: _trigger,
            autofocus: true,
            textInputAction: TextInputAction.next,
            style: theme.textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: '예: 저녁 먹고 나면 · 출근 지하철에서',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6))),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),

          Text('망칠 위험', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          TextField(
            controller: _obstacle,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            style: theme.textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: '예: 눕고 싶어질 때 · 폰 먼저 볼 때',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6))),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('건너뛰기', style: theme.textTheme.bodySmall),
              ),
              const Spacer(),
              FilledButton(onPressed: _save, child: const Text('저장')),
            ],
          ),
        ],
      ),
    );
  }
}
