import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/entry_display_mode.dart';
import '../models/memo.dart';

final entryDisplayModeNotifier = ValueNotifier<EntryDisplayMode>(
  EntryDisplayMode.hybrid,
);

void applyEntryDisplayMode(EntryDisplayMode mode) {
  entryDisplayModeNotifier.value = mode;
}

enum LogroomEntryKind {
  entry,
  task,
  done,
  event,
  pastEvent,
  open,
  habit,
  goal,
  completedGoal,
}

LogroomEntryKind logroomKindOf(Memo memo) {
  if (memo.tags.contains('goal')) return LogroomEntryKind.goal;
  if (memo.tags.contains('habit')) return LogroomEntryKind.habit;
  if (memo.scheduledAt != null) {
    final eventDay = DateTime(
      memo.scheduledAt!.year,
      memo.scheduledAt!.month,
      memo.scheduledAt!.day,
      memo.scheduledAt!.hour,
      memo.scheduledAt!.minute,
    );
    return eventDay.isBefore(DateTime.now())
        ? LogroomEntryKind.pastEvent
        : LogroomEntryKind.event;
  }
  if (memo.isChecklist) {
    return _isChecklistDone(memo.content)
        ? LogroomEntryKind.done
        : LogroomEntryKind.task;
  }
  return LogroomEntryKind.entry;
}

bool _isChecklistDone(String content) {
  final lines = content
      .split('\n')
      .map((l) => l.trimLeft())
      .where((l) => l.isNotEmpty)
      .toList();
  final checklist = lines
      .where((l) => l.startsWith('- [ ] ') || l.startsWith('- [x] '))
      .toList();
  return checklist.isNotEmpty && checklist.every((l) => l.startsWith('- [x] '));
}

String logroomSymbol(LogroomEntryKind kind) {
  switch (kind) {
    case LogroomEntryKind.entry:
      return '●';
    case LogroomEntryKind.task:
      return '□';
    case LogroomEntryKind.done:
      return '■';
    case LogroomEntryKind.event:
      return '△';
    case LogroomEntryKind.pastEvent:
      return '▲';
    case LogroomEntryKind.open:
      return '○';
    case LogroomEntryKind.habit:
      return '○';
    case LogroomEntryKind.goal:
      return '◇';
    case LogroomEntryKind.completedGoal:
      return '◆';
  }
}

String logroomLabel(LogroomEntryKind kind) {
  switch (kind) {
    case LogroomEntryKind.entry:
      return '메모';
    case LogroomEntryKind.task:
      return '할일';
    case LogroomEntryKind.done:
      return '완료';
    case LogroomEntryKind.event:
      return '일정';
    case LogroomEntryKind.pastEvent:
      return '지난 일정';
    case LogroomEntryKind.open:
      return '열림';
    case LogroomEntryKind.habit:
      return '습관';
    case LogroomEntryKind.goal:
      return '목표';
    case LogroomEntryKind.completedGoal:
      return '완료 목표';
  }
}

String logroomPrefix(Memo memo, EntryDisplayMode mode) {
  final kind = logroomKindOf(memo);
  final symbol = logroomSymbol(kind);
  final label = logroomLabel(kind);
  switch (mode) {
    case EntryDisplayMode.symbol:
      return symbol;
    case EntryDisplayMode.text:
      return '[$label]';
    case EntryDisplayMode.hybrid:
      return '$symbol $label';
  }
}

String logroomTitle(Memo memo) {
  var text = memo.content
      .replaceAll(RegExp(r'\s*#habit\b'), ' ')
      .replaceAll(RegExp(r'\s*#goal\b'), ' ')
      .trim();
  if (memo.isChecklist) {
    text = text
        .split('\n')
        .map(
          (line) => line
              .replaceFirst(RegExp(r'^- \[[ x]\]\s*'), '')
              .replaceFirst(RegExp(r'^•\s*'), ''),
        )
        .where((line) => line.trim().isNotEmpty)
        .join(' · ');
  }
  return text.isEmpty ? '(empty)' : text;
}

String logroomTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

String logroomShortDateTime(DateTime dt) =>
    '${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

Widget logroomPrefixText(Memo memo, {double fontSize = 12}) {
  return ValueListenableBuilder<EntryDisplayMode>(
    valueListenable: entryDisplayModeNotifier,
    builder: (_, mode, __) => Text(
      logroomPrefix(memo, mode),
      style: mono(
        color: kDim, // HTML .e-type: color: var(--txt2/--mu)
        fontSize: fontSize,
        fontWeight: FontWeight.normal, // not bold — content is primary
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

/// Whether a checklist memo has any unchecked item
bool logroomHasUnchecked(String content) =>
    content.split('\n').any((l) => l.startsWith('- [ ] '));
