import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/repos/time_track_repository.dart';
import '../../providers.dart';

/// 특정 블록에 기록 입력 다이얼로그 (화면·위젯 진입 공용).
Future<void> showTimeTrackInput(
  BuildContext context,
  WidgetRef ref, {
  required DateTime date,
  required int block,
}) async {
  final repo = ref.read(timeTrackRepoProvider);
  final existing = await repo.getBlock(date, block);
  if (!context.mounted) return;
  final controller = TextEditingController(text: existing?.content ?? '');
  final label =
      '${blockLabel(block)}–${blockLabel((block + 1) % 48 == 0 ? 48 : block + 1)}';
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final tk = t(ctx);
      return AlertDialog(
        title: Text('[ $label ]', style: AppText.hTitle(tk.ink)),
        // 다중 기록: 첫 줄은 제목, 다음 줄부터 줄바꿈으로 여러 작업.
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 7,
          keyboardType: TextInputType.multiline,
          style: AppText.body(tk.ink),
          cursorColor: tk.mark,
          decoration: InputDecoration(
            isDense: true,
            hintText: '제목\n— 한 일을 줄바꿈으로 여러 개',
            hintStyle: AppText.meta(tk.inkSoft, size: 13),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: tk.line)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: tk.ink, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('저장')),
        ],
      );
    },
  );
  if (text != null) {
    await repo.setBlock(date, block, text);
  }
}

/// 타임트래커 화면 (독립 진입용 — Scaffold 래퍼).
class TimeTrackScreen extends StatelessWidget {
  const TimeTrackScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        appBar: null,
        body: SafeArea(child: TimeTrackBody()),
      );
}

/// 타임로그(§ 시간 기록) — v17 레퍼런스: 시간대별로 '기록 없음' + 기록된 시간은
/// 강조 배경 + 제목 + 30분 + '—' 불릿 + 시간범위·작성 시각. 30분×48블록 유지.
class TimeTrackBody extends ConsumerStatefulWidget {
  const TimeTrackBody({super.key});

  @override
  ConsumerState<TimeTrackBody> createState() => _TimeTrackBodyState();
}

