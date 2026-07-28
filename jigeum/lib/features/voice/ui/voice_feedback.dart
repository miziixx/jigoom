/// 확정 피드백 스낵바. 기획서 §9 + §11-4 + 커밋10.
///
/// ⚠️ 위젯 레이어 — 이 환경(Flutter 없음)에서 컴파일 검증 못 함. 기기에서
/// `flutter analyze`/실행으로 확인 필요. 오케스트레이션 로직은 [VoiceController]
/// (검증됨)에 있고, 여기는 그 모델을 렌더링만 한다.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../models/intent_type.dart';
import '../voice_controller.dart';

/// "○○에 담았어요 [되돌리기]" + §11-4 "다르게 담기" 칩을 스낵바로 띄운다.
void showVoiceFeedback(
  BuildContext context,
  VoiceFeedback fb, {
  VoidCallback? onUndo,
  void Function(RoutePoint route)? onReclassify,
}) {
  final t = Theme.of(context).extension<AppTokens>()!;
  final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.ink,
      duration: const Duration(seconds: 4),
      content: Row(
        children: [
          Expanded(child: Text(fb.message, style: AppText.body(t.paper))),
          for (final route in fb.reclassifyTo)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _Chip(
                label: route.label,
                color: t.paper,
                onTap: () {
                  messenger.hideCurrentSnackBar();
                  onReclassify?.call(route);
                },
              ),
            ),
          if (fb.undoable)
            TextButton(
              onPressed: () {
                messenger.hideCurrentSnackBar();
                onUndo?.call();
              },
              child: Text('되돌리기', style: AppText.meta(t.mark)),
            ),
        ],
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label, style: AppText.meta(color)),
        ),
      );
}
