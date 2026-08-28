import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/almanac.dart';
import '../../core/constants.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import 'widget_bridge.dart';

/// 잠금화면 배경 만들기 — 이번 달 달력을 배경 이미지로 "구워서" 잠금화면 배경으로 설정.
/// 안드로이드/갤럭시는 잠금화면에 앱 위젯을 못 올려서, 달력을 이미지로 렌더해
/// WallpaperManager(FLAG_LOCK)로 굽는 방식. 실시간 갱신은 안 되고, 다시 만들면 갱신.
class LockWallpaperScreen extends ConsumerStatefulWidget {
  const LockWallpaperScreen({super.key});

  @override
  ConsumerState<LockWallpaperScreen> createState() =>
      _LockWallpaperScreenState();
}

class _LockWallpaperScreenState extends ConsumerState<LockWallpaperScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  String? _bgPath;
  bool _busy = false;
  List<Schedule> _scheds = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final today = todayDate();
    final first = DateTime(today.year, today.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday % 7));
    final gridEnd = gridStart.add(const Duration(days: 41));
    try {
      final s =
          await ref.read(scheduleRepoProvider).rangeOverlap(gridStart, gridEnd);
      if (mounted) setState(() => _scheds = s);
    } catch (_) {}
  }

  Future<void> _pickBg() async {
    final path = await WidgetBridge.pickImage();
    if (path != null && mounted) setState(() => _bgPath = path);
  }

  Future<void> _apply() async {
    setState(() => _busy = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _busy = false);
        return;
      }
      final ratio = MediaQuery.of(context).devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) {
        setState(() => _busy = false);
        return;
      }
      final ok =
          await WidgetBridge.setLockWallpaper(data.buffer.asUint8List());
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '잠금화면 배경으로 설정했어요.' : '설정에 실패했어요. 다시 시도해 주세요.'),
      ));
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final tk = settings.themeKey == kCustomThemeKey
        ? settings.customTokens
        : tokensForKey(settings.themeKey);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 잠금화면에 구워질 실제 이미지(버튼 제외).
          Positioned.fill(
            child: RepaintBoundary(
              key: _boundaryKey,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _background(tk),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          18, size.height * 0.15, 18, 0),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          height: size.height * 0.44,
                          child: _LockCalendar(tokens: tk, scheds: _scheds),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 상단 닫기.
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          // 하단 컨트롤.
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '달력을 이 사진 위에 얹어 잠금화면 배경으로 만듭니다.\n일정이 바뀌면 다시 만들어 주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : _pickBg,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('사진 고르기'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : _apply,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.black),
                                  )
                                : const Text('잠금화면으로 설정'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _background(AppTokens tk) {
    if (_bgPath != null) {
      return Image.file(File(_bgPath!), fit: BoxFit.cover);
    }
    // 사진 미선택 시 테마 톤 그라데이션.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tk.paper2, tk.paper],
        ),
      ),
    );
  }
}

/// 잠금화면용 달력(위젯과 같은 디자인) — Flutter 로 렌더해 이미지로 캡처.
class _LockCalendar extends StatelessWidget {
  const _LockCalendar({required this.tokens, required this.scheds});
  final AppTokens tokens;
  final List<Schedule> scheds;

  static const _pastel = [
    Color(0xFFEFDDA0),
    Color(0xFFF1C79E),
    Color(0xFFEFA6C0),
    Color(0xFFAEC6E4),
    Color(0xFFBBD3A6),
    Color(0xFFC7BEDD),
  ];

  @override
  Widget build(BuildContext context) {
    final tk = tokens;
    final today = todayDate();
    final first = DateTime(today.year, today.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday % 7));
    int idxOf(DateTime d) =>
        DateTime(d.year, d.month, d.day).difference(gridStart).inDays;
    final todayIdx = idxOf(today);

