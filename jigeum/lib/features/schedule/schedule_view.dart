import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/journal.dart';
import '../../data/db.dart';
import '../../providers.dart';
import 'schedule_edit_sheet.dart';
import 'routine_screen.dart';

/// 일과 (하루 일정) — 리스트 / 타임라인 / 원형 3보기 + 날짜 이동.
class ScheduleView extends ConsumerStatefulWidget {
  const ScheduleView({super.key});

  @override
  ConsumerState<ScheduleView> createState() => ScheduleViewState();
}

class ScheduleViewState extends ConsumerState<ScheduleView> {
  DateTime _date = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);
  int _view = 0; // 0 리스트 · 1 타임라인 · 2 원형

  /// 앱바 + 버튼에서 호출: 일정 추가.
  void addSchedule() => showScheduleEditSheet(context, date: _date);

  /// 앱바 루틴 버튼.
  void openRoutines() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RoutineScreen()));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items =
        ref.watch(schedulesForDateProvider(_date)).valueOrNull ?? const [];
    final totalMin =
        items.fold<int>(0, (a, s) => a + (s.endMin - s.startMin).clamp(0, 1440));

    return Container(
      color: Journal.pageBg(context),
      child: Column(
        children: [
          // 날짜 이동
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() =>
                      _date = _date.subtract(const Duration(days: 1))),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Text(
                      DateFormat('M월 d일 (E)', 'ko').format(_date),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(
                      () => _date = _date.add(const Duration(days: 1))),
                ),
              ],
            ),
          ),
          // 요약
          Text(
            '일정 ${items.length}건 · 총 ${_hm(totalMin)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          // 보기 전환
          _viewTabs(theme),
          Expanded(
            child: Journal.card(
              context,
              child: items.isEmpty
                  ? Center(
                      child: Text('+ 로 오늘 일정을 추가해요',
                          style: theme.textTheme.bodySmall))
                  : switch (_view) {
                      0 => _ListView(items: items),
                      1 => _TimelineView(items: items),
                      _ => _CircularView(items: items, date: _date),
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewTabs(ThemeData theme) {
    Widget tab(int i, String label) {
      final sel = _view == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _view = i),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: sel
                      ? (theme.textTheme.bodyLarge?.color ?? Colors.black)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: sel
                    ? theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)
                    : theme.textTheme.bodySmall),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        tab(0, '리스트'),
        tab(1, '타임라인'),
        tab(2, '원형'),
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
    if (h == 0) return '$mm분';
    if (mm == 0) return '$h시간';
    return '$h시간 $mm분';
  }
}

// ------------------------------------------------------------------ 리스트
class _ListView extends ConsumerWidget {
  const _ListView({required this.items});
  final List<Schedule> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => Journal.divider(context),
      itemBuilder: (_, i) {
        final s = items[i];
        return InkWell(
          onTap: () => showScheduleEditSheet(context, existing: s),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheduleColor(s.color),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              decoration: s.done
                                  ? TextDecoration.lineThrough
                                  : null),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('${minToShort(s.startMin)} – ${minToShort(s.endMin)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => ref
                      .read(scheduleRepoProvider)
                      .toggleDone(s.id, !s.done),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      s.done
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: s.done
                          ? const Color(0xFF34C77B)
                          : theme.textTheme.bodySmall?.color,
                    ),
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
    final theme = Theme.of(context);
    final hairline = theme.dividerTheme.color ?? Colors.black12;
    // 표시 범위: 가장 이른 시작 ~ 가장 늦은 끝 (여유 1시간).
    final startH =
        ((items.map((s) => s.startMin).reduce(math.min)) ~/ 60 - 0)
            .clamp(0, 23);
    final endH =
        ((items.map((s) => s.endMin).reduce(math.max)) / 60).ceil().clamp(1, 24);
    const rowH = 44.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 16),
      child: SizedBox(
        height: (endH - startH) * rowH,
        child: Stack(
          children: [
            // 시간 눈금
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
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 11)),
                    ),
                    Expanded(child: Container(height: 0.5, color: hairline)),
                  ],
                ),
              ),
            // 일정 블록
            for (final s in items)
              Positioned(
                left: 48,
                right: 4,
                top: (s.startMin - startH * 60) / 60 * rowH,
                height: ((s.endMin - s.startMin) / 60 * rowH).clamp(18, 1440),
                child: GestureDetector(
                  onTap: () => showScheduleEditSheet(context, existing: s),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheduleColor(s.color).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(
            painter: _ClockPainter(
              items: items,
              ring: theme.dividerTheme.color ?? Colors.black12,
              tickColor: theme.textTheme.bodySmall?.color ?? Colors.grey,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat('M.d').format(date),
                      style: theme.textTheme.titleMedium),
                  Text('${items.length}건',
                      style: theme.textTheme.bodySmall),
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
      {required this.items, required this.ring, required this.tickColor});
  final List<Schedule> items;
  final Color ring;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final ringR = r * 0.72;
    final bandW = r * 0.16;

    // 바깥 링
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ring;
    canvas.drawCircle(c, ringR + bandW * 0.9, ringPaint);

    // 시간 눈금 + 숫자 (0,3,6,...21)
    final tickPaint = Paint()..color = tickColor..strokeWidth = 1;
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
              style: TextStyle(color: tickColor, fontSize: 10)),
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

    // 일정 밴드
    for (final s in items) {
      final startA = (s.startMin / 1440) * 2 * math.pi - math.pi / 2;
      final sweep = ((s.endMin - s.startMin) / 1440) * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = bandW
        ..strokeCap = StrokeCap.butt
        ..color = scheduleColor(s.color);
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
  bool shouldRepaint(covariant _ClockPainter old) =>
      old.items != items;
}
