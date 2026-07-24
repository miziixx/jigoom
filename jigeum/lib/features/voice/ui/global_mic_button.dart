/// 전역 마이크 버튼. 기획서 §9 진입점 + 커밋10.
///
/// ⚠️ 위젯 레이어 — 이 환경(Flutter 없음)에서 컴파일 검증 못 함. 기기 확인 필요.
/// 탭 → 듣는 중 표시 → 자동 종료(최종 결과) → [VoiceController.handle] → 스낵바.
///
/// AppShell 어딘가(FAB 또는 마스트헤드)에 얹어 어느 화면에서나 접근하게 한다.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../stt_service.dart';
import '../voice_controller.dart';
import 'voice_feedback.dart';

class GlobalMicButton extends StatefulWidget {
  const GlobalMicButton({
    super.key,
    required this.stt,
    required this.controller,
  });

  final SttService stt;
  final VoiceController controller;

  @override
  State<GlobalMicButton> createState() => _GlobalMicButtonState();
}

class _GlobalMicButtonState extends State<GlobalMicButton> {
  StreamSubscription<SttStatus>? _statusSub;
  StreamSubscription<SttResult>? _resultSub;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _statusSub = widget.stt.status.listen((s) {
      if (mounted) setState(() => _listening = s == SttStatus.listening);
    });
    _resultSub = widget.stt.results.listen(_onResult);
  }

  Future<void> _onResult(SttResult r) async {
    if (!r.isFinal || r.text.trim().isEmpty) return;
    final fb = await widget.controller
        .handle(r.text, sttConfidence: r.confidence);
    if (!mounted) return;
    showVoiceFeedback(
      context,
      fb,
      onUndo: () => widget.controller.undo(),
      onReclassify: (route) async {
        final fb2 = await widget.controller.reclassifyLast(route);
        if (mounted) {
          showVoiceFeedback(context, fb2,
              onUndo: () => widget.controller.undo());
        }
      },
    );
  }

  Future<void> _tap() async {
    if (_listening) {
      await widget.stt.stop();
      return;
    }
    if (!await widget.stt.requestPermission()) return;
    if (!await widget.stt.isAvailable()) return;
    await widget.stt.start();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _resultSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return FloatingActionButton(
      onPressed: _tap,
      backgroundColor: _listening ? t.mark : t.ink,
      tooltip: _listening ? '듣는 중… (탭하면 종료)' : '말로 담기',
      child: Icon(_listening ? Icons.mic : Icons.mic_none, color: t.paper),
    );
  }
}
