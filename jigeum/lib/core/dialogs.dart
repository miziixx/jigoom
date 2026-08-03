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
  String saveLabel = '저장',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final tk = t(ctx);
      return AlertDialog(
        // 레퍼런스 v17 .modal — padding 18.
        titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        contentPadding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
        actionsPadding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
        // 레퍼런스 모달: 브래킷 제목(18) + (부제 9) + (필드 라벨 8) + 박스 입력.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 레퍼런스 .modal h3(18) — 대괄호는 포인트색, 제목은 잉크.
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: '[ ', style: AppText.hTitle(tk.mark).copyWith(fontSize: 18)),
              TextSpan(
                  text: title, style: AppText.hTitle(tk.ink).copyWith(fontSize: 18)),
              TextSpan(
                  text: ' ]', style: AppText.hTitle(tk.mark).copyWith(fontSize: 18)),
            ])),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: AppText.meta(tk.inkSoft, size: 9)),
            ],
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fieldLabel != null) ...[
              Text(fieldLabel, style: AppText.meta(tk.inkSoft, size: 8)),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            hintText: hint,
            hintStyle: AppText.meta(tk.inkSoft, size: 13),
            // 레퍼런스 .field input — 박스(line 테두리) + radius 6.
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: tk.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: tk.ink, width: 1.5)),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
          ],
        ),
        actions: [
          TextButton(
              style: _dlgTextBtn,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          FilledButton(
              style: _dlgFilledBtn,
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(saveLabel)),
        ],
      );
    },
  );
}

/// 레퍼런스 v17 .btn — min-height 37 · radius 2 · 컴팩트 폰트(12).
final ButtonStyle _dlgFilledBtn = FilledButton.styleFrom(
  minimumSize: const Size(0, 37),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
);
final ButtonStyle _dlgTextBtn = TextButton.styleFrom(
  minimumSize: const Size(0, 37),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
);

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
        // 레퍼런스 v17 .modal — padding 18.
        titlePadding: EdgeInsets.fromLTRB(18, 18, 18, message == null ? 10 : 8),
        contentPadding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
        actionsPadding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
        title: Text.rich(TextSpan(children: [
          TextSpan(
              text: '[ ', style: AppText.hTitle(tk.mark).copyWith(fontSize: 18)),
          TextSpan(
              text: title, style: AppText.hTitle(tk.ink).copyWith(fontSize: 18)),
          TextSpan(
              text: ' ]', style: AppText.hTitle(tk.mark).copyWith(fontSize: 18)),
        ])),
        content:
            message == null ? null : Text(message, style: AppText.body(tk.ink)),
        actions: [
          TextButton(
              style: _dlgTextBtn,
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          FilledButton(
            style: danger
                ? _dlgFilledBtn.merge(FilledButton.styleFrom(
                    backgroundColor: tk.mark, foregroundColor: tk.paper))
                : _dlgFilledBtn,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return r ?? false;
}
