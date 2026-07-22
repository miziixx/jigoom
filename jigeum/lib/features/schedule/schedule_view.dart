import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import 'schedule_edit_sheet.dart';
import 'routine_screen.dart';

/// 일과 (하루 일정) — 편집형. 리스트 / 타임라인 / 원형 3보기. 잉크 단색.
class ScheduleView extends ConsumerStatefulWidget {
  const ScheduleView({super.key});

  @override
  ConsumerState<ScheduleView> createState() => ScheduleViewState();
}

class ScheduleViewState extends ConsumerState<ScheduleView> {
  DateTime _date = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);
  int _view = 0; // 0 리스트 · 1 타임라인 · 2 원형

  void addSchedule() => showScheduleEditSheet(context, date: _date);

  void openRoutines() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const RoutineScreen()));

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final items =
        ref.watch(schedulesForDateProvider(_date)).valueOrNull ?? const [];
    final sky = ref.watch(settingsProvider);
    final totalMin = items.fold<int>(
        0, (a, s) => a + (s.endMin - s.startMin).clamp(0, 1440));

    final metaParts = <String>[
      if (sky.showSaju) sajuLabel(_date),
      if (sky.showZodiac) byeoljariLabel(_date),
    ];

    return Container(
      color: tk.paper,
      child: Column(
        children: [
          // 날짜 이동
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 2),
            child: Row(
              children: [
                _navArrow(tk, '‹',
                    () => setState(() =>
                        _date = _date.subtract(const Duration(days: 1)))),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      children: [
                        Text(
                          DateFormat('M월 d일 (E)', 'ko').format(_date),
                          textAlign: TextAlign.center,
                          style: AppText.hTitle(tk.ink),
                        ),
                        if (metaParts.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(metaParts.join(' · '),
                              textAlign: TextAlign.center,
                              style: AppText.metaSans(tk.inkSoft)),
                        ],
                      ],
                    ),
                  ),
                ),
                _navArrow(tk, '›',
                    () => setState(
                        () => _date = _date.add(const Duration(days: 1)))),
              ],
            ),
          ),
          Text('${items.length} EVENTS · ${_hm(totalMin)}',
              style: AppText.meta(tk.inkSoft)),
          const SizedBox(height: 12),
          _viewTabs(tk),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: kGutter),
            height: 1,
            color: tk.line,
          ),
          Expanded(
            child: items.isEmpty
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: emptyNote(context, '+ 로 오늘 일정을 추가해요'),
                    ),
                  )
                : switch (_view) {
                    0 => _ListView(items: items),
                    1 => _TimelineView(items: items),
                    _ => _CircularView(items: items, date: _date),
                  },
          ),
        ],
      ),
    );
  }

  Widget _navArrow(AppTokens tk, String g, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(g, style: AppText.glyph(tk.ink, size: 20)),
        ),
      );

  Widget _viewTabs(AppTokens tk) {
    Widget tab(int i, String label) {
      final sel = _view == i;
      return GestureDetector(
        onTap: () => setState(() => _view = i),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: sel ? tk.ink : Colors.transparent, width: 1.5),
              ),
            ),
            child: Text(label, style: AppText.nav(sel ? tk.ink : tk.inkSoft, active: sel)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 0),
      child: Row(children: [
        tab(0, 'list'),
        tab(1, 'timeline'),
        tab(2, 'clock'),
      ]),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      cancelText: '취소',
      confirmText: '이동',
    );
    if (picked != null) setState(() => _date = picked);
  }

  static String _hm(int m) {
    final h = m ~/ 60;
    final mm = m % 60;
    if (h == 0) return '${mm}m';
    if (mm == 0) return '${h}h';
    return '${h}h ${mm}m';
  }
}