    // 레인 배정(겹침 없이 같은 레인 유지) — main.dart 와 동일 규칙.
    final sorted = [...scheds]..sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        final c = a.date.compareTo(b.date);
        if (c != 0) return c;
        return a.startMin.compareTo(b.startMin);
      });
    final occ = List.generate(42, (_) => List<bool>.filled(3, false));
    final grid = List.generate(42, (_) => List<List<dynamic>?>.filled(3, null));
    for (final s in sorted) {
      final endD = s.endDate ?? s.date;
      var sIdx = idxOf(s.date);
      var eIdx = idxOf(endD);
      if (eIdx < 0 || sIdx > 41) continue;
      if (sIdx < 0) sIdx = 0;
      if (eIdx > 41) eIdx = 41;
      var lane = -1;
      for (var l = 0; l < 3; l++) {
        var free = true;
        for (var d = sIdx; d <= eIdx; d++) {
          if (occ[d][l]) {
            free = false;
            break;
          }
        }
        if (free) {
          lane = l;
          break;
        }
      }
      if (lane < 0) continue;
      final ci = (s.color > 0 ? s.color : s.title.hashCode).abs() % 6;
      for (var d = sIdx; d <= eIdx; d++) {
        occ[d][lane] = true;
        final int style;
        if (!s.allDay) {
          style = 4;
        } else if (sIdx == eIdx) {
          style = 0;
        } else if (d == sIdx) {
          style = 1;
        } else if (d == eIdx) {
          style = 3;
        } else {
          style = 2;
        }
        final showTitle = d == sIdx || d % 7 == 0 || !s.allDay;
        grid[d][lane] = <dynamic>[showTitle ? s.title : '', ci, style];
      }
    }

    final month = today.month;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤더.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('‹',
                style: TextStyle(color: tk.inkSoft, fontSize: 18)),
            const SizedBox(width: 10),
            Text('$month월',
                style: TextStyle(
                    color: tk.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            Text('›', style: TextStyle(color: tk.inkSoft, fontSize: 18)),
            const Spacer(),
            Text('✎  ＋  ',
                style: TextStyle(color: tk.inkSoft, fontSize: 15)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: tk.inkSoft.withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${today.day}',
                  style: TextStyle(color: tk.mark, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 요일.
        Row(
          children: [
            const SizedBox(width: 16),
            for (final e in const [
              ['일', 0xFFC0645A],
              ['월', 0xFF9A948A],
              ['화', 0xFF9A948A],
              ['수', 0xFF9A948A],
              ['목', 0xFF9A948A],
              ['금', 0xFF9A948A],
              ['토', 0xFF5F7DA0],
            ])
              Expanded(
                child: Center(
                  child: Text(e[0] as String,
                      style: TextStyle(
                          color: Color(e[1] as int), fontSize: 11)),
                ),
              ),
          ],
        ),
        // 6주.
        for (var r = 0; r < 6; r++)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 1, color: Colors.white.withValues(alpha: 0.25)),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 16,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            _weekNum(gridStart, r),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: tk.inkSoft, fontSize: 8),
                          ),
                        ),
                      ),
                      for (var c = 0; c < 7; c++)
                        Expanded(
                            child: _cell(tk, gridStart, r * 7 + c, month,
                                todayIdx, grid)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _weekNum(DateTime gridStart, int r) {
    final d = gridStart.add(Duration(days: r * 7));
    // ISO 주차 근사 — 연초부터의 주 index.
    final dayOfYear = d.difference(DateTime(d.year, 1, 1)).inDays;
    return '${(dayOfYear / 7).floor() + 1}';
  }

  Widget _cell(AppTokens tk, DateTime gridStart, int i, int month,
      int todayIdx, List<List<List<dynamic>?>> grid) {
    final date = gridStart.add(Duration(days: i));
    final inMonth = date.month == month;
    final isToday = i == todayIdx;
    final dow = i % 7;
    final numColor = isToday
        ? tk.mark
        : !inMonth
            ? tk.inkSoft
            : dow == 0
                ? const Color(0xFFC0645A)
                : dow == 6
                    ? const Color(0xFF5F7DA0)
                    : tk.ink;
    final showLunar = dow == 0 || isToday;
    final l = lunarOf(date);

    return Container(
      decoration: isToday
          ? BoxDecoration(
              border: Border.all(color: tk.inkSoft.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Text('${date.day}',
                style: TextStyle(color: numColor, fontSize: 12)),
          ),
          if (showLunar)
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Text('${l.month}.${l.day}',
                  style: TextStyle(color: tk.inkSoft, fontSize: 7)),
            ),
          for (var k = 0; k < 3; k++) _slot(tk, grid[i][k]),
        ],
      ),
    );
  }

  Widget _slot(AppTokens tk, List<dynamic>? slot) {
    if (slot == null) return const SizedBox(height: 11);
    final title = slot[0] as String;
    final ci = (slot[1] as int).clamp(0, 5).toInt();
    final style = slot[2] as int;
    if (style == 4) {
      return Padding(
        padding: const EdgeInsets.only(left: 3, top: 1),
        child: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tk.inkSoft, fontSize: 8)),
      );
    }
    final radius = style == 0
        ? BorderRadius.circular(2)
        : style == 1
            ? const BorderRadius.horizontal(left: Radius.circular(2))
            : style == 3
                ? const BorderRadius.horizontal(right: Radius.circular(2))
                : BorderRadius.zero;
    return Container(
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(color: _pastel[ci], borderRadius: radius),
      child: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF33291D), fontSize: 8)),
    );
  }
}