class _TimeTrackBodyState extends ConsumerState<TimeTrackBody> {
  DateTime _date = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);

  bool get _isToday =>
      _date.year == DateTime.now().year &&
      _date.month == DateTime.now().month &&
      _date.day == DateTime.now().day;

  Future<void> _export(List<TimeBlock> filled) async {
    if (filled.isEmpty) return;
    final buf = StringBuffer('${DateFormat('M.d (E)', 'ko').format(_date)} 시간 기록\n');
    for (final b in filled) {
      buf.writeln('\n${blockLabel(b.block)}');
      for (final l in b.content
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)) {
        buf.writeln('  $l');
      }
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
            content: Text('시간 기록을 복사했어요'),
            duration: Duration(milliseconds: 1200)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final blocks =
        ref.watch(timeBlocksForDateProvider(_date)).valueOrNull ?? const [];
    final byIndex = {
      for (final b in blocks)
        if (b.content.trim().isNotEmpty) b.block: b
    };
    final nowBlock = TimeTrackRepository.blockOfNow();
    final totalMin = byIndex.length * 30;
    final totH = totalMin ~/ 60;
    final totM = totalMin % 60;
    final totalStr = totH > 0 ? '$totH시간 ${totM > 0 ? '$totM분' : ''}'.trim() : '$totM분';

    // 보여줄 시간대: 06~23시 + 기록이 있는 시간(범위 밖이라도).
    final recordHours = {for (final k in byIndex.keys) k ~/ 2};
    final hours = <int>{...List.generate(18, (i) => i + 6), ...recordHours}
        .toList()
      ..sort();

    final rows = <Widget>[];
    for (final h in hours) {
      final recs = [byIndex[h * 2], byIndex[h * 2 + 1]]
          .whereType<TimeBlock>()
          .toList();
      if (recs.isEmpty) {
        rows.add(_emptyHour(tk, h));
      } else {
        for (final b in recs) {
          rows.add(_record(tk, b, _isToday && b.block == nowBlock));
        }
      }
    }

    return Container(
      color: tk.paper,
      child: Column(
        children: [
          // § 시간 기록 + 내보내기
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('§ ',
                    style: AppText.hTitle(tk.mark).copyWith(fontSize: 15)),
                Text('시간 기록',
                    style: AppText.hTitle(tk.ink).copyWith(fontSize: 18)),
                const Spacer(),
                GestureDetector(
                  onTap: () => _export(byIndex.values.toList()
                    ..sort((a, b) => a.block.compareTo(b.block))),
                  behavior: HitTestBehavior.opaque,
                  child: Text('내보내기', style: AppText.meta(tk.inkSoft, size: 11)),
                ),
              ],
            ),
          ),
          Container(
              margin: const EdgeInsets.symmetric(horizontal: kGutter),
              height: 1,
              color: tk.line),
          // 날짜 + 총 기록
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 10),
            child: Row(
              children: [
                _arrow(tk, '‹',
                    () => setState(() => _date = _date.subtract(const Duration(days: 1)))),
                const SizedBox(width: 6),
                Text(DateFormat('MM.dd (E)', 'ko').format(_date),
                    style: AppText.meta(tk.ink)),
                const Spacer(),
                Text('총 기록 $totalStr', style: AppText.meta(tk.inkSoft)),
                const SizedBox(width: 6),
                _arrow(tk, '›',
                    () => setState(() => _date = _date.add(const Duration(days: 1)))),
              ],
            ),
          ),
          Container(height: 1, color: tk.line),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: rows,
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrow(AppTokens tk, String g, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: tk.line),
          ),
          child: Text(g, style: AppText.glyph(tk.inkSoft, size: 15)),
        ),
      );

  /// 기록 없는 시간 — 시간 라벨 + 세로 헤어라인 + '기록 없음'.
  Widget _emptyHour(AppTokens tk, int hour) {
    final label = '${hour.toString().padLeft(2, '0')}:00';
    return GestureDetector(
      onTap: () =>
          showTimeTrackInput(context, ref, date: _date, block: hour * 2),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
        padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                    width: 46,
                    child: Text(label,
                        style: AppText.meta(tk.inkSoft, size: 11))),
              ),
              Container(width: 1, color: tk.line),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 0, 16),
                  child: Text('기록 없음',
                      style: AppText.meta(tk.inkSoft, size: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 기록된 시간 — 강조 배경 + 좌측 포인트선 + 제목/30분 + '—' 불릿 + 범위·작성.
  Widget _record(AppTokens tk, TimeBlock b, bool isNow) {
    final lines = b.content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final title = lines.isEmpty ? '기록' : lines.first;
    final bullets = lines.length > 1 ? lines.sublist(1) : const <String>[];
    final start = blockLabel(b.block);
    final end = blockLabel((b.block + 1) % 48 == 0 ? 48 : b.block + 1);
    final written =
        b.updatedAt != null ? ' · 작성 ${DateFormat('HH:mm').format(b.updatedAt!)}' : '';

    return GestureDetector(
      onTap: () =>
          showTimeTrackInput(context, ref, date: _date, block: b.block),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tk.paper2,
          border: Border(
            left: BorderSide(
                color: isNow ? tk.mark : tk.mark.withValues(alpha: 0.5),
                width: 2),
            bottom: BorderSide(color: tk.line),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 46,
                child: Text(start,
                    style: AppText.meta(isNow ? tk.ink : tk.inkSoft))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(title,
                            style: AppText.body(tk.ink)
                                .copyWith(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text('30분', style: AppText.meta(tk.inkSoft, size: 11)),
                    ],
                  ),
                  for (final line in bullets)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('— ', style: AppText.body(tk.inkSoft)),
                          Expanded(child: Text(line, style: AppText.body(tk.ink))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text('$start–$end$written',
                      style: AppText.meta(tk.inkSoft, size: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
