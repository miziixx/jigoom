import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/journal.dart';
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
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '이 시간에 뭐 했어요?'),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
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

/// 타임트래커 화면 — 하루 30분×48블록 기록.
class TimeTrackScreen extends ConsumerStatefulWidget {
  const TimeTrackScreen({super.key});

  @override
  ConsumerState<TimeTrackScreen> createState() => _TimeTrackScreenState();
}

class _TimeTrackScreenState extends ConsumerState<TimeTrackScreen> {
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
    final byIndex = {for (final b in blocks) b.block: b.content};
    final nowBlock = TimeTrackRepository.blockOfNow();
    final filled = byIndex.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('기록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: '지금 기록',
            onPressed: _isToday
                ? () => showTimeTrackInput(context, ref,
                    date: _date, block: nowBlock)
                : null,
          ),
        ],
      ),
      body: Container(
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
                    child: Text(
                      DateFormat('M월 d일 (E)', 'ko').format(_date),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
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
            Text('기록한 칸 $filled / 48',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Expanded(
              child: Journal.card(
                context,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: 48,
                  itemBuilder: (_, i) {
                    final text = byIndex[i];
                    final isNow = _isToday && i == nowBlock;
                    return _row(theme, i, text, isNow);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, int i, String? text, bool isNow) {
    final ink = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final hasText = text != null && text.isNotEmpty;
    return InkWell(
      onTap: () =>
          showTimeTrackInput(context, ref, date: _date, block: i),
      child: Container(
        decoration: isNow
            ? BoxDecoration(
                border: Border(left: BorderSide(color: ink, width: 2)))
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 46,
              child: Text(
                blockLabel(i),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: isNow ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            Expanded(
              child: Text(
                hasText ? text : '—',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: hasText
                      ? theme.textTheme.bodyMedium?.color
                      : (theme.textTheme.bodySmall?.color ?? Colors.grey)
                          .withValues(alpha: 0.4),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
