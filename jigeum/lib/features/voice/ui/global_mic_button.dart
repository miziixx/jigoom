/// 전역 마이크 버튼. 기획서 §9 진입점 + 커밋10.
///
/// ⚠️ 위젯 레이어 — 이 환경(Flutter 없음)에서 컴파일 검증 못 함. 기기 확인 필요.
/// 탭 → 듣는 중 표시 → 자동 종료(최종 결과) → [VoiceController.handle] → 스낵바.
///
/// AppShell 어딘가(FAB 또는 마스트헤드)에 얹어 어느 화면에서나 접근하게 한다.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  StreamSubscription<String>? _errorSub;
  bool _listening = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _statusSub = widget.stt.status.listen((s) {
      if (!mounted) return;
      setState(() => _listening = s == SttStatus.listening);
    });
    _resultSub = widget.stt.results.listen(_onResult);
    // 인식 실패를 조용히 삼키지 않고 사람이 읽을 메시지로 띄운다.
    _errorSub = widget.stt.errors.listen(_onError);
  }

  void _onError(String message) {
    if (!mounted) return;
    final t = Theme.of(context).extension<AppTokens>()!;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.mark,
        content: Text('🎙️ $message', style: AppText.body(t.paper)),
      ));
  }

  void _showNotice(String message) => _onError(message);

  Future<void> _onResult(SttResult r) async {
    if (!r.isFinal || r.text.trim().isEmpty) return;
    final fb =
        await widget.controller.handle(r.text, sttConfidence: r.confidence);
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
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_listening) {
        await widget.stt.stop();
        return;
      }
      final available = await widget.stt.isAvailable();
      if (!available) {
        _showNotice('이 기기에서 음성 인식을 찾지 못했어요. Google 앱/음성 입력을 확인해 주세요.');
        return;
      }
      final allowed = await widget.stt.requestPermission();
      if (!allowed) {
        _showNotice('마이크 권한이 꺼져 있어요. 앱 권한에서 마이크를 허용해 주세요.');
        return;
      }
      await widget.stt.start(localeId: 'ko_KR');
    } on MissingPluginException {
      _showNotice('이 환경에서는 음성 인식을 쓸 수 없어요. 안드로이드 앱에서 실행해 주세요.');
    } on PlatformException catch (e) {
      _showNotice(e.message ?? '음성 인식을 시작하지 못했어요.');
    } catch (_) {
      _showNotice('음성 인식을 시작하지 못했어요. 잠시 뒤 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _resultSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          child: _listening
              ? Container(
                  key: const ValueKey('voice-listening-label'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: t.ink,
                    border: Border.all(color: t.paper.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('듣는 중', style: AppText.meta(t.paper, size: 11)),
                )
              : const SizedBox.shrink(),
        ),
        if (_listening) const SizedBox(height: 6),
        FloatingActionButton.small(
          onPressed: _busy ? null : _tap,
          backgroundColor: _listening ? t.mark : t.ink,
          tooltip: _listening ? '듣는 중. 탭하면 종료' : '말로 담기',
          child: Icon(_listening ? Icons.mic : Icons.mic_none, color: t.paper),
        ),
      ],
    );
  }
}
