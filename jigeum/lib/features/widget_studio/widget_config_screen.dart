import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'studio_skin.dart';
import 'studio_tokens.dart';
import 'studio_widget_channel.dart';
import 'widget_config.dart';
import 'widget_frame.dart';

/// ============================================================
/// 홈 위젯 구성 화면(§11 → 위젯 1개 설정용)
///
/// 홈 화면에 위젯을 얹을 때 뜨는 설정 페이지. 위젯 종류·크기·테마·표면·
/// 투명도를 고르면 실시간 미리보기가 갱신되고, '홈에 추가'를 누르면 이
/// 미리보기를 그대로 PNG 로 캡처해 네이티브가 실제 홈 위젯으로 표시한다.
/// (레퍼런스 디자인을 픽셀 그대로 홈 화면에 올리기 위한 render→image 방식.)
/// ============================================================
class WidgetConfigScreen extends StatefulWidget {
  const WidgetConfigScreen({super.key});

  @override
  State<WidgetConfigScreen> createState() => _WidgetConfigScreenState();
}

class _WidgetConfigScreenState extends State<WidgetConfigScreen> {
  final GlobalKey _previewKey = GlobalKey();

  StudioWidgetType _type = StudioWidgetType.clock;
  String _themeKey = 'sage';
  StudioSurface _surface = StudioSurface.glass;
  StudioCalView _view = StudioCalView.month;
  Size _size = kDefaultWidgetSizes[StudioWidgetType.clock]!;
  double _opacity = 100;
  bool _busy = false;

  StudioTheme get _theme => StudioTheme.byKey(_themeKey);

  WidgetConfig get _config => WidgetConfig(
        id: 'preview',
        type: _type,
        title: _type.label,
        x: 0,
        y: 0,
        width: _size.width,
        height: _size.height,
        zIndex: 0,
        view: _type == StudioWidgetType.calendar ? _view : null,
        theme: _themeKey,
        surface: _surface,
        opacity: _opacity,
      );

  void _pickType(StudioWidgetType t) {
    setState(() {
      _type = t;
      _size = kDefaultWidgetSizes[t]!;
    });
  }

