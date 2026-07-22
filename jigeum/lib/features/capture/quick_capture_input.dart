import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../providers.dart';

/// 위젯 탭 진입용 빠른 담기 입력창(모달) — 앱 에디토리얼 톤.
///
/// 포커스·매트릭스 위젯을 누르면 앱 홈이 아니라 이 입력창만 바로 뜬다.
/// 텍스트 + 중요/긴급 분류 → 오늘 할 일로 담긴다(매트릭스 사분면 반영).
Future<void> showQuickCaptureInput(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  var important = false;
  var urgent = false;

  Future<void> submit(BuildContext ctx) async {
    final text = controller.text.trim();
    if (text.isNotEmpty) {
      await ref.read(nodeRepoProvider).create(
            type: NodeType.task,
            title: text,
            important: important,
            urgent: urgent,
            date: todayDate(),
          );
    }
    if (ctx.mounted) Navigator.of(ctx).pop();
  }

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) {
      final tk = t(ctx);
      return StatefulBuilder(
        builder: (ctx, setState) {
          Widget chip(String label, bool selected, VoidCallback onTap,
              {bool mark = false}) {
            final fill = mark ? tk.mark : tk.ink;
            return GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? fill : Colors.transparent,
                  border: Border.all(
                      color: selected ? fill : tk.line, width: 1),
                ),
                child: Text(label,
                    style: AppText.chip(selected ? tk.paper : tk.inkSoft)),
              ),
            );
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              decoration: BoxDecoration(
                color: tk.paper,
                border: Border.all(color: tk.ink, width: 1),
              ),
              padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 마스트헤드
                  Text('빠르게 담기',
                      style: AppText.meta(tk.inkSoft, size: 10)
                          .copyWith(letterSpacing: 1.4)),
                  const SizedBox(height: 6),
                  Container(height: 1, color: tk.ink),
                  const SizedBox(height: 14),
                  // 프롬프트 줄
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 2),
                        child:
                            Text('›', style: AppText.glyph(tk.mark, size: 16)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => submit(ctx),
                          cursorColor: tk.mark,
                          style: AppText.body(tk.ink),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '무엇을 담을까요_',
                            hintStyle: AppText.meta(tk.inkSoft, size: 12),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 분류 칩
                  Row(
                    children: [
                      chip('중요', important,
                          () => setState(() => important = !important)),
                      const SizedBox(width: 8),
                      chip('긴급', urgent,
                          () => setState(() => urgent = !urgent),
                          mark: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 액션
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Text('취소',
                              style: AppText.nav(tk.inkSoft)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => submit(ctx),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          color: tk.ink,
                          child: Text('담기',
                              style: AppText.nav(tk.paper, active: true)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
