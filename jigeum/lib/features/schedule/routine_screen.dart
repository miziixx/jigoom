import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';

const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

/// 새 루틴 블록 추가 시트(= "+ 루틴"). 블록 안 스텝은 화면에서 이어 추가.
Future<void> showRoutineGroupSheet(BuildContext context,
    {RoutineGroup? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => _GroupSheet(existing: existing),
  );
}

/// 스텝 추가/수정 시트 (트리거 + 제목).
Future<void> showRoutineStepSheet(BuildContext context,
    {required String groupId, RoutineStep? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => _StepSheet(groupId: groupId, existing: existing),
  );
}

/// 옛 시간자동 루틴 편집 시트 (레거시 — "시간 자동 일정" 섹션에서 사용).
Future<void> showRoutineEditSheet(BuildContext context, {Routine? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => _RoutineEditSheet(existing: existing),
  );
}

/// 루틴 관리 화면 (독립 진입용 — Scaffold 래퍼).
class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('루틴'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '새 루틴 블록',
              onPressed: () => showRoutineGroupSheet(context),
            ),
          ],
        ),
        body: const RoutineBody(),
      );
}

/// 루틴 화면 본문 — 블록(그룹) + 순서 스텝. 아래에 레거시 시간자동 루틴.
class RoutineBody extends ConsumerWidget {
  const RoutineBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final groups = ref.watch(routineGroupsProvider).valueOrNull ?? const [];
    final steps = ref.watch(routineStepsProvider).valueOrNull ?? const [];
    final legacy = ref.watch(routinesProvider).valueOrNull ?? const [];

    // 스텝을 그룹별로 묶기 (이미 sortOrder 로 정렬됨).
    final byGroup = <String, List<RoutineStep>>{};
    for (final s in steps) {
      (byGroup[s.groupId] ??= []).add(s);
    }

    if (groups.isEmpty && legacy.isEmpty) {
      return Container(
        color: tk.paper,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: emptyNote(context, '루틴 블록을 만들어 하루 흐름을 이어보세요'),
          ),
        ),
      );
    }

    return Container(
      color: tk.paper,
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 40),
        children: [
          for (final g in groups)
            _GroupBlock(group: g, steps: byGroup[g.id] ?? const []),
          // 새 블록 추가
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 20, kGutter, 0),
            child: GestureDetector(
              onTap: () => showRoutineGroupSheet(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: tk.ink))),
                child: Text('+ 새 루틴 블록',
                    style: AppText.meta(tk.ink, size: 11)
                        .copyWith(letterSpacing: 1.2)),
              ),
            ),
          ),
          // 레거시: 시간 자동 일정(옛 루틴)
          if (legacy.isNotEmpty) ...[
            const SectionLabel('시간 자동 일정'),
            for (final r in legacy) _legacyCard(context, ref, tk, r),
          ],
        ],
      ),
    );
  }

  Widget _legacyCard(
      BuildContext context, WidgetRef ref, AppTokens tk, Routine r) {
    final days = r.weekdays.split(',').where((s) => s.isNotEmpty).toList();
    final dayLabel = days.length == 7
        ? '매일'
        : days.map((d) => _weekdayNames[int.parse(d) - 1]).join('·');
    return Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
      padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title,
                    style: AppText.body(r.active ? tk.ink : tk.inkSoft)),
                const SizedBox(height: 3),
                Text(
                    '$dayLabel · ${minToShort(r.startMin)}–${minToShort(r.endMin)}',
                    style: AppText.meta(tk.inkSoft)),
              ],
            ),
          ),
          Switch(
            value: r.active,
            onChanged: (v) =>
                ref.read(scheduleRepoProvider).setRoutineActive(r.id, v),
          ),
          GestureDetector(
            onTap: () => showRoutineEditSheet(context, existing: r),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.edit_outlined, size: 18, color: tk.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

/// 한 블록(그룹) — 헤더(접기) + 순서 스텝(드래그 재정렬) + 스텝 추가.
class _GroupBlock extends ConsumerWidget {
  const _GroupBlock({required this.group, required this.steps});
  final RoutineGroup group;
  final List<RoutineStep> steps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final repo = ref.read(routineBuilderRepoProvider);
    final today = todayDate();
    bool doneToday(RoutineStep s) =>
        s.lastDone != null && dateOnly(s.lastDone!) == today;
    final doneCount = steps.where(doneToday).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        GestureDetector(
          onTap: () => repo.setGroupCollapsed(group.id, !group.collapsed),
          onLongPress: () => showRoutineGroupSheet(context, existing: group),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 18, kGutter, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  child: Text(group.collapsed ? '▸' : '▾',
                      style: AppText.meta(tk.inkSoft, size: 11)),
                ),
                Flexible(
                  child: Text(group.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(tk.ink)
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Text('$doneCount/${steps.length}',
                    style: AppText.meta(tk.inkSoft, size: 10)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kGutter),
          child: Container(height: 1, color: tk.ink),
        ),
        if (!group.collapsed) ...[
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            padding: EdgeInsets.zero,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final ids = steps.map((s) => s.id).toList();
              final moved = ids.removeAt(oldIndex);
              ids.insert(newIndex, moved);
              repo.reorderSteps(ids);
            },
            children: [
              for (var i = 0; i < steps.length; i++)
                _StepRow(
                  key: ValueKey(steps[i].id),
                  step: steps[i],
                  index: i,
                  doneToday: doneToday(steps[i]),
                ),
            ],
          ),
          // 스텝 추가
          GestureDetector(
            onTap: () => showRoutineStepSheet(context, groupId: group.id),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(kGutter + 60, 11, kGutter, 11),
              child: Text('+ 스텝 추가', style: AppText.meta(tk.inkSoft, size: 11)),
            ),
          ),
        ],
      ],
    );
  }
}