  Future<void> _addToHome() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _busy = false);
        return;
      }
      // 홈 위젯 이미지 — RemoteViews setImageViewBitmap 전송 한도(≈1MB)를 넘지
      // 않게 가장 긴 변을 512px 로 제한해 배율 계산.
      final longest = math.max(_size.width, _size.height);
      final ratio = (512 / longest).clamp(1.0, 3.0);
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) {
        setState(() => _busy = false);
        return;
      }
      final ok = await StudioWidgetChannel.commit(
        png: data.buffer.asUint8List(),
        widthPx: (_size.width * ratio).round(),
        heightPx: (_size.height * ratio).round(),
      );
      // 성공 시 네이티브가 액티비티를 종료(setResult OK). 실패면 안내.
      if (!ok && mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위젯 추가에 실패했어요. 다시 시도해 주세요.')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.ink),
          onPressed: () async {
            final nav = Navigator.of(context);
            await StudioWidgetChannel.cancel();
            nav.maybePop();
          },
        ),
        title: Text('위젯 추가',
            style: TextStyle(
                fontFamily: StudioFont.serif, fontSize: 17, color: theme.ink)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.7),
          child: Container(height: 0.7, color: theme.line),
        ),
      ),
      body: Column(
        children: [
          // 미리보기 — 배경 위에 실제 위젯 프레임.
          Expanded(
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [theme.wallA, theme.wallB],
                ),
              ),
              padding: const EdgeInsets.all(20),
              // FittedBox 로 큰 미리보기를 화면 폭에 맞춰 축소만(캡처는 논리 크기
              // 기준이라 해상도 손실 없음).
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: _size.width,
                  height: _size.height,
                  child: RepaintBoundary(
                    key: _previewKey,
                    child: WidgetFrame(
                      config: _config,
                      skin: StudioSkin(_config, theme),
                      selected: false,
                      tracker: const TrackerState(),
                      onTrackerDraft: (_) {},
                      onTrackerStart: () {},
                      onTrackerStop: () {},
                      onSelect: () {},
                      onDrag: (_) {},
                      onDragEnd: () {},
                      onResize: (_) {},
                      onResizeEnd: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 컨트롤 패널.
          Container(
            decoration: BoxDecoration(
              color: theme.surface,
              border: Border(top: BorderSide(color: theme.line, width: 0.7)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _row('종류', _typeDropdown(theme)),
                    if (_type == StudioWidgetType.calendar)
                      _row('화면', _viewTabs(theme)),
                    _row('크기', _sizeChips(theme)),
                    _row('테마', _themeDropdown(theme)),
                    _row('표면', _surfaceDropdown(theme)),
                    _row('투명도', _opacitySlider(theme)),
                    const SizedBox(height: 8),
                    _addButton(theme),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 컨트롤 조각 ---------------------------------------------------------

  Widget _row(String label, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              child: Text(label,
                  style: TextStyle(
                      fontFamily: StudioFont.mono,
                      fontFamilyFallback: StudioFont.monoFallback,
                      fontSize: 10,
                      letterSpacing: 1,
                      color: _theme.muted)),
            ),
            Expanded(child: child),
          ],
        ),
      );

  Widget _typeDropdown(StudioTheme theme) => _boxed(
        theme,
        DropdownButtonHideUnderline(
          child: DropdownButton<StudioWidgetType>(
            value: _type,
            isExpanded: true,
            isDense: true,
            dropdownColor: theme.surface,
            style: TextStyle(
                fontFamily: StudioFont.sans, fontSize: 13, color: theme.ink),
            items: [
              for (final t in StudioWidgetType.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (t) => t == null ? null : _pickType(t),
          ),
        ),
      );

  Widget _themeDropdown(StudioTheme theme) => _boxed(
        theme,
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _themeKey,
            isExpanded: true,
            isDense: true,
            dropdownColor: theme.surface,
            style: TextStyle(
                fontFamily: StudioFont.sans, fontSize: 13, color: theme.ink),
            items: [
              for (final t in StudioTheme.all)
                DropdownMenuItem(value: t.key, child: Text(t.label)),
            ],
            onChanged: (k) =>
                k == null ? null : setState(() => _themeKey = k),
          ),
        ),
      );

  Widget _surfaceDropdown(StudioTheme theme) => _boxed(
        theme,
        DropdownButtonHideUnderline(
          child: DropdownButton<StudioSurface>(
            value: _surface,
            isExpanded: true,
            isDense: true,
            dropdownColor: theme.surface,
            style: TextStyle(
                fontFamily: StudioFont.sans, fontSize: 13, color: theme.ink),
            items: const [
              DropdownMenuItem(value: StudioSurface.glass, child: Text('유리·반투명')),
              DropdownMenuItem(value: StudioSurface.paper, child: Text('종이')),
              DropdownMenuItem(value: StudioSurface.solid, child: Text('불투명')),
              DropdownMenuItem(
                  value: StudioSurface.transparent, child: Text('완전 투명')),
            ],
            onChanged: (s) =>
                s == null ? null : setState(() => _surface = s),
          ),
        ),
      );

  Widget _viewTabs(StudioTheme theme) => Row(
        children: [
          for (final v in StudioCalView.values)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _view = v),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: _view == v ? theme.primary : theme.line,
                            width: 0.7)),
                  ),
                  child: Text(v.name.toUpperCase(),
                      style: TextStyle(
                          fontFamily: StudioFont.mono,
                          fontFamilyFallback: StudioFont.monoFallback,
                          fontSize: 9,
                          color: _view == v ? theme.primary : theme.ink)),
                ),
              ),
            ),
        ],
      );

  Widget _sizeChips(StudioTheme theme) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final p in kSizePresets)
            GestureDetector(
              onTap: () => setState(() => _size = p.size),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: _size == p.size ? theme.primary : theme.line,
                      width: _size == p.size ? 1.4 : 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(p.label,
                    style: TextStyle(
                        fontFamily: StudioFont.mono,
                        fontFamilyFallback: StudioFont.monoFallback,
                        fontSize: 9,
                        color: _size == p.size ? theme.primary : theme.ink)),
              ),
            ),
        ],
      );

  Widget _opacitySlider(StudioTheme theme) => SliderTheme(
        data: SliderThemeData(
          activeTrackColor: theme.primary,
          inactiveTrackColor: theme.line,
          thumbColor: theme.primary,
          trackHeight: 2,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        ),
        child: Slider(
          value: _opacity,
          min: 20,
          max: 100,
          onChanged: (v) => setState(() => _opacity = v),
        ),
      );

  Widget _addButton(StudioTheme theme) => GestureDetector(
        onTap: _busy ? null : _addToHome,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _busy ? theme.muted : theme.ink,
            borderRadius: BorderRadius.circular(6),
          ),
          child: _busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: theme.surface))
              : Text('홈 화면에 추가',
                  style: TextStyle(
                      fontFamily: StudioFont.sans,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.surface)),
        ),
      );

  Widget _boxed(StudioTheme theme, Widget child) => Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.line, width: 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: child,
      );
}

/// 구성 액티비티 전용 최상위 앱(경량 — DB/알림 초기화 없음).
class WidgetConfigApp extends StatelessWidget {
  const WidgetConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WidgetConfigScreen(),
    );
  }
}
