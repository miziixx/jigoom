import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/journal.dart';
import '../../core/theme.dart';
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
    builder: (ctx) => AlertDialog(
      title: Text('$label 기록'),
      // 다중 기록: 줄바꿈으로 한 시간대에 여러 작업을 적을 수 있다.
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 1,
        maxLines: 6,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
            hintText: '이 시간에 뭐 했어요?\n(줄바꿈으로 여러 개)'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소')),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('저장')),
      ],
    ),
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

/// 타임트래커 body — 하루 30분×48블록 기록 (임베드용, Scaffold 없음).
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks =
        ref.watch(timeBlocksForDateProvider(_date)).valueOrNull ?? const [];
    final byIndex = {for (final b in blocks) b.block: b};
    final nowBlock = TimeTrackRepository.blockOfNow();
    final filled = byIndex.length;

    return Container(
        color: t(context).paper,
        child: Column(
          children: [
            // 날짜 이동
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 2),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() =>
                        _date = _date.subtract(const Duration(days: 1))),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('M월 d일 (E)', 'ko').format(_date),
                      textAlign: TextAlign.center,
                      style: AppText.hTitle(t(context).ink),
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
            Text('$filled / 48 FILLED',
                style: AppText.meta(t(context).inkSoft)),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: kGutter),
              height: 1,
              color: t(context).line,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 6, bottom: 16),
                itemCount: 48,
                itemBuilder: (_, i) {
                  final b = byIndex[i];
                  final isNow = _isToday && i == nowBlock;
                  return _row(theme, i, b?.content, isNow, b?.updatedAt);
                },
              ),
            ),
          ],
        ),
      );
  }

  Widget _row(
      ThemeData theme, int i, String? text, bool isNow, DateTime? writtenAt) {
    final tk = t(context);
    final hasText = text != null && text.trim().isNotEmpty;
    // 한 시간대 안의 여러 기록 — 줄바꿈으로 나눠 각 줄을 표시.
    final lines = hasText
        ? text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList()
        : const <String>[];
    return InkWell(
      onTap: () => showTimeTrackInput(context, ref, date: _date, block: i),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            // 기록된 행만 포인트 컬러 강조(지금은 진하게, 나머지 기록은 옅게).
            left: BorderSide(
                color: isNow
                    ? tk.mark
                    : (hasText
                        ? tk.mark.withValues(alpha: 0.35)
                        : Colors.transparent),
                width: 2),
            bottom: BorderSide(color: tk.line, width: 1),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(kGutter, 9, kGutter, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 46,
              child: Text(blockLabel(i),
                  style: AppText.meta(isNow ? tk.ink : tk.inkSoft)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: !hasText
                  ? Text('—', style: AppText.body(tk.inkSoft))
                  : lines.length <= 1
                      ? Text(lines.isEmpty ? '—' : lines.first,
                          style: AppText.body(tk.ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final line in lines)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('— ',
                                        style: AppText.body(tk.inkSoft)),
                                    Expanded(
                                        child: Text(line,
                                            style: AppText.body(tk.ink))),
                                  ],
                                ),
                              ),
                          ],
                        ),
            ),
            // 실제 작성/수정 시각 (기록이 있을 때만)
            if (hasText && writtenAt != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('✎ ${DateFormat('HH:mm').format(writtenAt)}',
                    style: AppText.meta(tk.mark, size: 10)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
