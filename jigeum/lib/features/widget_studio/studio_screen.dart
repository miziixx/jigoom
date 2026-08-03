import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'studio_controller.dart';
import 'studio_inspector.dart';
import 'studio_live_data.dart';
import 'studio_skin.dart';
import 'studio_tokens.dart';
import 'widget_config.dart';
import 'widget_frame.dart';

/// ============================================================
/// WIDGET STUDIO — 편집기 화면(§11)
///
/// 레퍼런스 3-패널(카탈로그·캔버스·인스펙터)을 모바일에 맞게 재배치:
/// 가운데 배경화면 캔버스는 그대로 두고, 왼쪽 카탈로그/전체 테마와 오른쪽
/// 인스펙터는 바텀시트로 연다. 컴포넌트의 시각 값은 레퍼런스와 동일.
/// ============================================================
class WidgetStudioScreen extends ConsumerStatefulWidget {
  const WidgetStudioScreen({super.key});

  @override
  ConsumerState<WidgetStudioScreen> createState() => _WidgetStudioScreenState();
}

class _WidgetStudioScreenState extends ConsumerState<WidgetStudioScreen> {
  Timer? _ticker;
  int _liveTick = 0;
  bool _didFit = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final running = ref
          .read(studioControllerProvider)
          .trackers
          .values
          .any((t) => t.running);
      if (running && mounted) setState(() => _liveTick++);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(studioControllerProvider);
    final ctrl = ref.read(studioControllerProvider.notifier);
    final theme = StudioTheme.byKey(session.studio.globalTheme);
    final canvas = session.canvas;

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.ink),
              ),
              child: Text('J',
                  style: TextStyle(
                      fontFamily: StudioFont.serif, fontSize: 16, color: theme.ink)),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WIDGET EDITOR',
                    style: TextStyle(
                        fontFamily: StudioFont.mono,
                        fontFamilyFallback: StudioFont.monoFallback,
                        fontSize: 8,
                        letterSpacing: 1.2,
                        color: theme.muted)),
                Text('지금 위젯 스튜디오',
                    style: TextStyle(
                        fontFamily: StudioFont.serif,
                        fontSize: 16,
                        color: theme.ink)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '그리드',
            onPressed: ctrl.toggleGrid,
            icon: Icon(Icons.grid_4x4,
                size: 18, color: session.grid ? theme.primary : theme.muted),
          ),
          PopupMenuButton<String>(
            iconColor: theme.ink,
            color: theme.surface,
            onSelected: (v) async {
              if (v == 'reset') {
                final ok = await _confirmReset(theme);
                if (ok) {
                  ctrl.resetLayout();
                  _toast('초기 배치로 되돌렸어요');
                }
              } else if (v == 'export') {
                await Clipboard.setData(ClipboardData(text: ctrl.exportJson()));
                _toast('위젯 설정 JSON을 복사했어요');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'reset', child: Text('초기화')),
              const PopupMenuItem(value: 'export', child: Text('설정 내보내기')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () {
                ctrl.saveNow();
                _toast('위젯 배치를 저장했어요');
              },
              style: TextButton.styleFrom(
                backgroundColor: theme.ink,
                foregroundColor: theme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: Text('저장',
                  style: TextStyle(
                      fontFamily: StudioFont.sans,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.surface)),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.7, color: theme.line),
        ),
      ),
      body: LayoutBuilder(builder: (context, box) {
        if (!_didFit) {
          _didFit = true;
          final fit = ((box.maxWidth - 32) / canvas.width).clamp(0.65, 1.0);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && (session.zoom - 1.0).abs() < 0.001) ctrl.setZoom(fit);
          });
        }
        return Column(
          children: [
            _toolbar(session, ctrl, theme, canvas),
            Expanded(child: _stage(session, ctrl, theme, canvas)),
          ],
        );
      }),
      bottomNavigationBar: _bottomBar(session, theme),
    );
  }

  // --- 툴바 (디바이스 전환 + 줌) --------------------------------------------

  Widget _toolbar(StudioSession session, StudioController ctrl, StudioTheme theme,
      Size canvas) {
    Widget mini(String label, bool active, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                  color: active ? theme.primary : theme.line, width: 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label,
                style: TextStyle(
                    fontFamily: StudioFont.mono,
                    fontFamilyFallback: StudioFont.monoFallback,
                    fontSize: 8,
                    color: active ? theme.primary : theme.muted)),
          ),
        );

    return Container(
      color: theme.bg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            mini('390 × 844', !session.studio.largeCanvas,
                () => ctrl.setLargeCanvas(false)),
            const SizedBox(width: 5),
            mini('430 × 932', session.studio.largeCanvas,
                () => ctrl.setLargeCanvas(true)),
          ]),
          Row(children: [
            Text('PREVIEW',
                style: TextStyle(
                    fontFamily: StudioFont.mono,
                    fontFamilyFallback: StudioFont.monoFallback,
                    fontSize: 8,
                    color: theme.muted)),
            const SizedBox(width: 6),
            mini('－', false, () => ctrl.setZoom(session.zoom - 0.1)),
            const SizedBox(width: 6),
            SizedBox(
              width: 34,
              child: Text('${(session.zoom * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: StudioFont.mono,
                      fontFamilyFallback: StudioFont.monoFallback,
                      fontSize: 8,
                      color: theme.muted)),
            ),
            mini('＋', false, () => ctrl.setZoom(session.zoom + 0.1)),
          ]),
        ],
      ),
    );
  }

  // --- 스테이지 (배경화면 캔버스) -------------------------------------------

  Widget _stage(StudioSession session, StudioController ctrl, StudioTheme theme,
      Size canvas) {
    // 실제 앱 데이터(할 일·습관·목표·오늘 일정) — 스트림 변경 시 위젯 즉시 갱신.
    final live = ref.watch(studioLiveDataProvider);
    final zoom = session.zoom;
    final scaledW = canvas.width * zoom;
    final scaledH = canvas.height * zoom;

    final canvasStack = SizedBox(
      width: canvas.width,
      height: canvas.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ctrl.select(null), // 빈 곳 탭 → 선택 해제
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 배경 그라디언트
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(StudioCanvas.radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [theme.wallA, Color.lerp(theme.wallA, theme.wallB, 0.55)!, theme.wallB],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
            // 상단 하이라이트
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(StudioCanvas.radius),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x2EFFFFFF), Color(0x00FFFFFF)],
                      stops: [0, 0.25],
                    ),
                  ),
                ),
              ),
            ),
            // 그리드
            if (session.grid)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(StudioCanvas.radius),
                    child: CustomPaint(painter: _GridPainter()),
                  ),
                ),
              ),
            // 위젯들 (z 순)
            for (final w in _sorted(session.widgets))
              Positioned(
                left: w.x,
                top: w.y,
                width: w.width,
                height: w.height,
                child: WidgetFrame(
                  config: w,
                  skin: StudioSkin(w, ctrl.themeFor(w)),
                  selected: session.selectedId == w.id,
                  tracker: session.trackerFor(w.id),
                  liveData: live,
                  liveTick: _liveTick,
                  onTrackerDraft: (v) => ctrl.trackerDraft(w.id, v),
                  onTrackerStart: () {
                    if (!ctrl.trackerStart(w.id)) {
                      _toast('기록할 일을 먼저 적어주세요');
                    } else {
                      _toast('타임트래커를 시작했어요');
                    }
                  },
                  onTrackerStop: () {
                    ctrl.trackerStop(w.id);
                    _toast('시간 기록을 저장했어요');
                  },
                  onSelect: () => ctrl.select(w.id),
                  onDrag: (delta) => _dragWidget(ctrl, w.id, delta),
                  onDragEnd: ctrl.commit,
                  onResize: (delta) => _resizeWidget(ctrl, w.id, delta),
                  onResizeEnd: ctrl.commit,
                ),
              ),
          ],
        ),
      ),
    );

    // 스케일 후 스크롤(세로 우선, 필요 시 가로).
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _phoneShell(
                child: SizedBox(
                  width: scaledW,
                  height: scaledH,
                  // FittedBox 로 캔버스(canvas.width×height)를 zoom 배율로 스케일.
                  // 자식 GestureDetector 의 delta 는 이미 로컬(미스케일) 좌표라
                  // 드래그·리사이즈에서 zoom 을 다시 나누지 않는다.
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: canvasStack,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// .wallpaper-shell — 기기 베젤(짙은 카드 + 큰 라운드 + 그림자).
  Widget _phoneShell({required Widget child}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF232421),
          borderRadius: BorderRadius.circular(42),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1A252723), blurRadius: 60, offset: Offset(0, 20)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(StudioCanvas.radius),
          child: child,
        ),
      );

  List<WidgetConfig> _sorted(List<WidgetConfig> ws) {
    final list = [...ws]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return list;
  }

  // delta 는 FittedBox 내부(캔버스 로컬 좌표)에서 온 값 → 그대로 누적.
  void _dragWidget(StudioController ctrl, String id, Offset delta) {
    final cur =
        ref.read(studioControllerProvider).widgets.firstWhere((e) => e.id == id);
    ctrl.moveTo(id, cur.x + delta.dx, cur.y + delta.dy);
  }

  void _resizeWidget(StudioController ctrl, String id, Offset delta) {
    final cur =
        ref.read(studioControllerProvider).widgets.firstWhere((e) => e.id == id);
    ctrl.resizeTo(id, cur.width + delta.dx, cur.height + delta.dy);
  }

  // --- 하단 바 (카탈로그 · 테마 · 속성) -------------------------------------

  Widget _bottomBar(StudioSession session, StudioTheme theme) {
    Widget btn(String label, IconData icon, VoidCallback? onTap, {bool accent = false}) {
      final enabled = onTap != null;
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 18,
                    color: !enabled
                        ? theme.muted.withValues(alpha: 0.4)
                        : (accent ? theme.primary : theme.ink)),
                const SizedBox(height: 3),
                Text(label,
                    style: TextStyle(
                        fontFamily: StudioFont.mono,
                        fontFamilyFallback: StudioFont.monoFallback,
                        fontSize: 8,
                        color: !enabled ? theme.muted.withValues(alpha: 0.4) : theme.ink)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.line, width: 0.7)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            btn('위젯 추가', Icons.add_box_outlined, () => _openCatalog(theme)),
            btn('테마', Icons.palette_outlined, () => _openThemes(theme)),
            btn('속성', Icons.tune,
                session.selected != null ? () => _openInspector(theme) : null,
                accent: session.selected != null),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmReset(StudioTheme theme) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: theme.surface,
            title: const Text('초기화'),
            content: const Text('위젯 배치를 처음 상태로 되돌릴까요?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('되돌리기')),
            ],
          ),
        ) ??
        false;
  }

  // --- 시트: 카탈로그 -------------------------------------------------------

  void _openCatalog(StudioTheme theme) {
    final ctrl = ref.read(studioControllerProvider.notifier);
    const items = <(StudioWidgetType, String)>[
      (StudioWidgetType.clock, '시간·날짜'),
      (StudioWidgetType.calendar, '일·주·월 전환'),
      (StudioWidgetType.goal, '진행률 포함'),
      (StudioWidgetType.tracker, '기록·빈 시간'),
      (StudioWidgetType.tasks, '체크리스트'),
      (StudioWidgetType.habits, '연속 기록'),
      (StudioWidgetType.matrix, '아이젠하워'),
      (StudioWidgetType.capture, '할 일·일정·기록'),
      (StudioWidgetType.fortune, '행동 카드'),
    ];
    _sheet(theme, '위젯 추가', 'CATALOG', (ctx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ctrl.addWidget(items[i].$1);
                Navigator.pop(ctx);
                _toast('${items[i].$1.label} 위젯을 추가했어요');
              },
              child: Container(
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: theme.line, width: 0.7))),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                        width: 29,
                        child: Text((i + 1).toString().padLeft(2, '0'),
                            style: TextStyle(
                                fontFamily: StudioFont.mono,
                                fontFamilyFallback: StudioFont.monoFallback,
                                fontSize: 8,
                                color: theme.muted))),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[i].$1.label,
                              style: TextStyle(
                                  fontFamily: StudioFont.sans,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.ink)),
                          const SizedBox(height: 3),
                          Text(items[i].$2,
                              style: TextStyle(
                                  fontFamily: StudioFont.sans,
                                  fontSize: 8,
                                  color: theme.muted)),
                        ],
                      ),
                    ),
                    Text('＋',
                        style: TextStyle(
                            fontFamily: StudioFont.sans,
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            color: theme.primary)),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }

  // --- 시트: 전체 테마 ------------------------------------------------------

  void _openThemes(StudioTheme theme) {
    final ctrl = ref.read(studioControllerProvider.notifier);
    _sheet(theme, '전체 테마', 'THEME', (ctx) {
      return Consumer(builder: (context, ref2, _) {
        final active = ref2.watch(studioControllerProvider).studio.globalTheme;
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          mainAxisSpacing: 7,
          crossAxisSpacing: 7,
          childAspectRatio: 2.4,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final t in StudioTheme.all)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ctrl.setGlobalTheme(t.key),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: t.key == active ? t.primary : theme.line,
                        width: t.key == active ? 1.4 : 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Row(children: [
                            Expanded(child: ColoredBox(color: t.surface)),
                            Expanded(child: ColoredBox(color: t.ink)),
                            Expanded(child: ColoredBox(color: t.primary)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(t.label,
                          style: TextStyle(
                              fontFamily: StudioFont.mono,
                              fontFamilyFallback: StudioFont.monoFallback,
                              fontSize: 7,
                              letterSpacing: 0.42,
                              color: theme.muted)),
                    ],
                  ),
                ),
              ),
          ],
        );
      });
    });
  }

  // --- 시트: 인스펙터 -------------------------------------------------------

  void _openInspector(StudioTheme theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: StudioInspector(panel: inspectorPalette(theme)),
        ),
      ),
    );
  }

  void _sheet(StudioTheme theme, String title, String kicker,
      Widget Function(BuildContext) body) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: theme.line, width: 0.7))),
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontFamily: StudioFont.serif,
                            fontSize: 18,
                            color: theme.ink)),
                    Text(kicker,
                        style: TextStyle(
                            fontFamily: StudioFont.mono,
                            fontFamilyFallback: StudioFont.monoFallback,
                            fontSize: 8,
                            letterSpacing: 1.0,
                            color: theme.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              Flexible(
                child: SingleChildScrollView(child: body(ctx)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 24px 반복 그리드(opacity .13).
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF6F746F).withValues(alpha: 0.13)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += StudioCanvas.gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += StudioCanvas.gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