// ------------------------------------------------------------------ 리스트
class _ListView extends ConsumerWidget {
  const _ListView({required this.items});
  final List<Schedule> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final s = items[i];
        return InkWell(
          onTap: () => showScheduleEditSheet(context, existing: s),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tk.line, width: 1)),
            ),
            padding: const EdgeInsets.fromLTRB(kGutter, 11, kGutter, 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(minToShort(s.startMin),
                      style: AppText.meta(tk.inkSoft)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          style: AppText.body(s.done ? tk.inkSoft : tk.ink)
                              .copyWith(
                                  decoration: s.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: tk.inkSoft),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                          '${minToShort(s.startMin)}–${minToShort(s.endMin)}',
                          style: AppText.meta(tk.inkSoft, size: 10)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => ref
                      .read(scheduleRepoProvider)
                      .toggleDone(s.id, !s.done),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 1),
                    child: Text(s.done ? '■' : '□',
                        style: AppText.glyph(tk.ink)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- 타임라인
class _TimelineView extends StatelessWidget {
  const _TimelineView({required this.items});
  final List<Schedule> items;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final startH =
        ((items.map((s) => s.startMin).reduce(math.min)) ~/ 60 - 0)
            .clamp(0, 23);
    final endH = ((items.map((s) => s.endMin).reduce(math.max)) / 60)
        .ceil()
        .clamp(1, 24);
    const rowH = 44.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 16),
      child: SizedBox(
        height: (endH - startH) * rowH,
        child: Stack(
          children: [
            for (var h = startH; h <= endH; h++)
              Positioned(
                left: 0,
                right: 0,
                top: (h - startH) * rowH,
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text('${h.toString().padLeft(2, '0')}:00',
                          style: AppText.meta(tk.inkSoft, size: 10)),
                    ),
                    Expanded(child: Container(height: 1, color: tk.line)),
                  ],
                ),
              ),
            for (final s in items)
              Positioned(
                left: 48,
                right: 0,
                top: (s.startMin - startH * 60) / 60 * rowH,
                height: ((s.endMin - s.startMin) / 60 * rowH).clamp(18, 1440),
                child: GestureDetector(
                  onTap: () => showScheduleEditSheet(context, existing: s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tk.paper2,
                      border: Border(
                          left: BorderSide(color: tk.ink, width: 2),
                          top: BorderSide(color: tk.line, width: 1),
                          right: BorderSide(color: tk.line, width: 1),
                          bottom: BorderSide(color: tk.line, width: 1)),
                    ),
                    child: Text(s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(tk.ink)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 원형
class _CircularView extends StatelessWidget {
  const _CircularView({required this.items, required this.date});
  final List<Schedule> items;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kGutter),
        child: AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(
            painter: _ClockPainter(
              items: items,
              ink: tk.ink,
              ring: tk.line,
              tickColor: tk.inkSoft,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat('M.d').format(date),
                      style: AppText.hTitle(tk.ink)),
                  Text('${items.length} events',
                      style: AppText.meta(tk.inkSoft)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(
      {required this.items,
      required this.ink,
      required this.ring,
      required this.tickColor});
  final List<Schedule> items;
  final Color ink;
  final Color ring;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final ringR = r * 0.72;
    final bandW = r * 0.14;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ring;
    canvas.drawCircle(c, ringR + bandW * 0.9, ringPaint);

    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1;
    for (var h = 0; h < 24; h++) {
      final a = (h / 24) * 2 * math.pi - math.pi / 2;
      final outer = ringR + bandW * 0.9;
      final inner = outer - (h % 3 == 0 ? 8 : 4);
      canvas.drawLine(
        c + Offset(math.cos(a) * outer, math.sin(a) * outer),
        c + Offset(math.cos(a) * inner, math.sin(a) * inner),
        tickPaint,
      );
      if (h % 3 == 0) {
        final tp = TextPainter(
          text: TextSpan(
              text: '$h',
              style: TextStyle(
                  color: tickColor, fontSize: 10, fontFamily: 'monospace')),
          textDirection: TextDirection.ltr,
        )..layout();
        final lr = outer + 10;
        tp.paint(
          canvas,
          c +
              Offset(math.cos(a) * lr, math.sin(a) * lr) -
              Offset(tp.width / 2, tp.height / 2),
        );
      }
    }

    // 일정 밴드 — 잉크 단색.
    for (final s in items) {
      final startA = (s.startMin / 1440) * 2 * math.pi - math.pi / 2;
      final sweep = ((s.endMin - s.startMin) / 1440) * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = bandW
        ..strokeCap = StrokeCap.butt
        ..color = ink;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: ringR),
        startA,
        sweep <= 0 ? 0.02 : sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ClockPainter old) => old.items != items;
}
