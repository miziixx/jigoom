import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../providers.dart';

/// 목표 생성 직후 "첫 2분 행동" 강제 입력 바텀시트 (규칙 5).
/// 자식 task 1개 생성. 건너뛰기 버튼은 있되 작게.
Future<void> showTwoMinuteSheet(
  BuildContext context,
  WidgetRef ref, {
  required String goalId,
  required String goalTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (ctx) => _TwoMinuteSheet(goalId: goalId, goalTitle: goalTitle),
  );
}

class _TwoMinuteSheet extends ConsumerStatefulWidget {
  const _TwoMinuteSheet({required this.goalId, required this.goalTitle});
  final String goalId;
  final String goalTitle;

  @override
  ConsumerState<_TwoMinuteSheet> createState() => _TwoMinuteSheetState();
}

class _TwoMinuteSheetState extends ConsumerState<_TwoMinuteSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await ref.read(nodeRepoProvider).create(
          parentId: widget.goalId,
          type: NodeType.task,
          title: text,
          important: true, // 첫 행동은 중요로 시작
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
          Text('첫 2분 행동', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('“${widget.goalTitle}”을(를) 위해 지금 2분 안에 할 수 있는 한 가지',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            style: theme.textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: '예: 관련 폴더 하나 만들기',
              border: UnderlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('건너뛰기',
                    style: theme.textTheme.bodySmall),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _save,
                child: const Text('추가'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
