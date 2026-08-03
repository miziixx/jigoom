import 'package:flutter/material.dart';

import 'studio_skin.dart';
import 'widget_config.dart';

/// ============================================================
/// WIDGET STUDIO — 타임트래커 본문(§9, 직접 입력형)
///
/// 위젯 안에서 바로 여러 줄 입력 → 기록 시작 → 실시간 타이머 → 기록 종료까지
/// 수행한다. 시작 시각은 [TrackerState.startedAt] 로 영속 저장되고, 화면에는
/// 현재 시각과의 차이로 경과를 계산해 표시한다(재렌더/재시작에도 초기화 안 됨).
/// ============================================================
class TrackerBody extends StatefulWidget {
  const TrackerBody({
    super.key,
    required this.skin,
    required this.state,
    required this.onDraft,
    required this.onStart,
    required this.onStop,
    this.liveTick = 0,
  });

  final StudioSkin skin;
  final TrackerState state;
  final ValueChanged<String> onDraft;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final int liveTick; // 1초 틱 — 실행 중 타이머 갱신 유발.

  @override
  State<TrackerBody> createState() => _TrackerBodyState();
}

class _TrackerBodyState extends State<TrackerBody> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.state.draft);
  }

  @override
  void didUpdateWidget(TrackerBody old) {
    super.didUpdateWidget(old);
    // 외부(종료 후 draft='')에서 바뀌면 컨트롤러 동기화 — 편집 중 커서는 보존.
    if (widget.state.draft != _c.text && widget.state.draft != old.state.draft) {
      _c.value = TextEditingValue(
        text: widget.state.draft,
        selection: TextSelection.collapsed(offset: widget.state.draft.length),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static String _fmt(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${sec.toString().padLeft(2, '0')}s';
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  static String _clock(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  int _elapsed() {
    final st = widget.state;
    if (!st.running || st.startedAt == null) return 0;
    return ((DateTime.now().millisecondsSinceEpoch - st.startedAt!) / 1000)
        .floor();
  }

  void _addLine() {
    final sel = _c.selection;
    final base = sel.baseOffset >= 0 ? sel.baseOffset : _c.text.length;
    final ext = sel.extentOffset >= 0 ? sel.extentOffset : base;
    final start = base < ext ? base : ext;
    final end = base < ext ? ext : base;
    final insertNl = _c.text.isNotEmpty && start > 0;
    final next = _c.text.substring(0, start) +
        (insertNl ? '\n' : '') +
        _c.text.substring(end);
    final caret = start + (insertNl ? 1 : 0);
    _c.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: caret),
    );
    widget.onDraft(next);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.skin;
    final st = widget.state;
    final running = st.running;
    final elapsed = _elapsed();

    final records = st.records;
    final totalSeconds = records.fold<int>(
            0, (a, r) => a + ((r.endedAt - r.startedAt) / 1000).round()) +
        (running ? elapsed : 0);

    // --- 입력 카드(.tracker-entry) ---
    final entry = Container(
      padding: EdgeInsets.all(s.isCompact ? 6 : 8),
      margin: EdgeInsets.only(bottom: s.isTiny ? 0 : (s.isCompact ? 6 : 8)),
      decoration: BoxDecoration(
        color: s.primary.withValues(alpha: 0.08),
        border: s.isTiny
            ? null
            : Border(left: BorderSide(color: s.primary, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!s.isTiny)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('QUICK TRACK', style: s.wMeta),
                      const SizedBox(height: 3),
                      Text(running ? '지금 기록 중' : '바로 시간 기록',
                          style: s.sans(9, weight: FontWeight.w600)),
                    ],
                  ),
                ),
                Text(running ? _fmt(elapsed) : '00:00',
                    style: s.mono(9,
                        color: running ? s.primary : s.muted, letterEm: 0)),
              ],
            ),
          // textarea
          Container(
            margin: EdgeInsets.only(top: s.isTiny ? 0 : 7),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: s.line, width: s.lineWidth),
                bottom: BorderSide(color: s.line, width: s.lineWidth),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: TextField(
              controller: _c,
              onChanged: widget.onDraft,
              maxLines: s.isTiny ? 2 : null,
              minLines: s.isTiny ? 2 : 2,
              cursorColor: s.primary,
              style: s.sans(8, height: 1.45, color: s.ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '지금 하는 일을 적어요.\n여러 작업은 줄바꿈으로 입력',
                hintStyle: s.sans(8, height: 1.45, color: s.muted)
                    .copyWith(color: s.muted.withValues(alpha: 0.68)),
              ),
            ),
          ),
          // actions
          Padding(
            padding: EdgeInsets.only(top: s.isCompact ? 5 : 7),
            child: Row(
              children: [
                if (!s.isTiny) ...[
                  _entryBtn(s, '＋ 작업 줄', _addLine),
                  const SizedBox(width: 6),
                  _micBtn(s),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: _toggleBtn(s, running),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (s.isTiny) return entry;

    // --- 요약 + 기록 목록 ---
    final visibleRecords =
        (s.isCompact ? records.reversed.take(1) : records.reversed.take(3))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        entry,
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TODAY / LOG', style: s.wMeta),
                  Text(_fmt(totalSeconds),
                      style: s.serif(24, color: s.primaryDark, letterEm: -0.01)),
                ],
              ),
            ),
            Text('기록 ${records.length}개', style: s.chip),
          ],
        ),
        const SizedBox(height: 7),
        Container(height: s.lineWidth, color: s.line),
        if (visibleRecords.isEmpty)
          _recordRow(s, null)
        else
          for (final r in visibleRecords) _recordRow(s, r),
      ],
    );
  }

  Widget _recordRow(StudioSkin s, TimeRecord? r) {
    final empty = r == null;
    final durSec = r == null ? 0 : ((r.endedAt - r.startedAt) / 1000).round();
    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: s.line, width: s.lineWidth))),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 35,
            child: Text(empty ? '--:--' : _clock(r.startedAt),
                style: s.mono(6.8, letterEm: 0, height: 1.3)),
          ),
          const SizedBox(width: 7),
          Container(
              width: 2,
              height: 20,
              color: empty ? s.line : s.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(empty ? '아직 기록 없음' : (r.title.isEmpty ? '시간 기록' : r.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: empty
                        ? s.rowStrong.copyWith(
                            color: s.muted, fontWeight: FontWeight.w500)
                        : s.rowStrong),
                if (!empty && r.work.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in r.work)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(children: [
                                TextSpan(text: '— ', style: s.sans(7, color: s.primary)),
                                TextSpan(text: line, style: s.sans(7, color: s.muted)),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (!empty) ...[
                  const SizedBox(height: 3),
                  Text('${_fmt(durSec)} · 작성 ${r.writtenAt != null ? _clock(r.writtenAt!) : _clock(r.endedAt)}',
                      style: s.rowSmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryBtn(StudioSkin s, String label, VoidCallback onTap) {
    return _BtnShell(
      onTap: onTap,
      border: s.line,
      lineWidth: s.lineWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(label,
          style: s.mono(7, color: s.muted, letterEm: 0, weight: FontWeight.w600)),
    );
  }

  Widget _micBtn(StudioSkin s) {
    return _BtnShell(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('실제 앱에서는 음성 입력을 시작합니다')),
      ),
      border: s.line,
      lineWidth: s.lineWidth,
      width: 28,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 13,
        height: 13,
        child: CustomPaint(painter: _MicPainter(s.muted)),
      ),
    );
  }

  Widget _toggleBtn(StudioSkin s, bool running) {
    final bg = running ? s.ink : s.primary;
    return _BtnShell(
      onTap: running ? widget.onStop : widget.onStart,
      border: bg,
      lineWidth: s.lineWidth,
      fill: bg,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Text(running ? '기록 종료' : '기록 시작',
          style: s.mono(7, color: Colors.white, letterEm: 0, weight: FontWeight.w600)),
    );
  }
}

/// 트래커 액션 버튼 공용 셸 — min-height 25, radius 3.
class _BtnShell extends StatelessWidget {
  const _BtnShell({
    required this.onTap,
    required this.child,
    required this.border,
    required this.lineWidth,
    this.fill,
    this.width,
    this.padding = EdgeInsets.zero,
  });

  final VoidCallback onTap;
  final Widget child;
  final Color border;
  final double lineWidth;
  final Color? fill;
  final double? width;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: 25,
        padding: padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: border, width: lineWidth),
          borderRadius: BorderRadius.circular(3),
        ),
        child: child,
      ),
    );
  }
}

/// 얇은 선 마이크 아이콘 (레퍼런스 SVG stroke 1.35, round).
class _MicPainter extends CustomPainter {
  _MicPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final k = size.width / 24; // 24 viewBox → 실제 크기 스케일
    // 캡슐 <rect x=9 y=3 w=6 h=11 rx=3>
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(9 * k, 3 * k, 6 * k, 11 * k),
      Radius.circular(3 * k),
    );
    canvas.drawRRect(rect, p);
    // 아치 M6.5 10.5 a5.5 5.5 0 0 0 11 0
    final arc = Path()
      ..moveTo(6.5 * k, 10.5 * k)
      ..arcToPoint(Offset(17.5 * k, 10.5 * k),
          radius: Radius.circular(5.5 * k), clockwise: false);
    canvas.drawPath(arc, p);
    // 스탠드 M12 16 v4 ; M9 20 h6
    canvas.drawLine(Offset(12 * k, 16 * k), Offset(12 * k, 20 * k), p);
    canvas.drawLine(Offset(9 * k, 20 * k), Offset(15 * k, 20 * k), p);
  }

  @override
  bool shouldRepaint(_MicPainter old) => old.color != color;
}
