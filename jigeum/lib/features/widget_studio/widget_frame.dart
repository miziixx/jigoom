import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'studio_live_data.dart';
import 'studio_skin.dart';
import 'studio_tokens.dart';
import 'studio_widget_bodies.dart';
import 'widget_config.dart';

/// ============================================================
/// WIDGET STUDIO — 공용 위젯 프레임(.widget)
///
/// 헤더(키커·메뉴)·본문·리사이즈 핸들·선택 아웃라인과 표면/투명도/선/모서리/
/// 반응형(compact·tiny)을 레퍼런스 CSS 그대로 입힌다. 위치는 상위 Positioned 가
/// 잡고, 이 위젯은 w×h 크기 안쪽의 카드만 그린다.
/// ============================================================
class WidgetFrame extends StatelessWidget {
  const WidgetFrame({
    super.key,
    required this.config,
    required this.skin,
    required this.selected,
    required this.tracker,
    required this.onTrackerDraft,
    required this.onTrackerStart,
    required this.onTrackerStop,
    required this.onSelect,
    required this.onDrag,
    required this.onDragEnd,
    required this.onResize,
    required this.onResizeEnd,
    this.liveData,
    this.liveTick = 0,
  });

  final WidgetConfig config;
  final StudioSkin skin;
  final bool selected;
  final TrackerState tracker;
  final ValueChanged<String> onTrackerDraft;
  final VoidCallback onTrackerStart;
  final VoidCallback onTrackerStop;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onDragEnd;
  final ValueChanged<Offset> onResize;
  final VoidCallback onResizeEnd;
  final StudioLiveData? liveData;
  final int liveTick;

  @override
  Widget build(BuildContext context) {
    final s = skin;
    final headerH = s.isTiny ? 0.0 : (s.isCompact ? 22.0 : 27.0);
    final radius = BorderRadius.circular(config.radius);

    // body padding: normal 5/11/11 · compact 3/7/7 · tiny 7
    final bodyPad = s.isTiny
        ? const EdgeInsets.all(7)
        : (s.isCompact
            ? const EdgeInsets.fromLTRB(7, 3, 7, 7)
            : const EdgeInsets.fromLTRB(11, 5, 11, 11));
    final headerPad = s.isCompact
        ? const EdgeInsets.fromLTRB(7, 5, 7, 0)
        : const EdgeInsets.fromLTRB(10, 7, 10, 0);

    final body = Padding(
      padding: bodyPad,
      child: studioWidgetBody(
        config,
        s,
        tracker: tracker,
        onTrackerDraft: onTrackerDraft,
        onTrackerStart: onTrackerStart,
        onTrackerStop: onTrackerStop,
        data: liveData,
        liveTick: liveTick,
      ),
    );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!s.isTiny)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => onSelect(),
            onPanUpdate: (d) => onDrag(d.delta),
            onPanEnd: (_) => onDragEnd(),
            child: SizedBox(
              height: headerH,
              child: Padding(
                padding: headerPad,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(config.type.kicker,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: s.kicker),
                    ),
                    Text('···',
                        style: TextStyle(
                            fontFamily: StudioFont.sans,
                            fontSize: 13,
                            height: 1,
                            color: s.muted)),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: body),
      ],
    );

    // 표면: transparent 는 배경/그림자 없음. glass 는 backdrop blur.
    final isTransparent = config.surface == StudioSurface.transparent;
    Widget card = ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (config.surface == StudioSurface.glass)
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: StudioFrame.glassBlur, sigmaY: StudioFrame.glassBlur),
              child: const SizedBox.expand(),
            ),
          Positioned.fill(child: ColoredBox(color: s.surfaceColor)),
          column,
        ],
      ),
    );

    // 테두리(line) — transparent 도 CSS 상 border 는 유지되나 배경만 투명.
    card = Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: s.line, width: s.lineWidth),
        boxShadow: isTransparent
            ? null
            : [
                BoxShadow(
                  color: config.surface == StudioSurface.glass
                      ? StudioFrame.glassShadowColor
                      : StudioFrame.shadowColor,
                  blurRadius: config.surface == StudioSurface.glass
                      ? StudioFrame.glassShadowBlur
                      : StudioFrame.shadowBlur,
                  offset: config.surface == StudioSurface.glass
                      ? StudioFrame.glassShadowOffset
                      : StudioFrame.shadowOffset,
                ),
              ],
      ),
      child: card,
    );

    // 탭 선택 + 리사이즈 핸들 + 선택 아웃라인.
    Widget stacked = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onTap: onSelect,
            child: card,
          ),
        ),
        if (selected)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => onSelect(),
              onPanUpdate: (d) => onResize(d.delta),
              onPanEnd: (_) => onResizeEnd(),
              child: SizedBox(
                width: StudioFrame.resizeHandle,
                height: StudioFrame.resizeHandle,
                child: CustomPaint(painter: _ResizeGlyph(s.primary)),
              ),
            ),
          ),
        if (selected)
          Positioned(
            left: -StudioFrame.selectOutlineOffset,
            top: -StudioFrame.selectOutlineOffset,
            right: -StudioFrame.selectOutlineOffset,
            bottom: -StudioFrame.selectOutlineOffset,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: s.primary, width: StudioFrame.selectOutline),
                  borderRadius:
                      BorderRadius.circular(config.radius + StudioFrame.selectOutlineOffset),
                ),
              ),
            ),
          ),
      ],
    );

    // 전체 투명도.
    if (config.opacity < 100) {
      stacked = Opacity(opacity: config.opacity / 100, child: stacked);
    }
    return stacked;
  }
}

/// .resize-handle 의 두 선(회전 -45°, primary 65%).
class _ResizeGlyph extends CustomPainter {
  _ResizeGlyph(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..strokeWidth = 1;
    // before: 9px 선, right:2 bottom:5 ; after: 5px 선, right:2 bottom:9 — 모두 -45°.
    void diag(double lengthPx, double right, double bottom) {
      final cx = size.width - right;
      final cy = size.height - bottom;
      final dx = (lengthPx / 2) * 0.7071;
      canvas.drawLine(
          Offset(cx - dx, cy + dx), Offset(cx + dx, cy - dx), p);
    }

    diag(9, 2 + 4.5, 5 + 0.5);
    diag(5, 2 + 2.5, 9 + 0.5);
  }

  @override
  bool shouldRepaint(_ResizeGlyph old) => old.color != color;
}
