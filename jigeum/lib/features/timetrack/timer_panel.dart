import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/editorial.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../providers.dart';

/// 진행 중 타이머 패널 — 기준 HTML `.timer-panel.new-timer`.
/// 앱을 켜 둔 동안만 흐르는 정직한 실시간 경과(가짜 시계 없음).
/// 대기 상태에선 '타이머 시작' 카드, 진행 중이면 HH:MM:SS 를 매초 갱신한다.
class TimerPanel extends StatelessWidget {
  const TimerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActiveTimer?>(
      valueListenable: activeTimerNotifier,
      builder: (context, timer, _) {
        final tk = t(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 2),
          child: timer == null ? _idle(context, tk) : _running(context, tk, timer),
        );
      },
    );
  }

  // 대기 — 탭하면 제목을 받아 타이머를 시작한다.
  Widget _idle(BuildContext context, AppTokens tk) => GestureDetector(
        onTap: () => _start(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: tk.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('타이머', style: AppText.meta(tk.inkSoft, size: 8)),
                    const SizedBox(height: 6),
                    Text('00:00:00',
                        style: AppText.meta(tk.inkSoft, size: 32)
                            .copyWith(fontWeight: FontWeight.w300, height: 1)),
                    const SizedBox(height: 5),
                    Text('탭해서 지금 하는 일을 재기 시작',
                        style: AppText.body(tk.inkSoft).copyWith(fontSize: 9)),
                  ],
                ),
              ),
              _roundBtn(tk, '▶'),
            ],
          ),
        ),
      );

  // 진행 중 — 실시간 시계 + 제목 + 정지 버튼.
  Widget _running(BuildContext context, AppTokens tk, ActiveTimer timer) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tk.paper2,
          border: Border.all(color: tk.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('진행 중', style: AppText.meta(tk.mark, size: 8)),
                  const SizedBox(height: 6),
                  _LiveClock(startedAt: timer.startedAt, tk: tk),
                  const SizedBox(height: 5),
                  Text(timer.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(tk.inkSoft).copyWith(fontSize: 9)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => activeTimerNotifier.value = null,
              behavior: HitTestBehavior.opaque,
              child: _roundBtn(tk, 'Ⅱ'),
            ),
          ],
        ),
      );

  // .round-btn — 48×48 원, 라인 강조 테두리.
  Widget _roundBtn(AppTokens tk, String glyph) => Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tk.paper,
          border: Border.all(color: tk.ink),
        ),
        child: Text(glyph, style: AppText.glyph(tk.mark, size: 15)),
      );

  // 제목을 받아 지금부터 타이머 시작.
  Future<void> _start(BuildContext context) async {
    final controller = TextEditingController();
    final title = await showEditorialSheet<String>(
      context,
      scrollable: false,
      builder: (ctx) {
        final tk = t(ctx);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('무엇을 재시작할까요',
                style: AppText.serif(tk.ink, size: 17)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
              style: AppText.body(tk.ink),
              cursorColor: tk.mark,
              decoration: InputDecoration(
                isDense: true,
                hintText: '지금 하는 일',
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
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: EdButton(
                    label: '취소',
                    filled: false,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: EdButton(
                    label: '시작',
                    onTap: () => Navigator.of(ctx).pop(controller.text),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    final trimmed = (title ?? '').trim();
    if (trimmed.isEmpty) return;
    activeTimerNotifier.value = ActiveTimer(trimmed, DateTime.now());
  }
}

/// 실시간 시계 — [startedAt] 기준 실제 경과를 매초 다시 그린다.
/// 화면이 살아있는 동안만 틱하고, 사라지면 타이머를 정리한다.
class _LiveClock extends StatefulWidget {
  const _LiveClock({required this.startedAt, required this.tk});
  final DateTime startedAt;
  final AppTokens tk;

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _2(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    final s = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
    final text = '${_2(s ~/ 3600)}:${_2((s % 3600) ~/ 60)}:${_2(s % 60)}';
    return Text(text,
        style: AppText.meta(widget.tk.ink, size: 32)
            .copyWith(fontWeight: FontWeight.w300, height: 1));
  }
}
