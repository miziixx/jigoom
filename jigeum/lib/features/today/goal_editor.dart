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
        // 레퍼런스 v17 .modal — padding 18 · 제목 18 · 부제 9.
        titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        contentPadding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
        actionsPadding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('[ 오늘의 목표 ]',
                style: AppText.hTitle(tk.ink).copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text('이루고 싶은 결과를 짧게, 한 줄에 하나씩.',
                style: AppText.meta(tk.inkSoft, size: 9)),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: tk.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: tk.ink, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(
              style: _goalDlgBtn,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          FilledButton(
              style: _goalDlgBtn,
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

/// 레퍼런스 v17 .btn — min-height 37 · radius 2 · 컴팩트 폰트(12).
final ButtonStyle _goalDlgBtn = TextButton.styleFrom(
  minimumSize: const Size(0, 37),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
);

/// 여러 줄 목표 문자열 정규화 — 각 줄 trim, 빈 줄 제거, 개행으로 재결합.
String normalizeGoals(String raw) => raw
    .split('\n')
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty)
    .join('\n');
