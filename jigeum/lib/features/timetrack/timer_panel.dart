import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/editorial.dart';
import '../../core/journal.dart';
import '../../core/reference_tokens.dart';
import '../../core/theme.dart';
import '../../providers.dart';

/// 진행 중 타이머 패널 — 여러 작업을 동시에 기록한다(리디자인 시안 '지금 진행 중').
/// 앱을 켜 둔 동안만 흐르는 정직한 실시간 경과(가짜 시계 없음). 각 타이머는
/// [ActiveTimer.startedAt] 기준 실경과를 매초 HH:MM:SS 로 갱신하고, 각자 정지한다.
class TimerPanel extends StatelessWidget {
  const TimerPanel({super.key, this.padded = true});

  /// true 면 좌우/상하 여백을 준다(시간·기록 탭). 오늘 화면처럼 바깥에서 여백을
  /// 주는 경우 false.
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ActiveTimer>>(
      valueListenable: activeTimersNotifier,
      builder: (context, timers, _) {
        final tk = t(context);
        final pad = padded
            ? const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 2)
            : EdgeInsets.zero;
        return Padding(
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (timers.isEmpty)
                _idle(context, tk)
              else ...[
                for (var i = 0; i < timers.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == timers.length - 1 ? 0 : 9),
                    child: _running(tk, timers[i], primary: i == 0),
                  ),
                const SizedBox(height: 9),
                _addRow(context, tk),
              ],
            ],
          ),
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

  // 진행 중 한 줄 — 실시간 시계 + 제목 + 정지. 첫 번째는 강조(대표 몰입).
  Widget _running(AppTokens tk, ActiveTimer timer, {required bool primary}) =>
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: primary ? mixOver(tk.mark, 0.12, tk.paper) : tk.paper2,
          border: primary ? null : Border.all(color: tk.line),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 11),
              decoration: BoxDecoration(shape: BoxShape.circle, color: tk.mark),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(timer.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(tk.ink).copyWith(fontSize: 13.5)),
                  const SizedBox(height: 3),
                  Text('${primary ? '몰입 · ' : ''}${_started(timer.startedAt)} 시작',
                      style: AppText.meta(tk.inkSoft, size: 9)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _LiveClock(startedAt: timer.startedAt, color: tk.mark),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => stopActiveTimer(timer.id),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, border: Border.all(color: tk.line)),
                child: Text('❚❚', style: AppText.meta(tk.mark, size: 9)),
              ),
            ),
          ],
        ),
      );

  Widget _addRow(BuildContext context, AppTokens tk) => GestureDetector(
        onTap: () => _start(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tk.line),
          ),
          child: Text('＋ 새로 기록 시작', style: AppText.meta(tk.inkSoft, size: 11)),
        ),
      );

  static String _started(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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

  // 제목을 받아 지금부터 타이머 시작(목록에 추가).
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
            Text('무엇을 재시작할까요', style: AppText.serif(tk.ink, size: 17)),
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
    startActiveTimer(trimmed);
  }
}

/// 실시간 시계 — [startedAt] 기준 실제 경과를 매초 다시 그린다.
class _LiveClock extends StatefulWidget {
  const _LiveClock({required this.startedAt, required this.color});
  final DateTime startedAt;
  final Color color;

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
        style: AppText.meta(widget.color, size: 15)
            .copyWith(fontWeight: FontWeight.w500));
  }
}