/// 스텝 한 줄 — 트리거(레일) · □/■ 제목 · 연속수 · 드래그 손잡이.
class _StepRow extends ConsumerWidget {
  const _StepRow({
    super.key,
    required this.step,
    required this.index,
    required this.doneToday,
  });
  final RoutineStep step;
  final int index;
  final bool doneToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final repo = ref.read(routineBuilderRepoProvider);
    final trigger = step.trigger.trim();

    return Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 트리거 (레일 왼쪽)
            SizedBox(
              width: kGutter + 46,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    trigger.isEmpty ? '그다음' : trigger,
                    textAlign: TextAlign.right,
                    style: AppText.meta(trigger.isEmpty ? tk.inkSoft : tk.ink,
                        size: 10),
                  ),
                ),
              ),
            ),
            // 시퀀스 레일 (세로선 — 줄이 이어져 "뭐 다음 뭐"를 잇는다)
            Container(width: 1, color: tk.line),
            // 본문 (탭=체크 / 롱프레스=수정)
            Expanded(
              child: GestureDetector(
                onTap: () => repo.toggleStepDone(step),
                onLongPress: () => showRoutineStepSheet(context,
                    groupId: step.groupId, existing: step),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
                  child: Row(
                    children: [
                      Text(doneToday ? '■' : '□',
                          style: AppText.glyph(doneToday ? tk.ink : tk.inkSoft,
                              size: 15)),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          step.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: doneToday
                              ? AppText.body(tk.inkSoft).copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: tk.inkSoft)
                              : AppText.body(tk.ink),
                        ),
                      ),
                      if (doneToday && step.lastDoneAt != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                              '${DateFormat('HH:mm').format(step.lastDoneAt!)} 완료'
                              '${step.streak > 0 ? ' · ×${step.streak}' : ''}',
                              style: AppText.meta(tk.mark, size: 10)),
                        )
                      else if (step.streak > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text('×${step.streak}',
                              style: AppText.meta(tk.inkSoft, size: 10)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // 드래그 손잡이 (여기서만 드래그 시작 → 탭 체크와 충돌 없음)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: kGutter - 8),
                child: Center(
                  child: Text('≡', style: AppText.glyph(tk.inkSoft, size: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────── 블록 시트

class _GroupSheet extends ConsumerStatefulWidget {
  const _GroupSheet({this.existing});
  final RoutineGroup? existing;

  @override
  ConsumerState<_GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends ConsumerState<_GroupSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final repo = ref.read(routineBuilderRepoProvider);
    final e = widget.existing;
    if (e == null) {
      await repo.addGroup(title);
    } else {
      await repo.renameGroup(e.id, title);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final editing = widget.existing != null;
    return _SheetFrame(
      title: editing ? '루틴 블록 수정' : '새 루틴 블록',
      onDelete: editing
          ? () async {
              await ref
                  .read(routineBuilderRepoProvider)
                  .deleteGroup(widget.existing!.id);
              if (context.mounted) Navigator.of(context).pop();
            }
          : null,
      onSave: _save,
      children: [
        _promptField(tk, _title, '블록 이름 (예: 모닝 루틴)', autofocus: !editing),
      ],
    );
  }
}

// ─────────────────────────────────────────────────── 스텝 시트

class _StepSheet extends ConsumerStatefulWidget {
  const _StepSheet({required this.groupId, this.existing});
  final String groupId;
  final RoutineStep? existing;

  @override
  ConsumerState<_StepSheet> createState() => _StepSheetState();
}

class _StepSheetState extends ConsumerState<_StepSheet> {
  late final TextEditingController _trigger =
      TextEditingController(text: widget.existing?.trigger ?? '');
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');

  @override
  void dispose() {
    _trigger.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final repo = ref.read(routineBuilderRepoProvider);
    final e = widget.existing;
    if (e == null) {
      await repo.addStep(widget.groupId,
          trigger: _trigger.text.trim(), title: title);
    } else {
      await repo.updateStep(e.id, trigger: _trigger.text.trim(), title: title);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final editing = widget.existing != null;
    return _SheetFrame(
      title: editing ? '스텝 수정' : '새 스텝',
      onDelete: editing
          ? () async {
              await ref
                  .read(routineBuilderRepoProvider)
                  .deleteStep(widget.existing!.id);
              if (context.mounted) Navigator.of(context).pop();
            }
          : null,
      onSave: _save,
      children: [
        _promptField(tk, _title, '무엇을 하나요? (예: 공복에 물 한 잔)',
            autofocus: !editing),
        const SizedBox(height: 14),
        Text('언제 (트리거)', style: AppText.meta(tk.inkSoft, size: 10)),
        const SizedBox(height: 6),
        _promptField(tk, _trigger, '예: 눈 뜨면 · 07:20 · 집 나서면 (비우면 “그다음”)'),
      ],
    );
  }
}

// ─────────────────────────────────────────────────── 공용 시트 프레임

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.children,
    required this.onSave,
    this.onDelete,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Container(
      color: tk.paper,
      padding: EdgeInsets.only(
        left: kGutter,
        right: kGutter,
        top: 18,
        bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: AppText.meta(tk.inkSoft, size: 10)
                      .copyWith(letterSpacing: 1.4)),
              const Spacer(),
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: Text('삭제', style: AppText.meta(tk.mark, size: 11)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: tk.ink),
          const SizedBox(height: 14),
          ...children,
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text('취소', style: AppText.nav(tk.inkSoft)),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onSave,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  color: tk.ink,
                  child: Text('저장', style: AppText.nav(tk.paper, active: true)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _promptField(AppTokens tk, TextEditingController c, String hint,
    {bool autofocus = false}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 2),
        child: Text('›', style: AppText.glyph(tk.mark, size: 16)),
      ),
      Expanded(
        child: TextField(
          controller: c,
          autofocus: autofocus,
          cursorColor: tk.mark,
          style: AppText.body(tk.ink),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: AppText.meta(tk.inkSoft, size: 13),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────── 레거시 시간자동 루틴 편집

class _RoutineEditSheet extends ConsumerStatefulWidget {
  const _RoutineEditSheet({this.existing});
  final Routine? existing;

  @override
  ConsumerState<_RoutineEditSheet> createState() => _RoutineEditSheetState();
}

class _RoutineEditSheetState extends ConsumerState<_RoutineEditSheet> {
  late final TextEditingController _title;
  late int _color;
  late int _start;
  late int _end;
  late Set<int> _days; // 1~7

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _color = e?.color ?? 1;
    _start = e?.startMin ?? 7 * 60;
    _end = e?.endMin ?? 8 * 60;
    _days = e == null
        ? {1, 2, 3, 4, 5, 6, 7}
        : e.weekdays
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toSet();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final init = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: init ~/ 60, minute: init % 60),
      cancelText: '취소',
      confirmText: '선택',
    );
    if (picked != null) {
      setState(() {
        final m = picked.hour * 60 + picked.minute;
        if (isStart) {
          _start = m;
          if (_end <= _start) _end = (_start + 60).clamp(0, 1439);
        } else {
          _end = m;
        }
      });
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _days.isEmpty) return;
    final repo = ref.read(scheduleRepoProvider);
    final weekdays = (_days.toList()..sort()).join(',');
    final e = widget.existing;
    if (e == null) {
      await repo.addRoutine(
        title: title,
        color: _color,
        startMin: _start,
        endMin: _end,
        weekdays: weekdays,
      );
    } else {
      await repo.db.update(repo.db.routines).replace(e.copyWith(
            title: title,
            color: _color,
            startMin: _start,
            endMin: _end,
            weekdays: weekdays,
          ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairline = theme.dividerTheme.color ?? Colors.black12;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing == null ? '새 시간 루틴' : '시간 루틴 수정',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            autofocus: widget.existing == null,
            decoration: const InputDecoration(
                hintText: '예: 아침 기상, 운동', border: UnderlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var d = 1; d <= 7; d++)
                GestureDetector(
                  onTap: () => setState(() {
                    _days.contains(d) ? _days.remove(d) : _days.add(d);
                  }),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _days.contains(d)
                          ? (theme.textTheme.bodyLarge?.color ?? Colors.black)
                          : Colors.transparent,
                      border: Border.all(color: hairline, width: 1),
                    ),
                    child: Text(
                      _weekdayNames[d - 1],
                      style: TextStyle(
                        fontSize: 13,
                        color: _days.contains(d)
                            ? theme.scaffoldBackgroundColor
                            : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _timeBtn(theme, '시작', _start, true)),
              const SizedBox(width: 10),
              Expanded(child: _timeBtn(theme, '끝', _end, false)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.existing != null)
                TextButton.icon(
                  onPressed: () async {
                    await ref
                        .read(scheduleRepoProvider)
                        .deleteRoutine(widget.existing!.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: theme.textTheme.bodySmall?.color),
                  label: Text('삭제', style: theme.textTheme.bodySmall),
                ),
              const Spacer(),
              FilledButton(onPressed: _save, child: const Text('저장')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeBtn(ThemeData theme, String label, int min, bool isStart) {
    final hairline = theme.dividerTheme.color ?? Colors.black12;
    return GestureDetector(
      onTap: () => _pickTime(isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          border: Border.all(color: hairline, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            Text(minToLabel(min), style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
