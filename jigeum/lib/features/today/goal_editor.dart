import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../widgetkit/widget_bridge.dart';

/// 오늘의 목표(여러 개) 편집 — 한 줄에 목표 하나.
/// 저장 시 빈 줄을 걸러 개행으로 이어 dayGoal 에 쓰고 홈 위젯에 반영한다.
/// TODAY 뷰와 위젯(목표 위젯) 양쪽에서 재사용한다.
/// 저장된 정규화 문자열을 반환(취소 시 null).
Future<String?> showGoalEditor(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(scheduleRepoProvider);
  final current = (await repo.getDayGoal(todayDate()))?.trim() ?? '';
  if (!context.mounted) return null;

  final controller = TextEditingController(text: current);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final tk = t(ctx);
      return AlertDialog(
        backgroundColor: tk.paper,
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('GOAL', style: AppText.sec(tk.inkSoft)),
            const SizedBox(height: 6),
            Text('오늘의 목표', style: AppText.hTitle(tk.ink)),
            const SizedBox(height: 2),
            Text('한 줄에 하나씩', style: AppText.meta(tk.inkSoft, size: 12)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: AppText.body(tk.ink),
          cursorColor: tk.mark,
          decoration: InputDecoration(
            isDense: true,
            hintText: '오늘 이루고 싶은 것',
            hintStyle: AppText.meta(tk.inkSoft, size: 13),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: tk.line)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: tk.ink, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('저장')),
        ],
      );
    },
  );

  if (result == null) return null;
  final normalized = normalizeGoals(result);
  await repo.setDayGoal(todayDate(), normalized);
  await WidgetBridge.updateGoal(normalized);
  return normalized;
}

/// 여러 줄 목표 문자열 정규화 — 각 줄 trim, 빈 줄 제거, 개행으로 재결합.
String normalizeGoals(String raw) => raw
    .split('\n')
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty)
    .join('\n');
