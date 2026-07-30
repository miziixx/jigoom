import 'package:flutter/material.dart';

import 'theme.dart';

/// 편집형 입력 다이얼로그 — 모노 키커 + Sans 제목 + 언더라인 입력.
/// 반환: 입력값(취소 시 null). (다이얼로그 배경/보더/각짐은 테마가 처리)
Future<String?> showInputDialog(
  BuildContext context, {
  required String title,
  String kicker = 'NEW',
  String hint = '',
  String initial = '',
  String? subtitle,
  String? fieldLabel,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final tk = t(ctx);
      return AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        // 레퍼런스 모달: 브래킷 세리프 제목 + (부제) + (필드 라벨) + 언더라인 입력.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('[ $title ]', style: AppText.hTitle(tk.ink)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: AppText.meta(tk.inkSoft, size: 12)),
            ],
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fieldLabel != null) ...[
              Text(fieldLabel, style: AppText.meta(tk.inkSoft, size: 10)),
              const SizedBox(height: 8),
            ],
            TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          style: AppText.body(tk.ink),
          cursorColor: tk.mark,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: AppText.meta(tk.inkSoft, size: 13),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: tk.line)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: tk.ink, width: 1.5)),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('저장')),
        ],
      );
    },
  );
}

/// 편집형 확인 다이얼로그. danger=true면 확인 버튼 배경 mark.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '확인',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final tk = t(ctx);
      return AlertDialog(
        titlePadding: EdgeInsets.fromLTRB(20, 20, 20, message == null ? 12 : 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        title: Text(title, style: AppText.hTitle(tk.ink)),
        content:
            message == null ? null : Text(message, style: AppText.body(tk.ink)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: tk.mark, foregroundColor: tk.paper)
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return r ?? false;
}
