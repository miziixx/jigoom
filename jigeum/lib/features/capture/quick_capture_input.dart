import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../providers.dart';

/// 위젯 탭 진입용 빠른 담기 입력창(모달).
///
/// 포커스·매트릭스 위젯을 누르면 앱 홈이 아니라 이 입력창만 바로 뜬다.
/// 텍스트 + 중요/긴급 분류 → 오늘 할 일로 담긴다(매트릭스 사분면 반영).
Future<void> showQuickCaptureInput(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  var important = false;
  var urgent = false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('빠르게 담기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: '무엇을 담을까요?'),
              onSubmitted: (_) => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                FilterChip(
                  label: const Text('중요'),
                  selected: important,
                  onSelected: (v) => setState(() => important = v),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('긴급'),
                  selected: urgent,
                  onSelected: (v) => setState(() => urgent = v),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('담기'),
          ),
        ],
      ),
    ),
  );

  final text = controller.text.trim();
  if (saved == true && text.isNotEmpty) {
    await ref.read(nodeRepoProvider).create(
          type: NodeType.task,
          title: text,
          important: important,
          urgent: urgent,
          date: todayDate(),
        );
  }
}
