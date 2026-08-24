import 'package:drift/drift.dart' show Value;
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

// ─────────────────────────────────────────── 드래그용 평면 아이템

/// 블록·스텝을 한 줄짜리 리스트로 편 것. 하나의 ReorderableListView 안에
/// 헤더와 스텝이 같이 들어가야 스텝을 **다른 블록으로** 끌어 옮길 수 있다.
sealed class _Item {
  const _Item();
  Key get key;
}

class _HeaderItem extends _Item {
  const _HeaderItem(this.group, this.steps);
  final RoutineGroup group;
  final List<RoutineStep> steps;
  @override
  Key get key => ValueKey('g:${group.id}');
}

class _StepItem extends _Item {
  const _StepItem(this.step);
  final RoutineStep step;
  @override
  Key get key => ValueKey('s:${step.id}');
}

class _AddItem extends _Item {
  const _AddItem(this.groupId);
  final String groupId;
  @override
  Key get key => ValueKey('a:$groupId');
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

    // 평면화: [헤더, 스텝…, 스텝추가] × 블록 수.
    final items = <_Item>[
      for (final g in groups) ...[
        _HeaderItem(g, byGroup[g.id] ?? const []),
        if (!g.collapsed) ...[
          for (final s in byGroup[g.id] ?? const <RoutineStep>[]) _StepItem(s),
          _AddItem(g.id),
        ],
      ],
    ];

    return Container(
      color: tk.paper,
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 40),
        children: [
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            padding: EdgeInsets.zero,
            // 드래그 중 기본 그림자/테두리 제거 — 그대로 들어올린 모습만.
            proxyDecorator: (child, index, animation) =>
                Material(type: MaterialType.transparency, child: child),
            onReorder: (oldIndex, newIndex) =>
                _onReorder(ref, items, groups, oldIndex, newIndex),
            children: [
              for (var i = 0; i < items.length; i++)
                _itemWidget(items[i], i),
            ],
          ),
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
          // 기준 HTML .routine-log-feed — 최근 완료 루틴 스텝(실 lastDoneAt).
          ..._routineLog(tk, steps),
        ],
      ),
    );
  }

  // 기준 HTML .routine-log-feed — 최근 완료된 루틴 스텝을 시각순 피드로.
  List<Widget> _routineLog(AppTokens tk, List<RoutineStep> steps) {
    final done = steps.where((s) => s.lastDoneAt != null).toList()
      ..sort((a, b) => b.lastDoneAt!.compareTo(a.lastDoneAt!));
    if (done.isEmpty) return const [];
    final recent = done.take(12).toList();
    const palette = [
      Color(0xFF728D78),
      Color(0xFF6F86A7),
      Color(0xFFB77568),
    ];
    return [
      const SectionLabel('최근 완료'),
      for (var i = 0; i < recent.length; i++)
        _logRow(tk, recent[i], palette[i % palette.length]),
    ];
  }

  Widget _logRow(AppTokens tk, RoutineStep s, Color color) {
    final sub = s.streak > 1 ? '${s.streak}일 연속' : '완료';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: AppText.body(tk.ink)),
                const SizedBox(height: 2),
                Text(sub, style: AppText.meta(tk.inkSoft, size: 10)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(_logWhen(s.lastDoneAt!),
              style: AppText.meta(tk.inkSoft, size: 9)),
        ],
      ),
    );
  }

  String _logWhen(DateTime dt) {
    final today = todayDate();
    final d = dateOnly(dt);
    final diff = today.difference(d).inDays;
    final hm = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return '오늘 $hm';
    if (diff == 1) return '어제 $hm';
    return '${dt.month}/${dt.day} $hm';
  }

  Widget _itemWidget(_Item item, int index) {
    return switch (item) {
      _HeaderItem(:final group, :final steps) =>
        _GroupHeader(key: item.key, group: group, steps: steps, index: index),
      _StepItem(:final step) => _StepRow(key: item.key, step: step, index: index),
      _AddItem(:final groupId) => _AddStepRow(key: item.key, groupId: groupId),
    };
  }

  /// 드래그 결과 반영. 헤더를 옮기면 블록 순서, 스텝을 옮기면 (다른 블록 포함)
  /// 스텝의 소속·순서를 다시 계산한다.
  void _onReorder(WidgetRef ref, List<_Item> items, List<RoutineGroup> groups,
      int oldIndex, int newIndex) {
    if (groups.isEmpty) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    final moved = items[oldIndex];
    if (moved is _AddItem) return; // 손잡이가 없어 여기 올 일은 없지만 방어.

    final reordered = [...items];
    reordered.insert(newIndex, reordered.removeAt(oldIndex));

    final repo = ref.read(routineBuilderRepoProvider);
    if (moved is _HeaderItem) {
      repo.reorderGroups([
        for (final it in reordered)
          if (it is _HeaderItem) it.group.id,
      ]);
      return;
    }

    // 스텝: 위로 훑어 만나는 헤더가 그 스텝의 새 블록.
    final layout = <String, List<String>>{};
    var current = groups.first.id;
    for (final it in reordered) {
      if (it is _HeaderItem) {
        current = it.group.id;
      } else if (it is _StepItem) {
        (layout[current] ??= []).add(it.step.id);
      }
    }
    repo.applyStepLayout(layout);
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

/// 블록 헤더 — 탭=접기, 롱프레스=수정, 손잡이로 블록 통째 이동.
class _GroupHeader extends ConsumerWidget {
  const _GroupHeader({
    super.key,
    required this.group,
    required this.steps,
    required this.index,
  });
  final RoutineGroup group;
  final List<RoutineStep> steps;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final repo = ref.read(routineBuilderRepoProvider);
    final today = todayDate();
    final doneCount = steps
        .where((s) => s.lastDone != null && dateOnly(s.lastDone!) == today)
        .length;

    // HTML .routine-group 색 — 그룹별 빈도 노드 색(sage/blue/ochre/violet/rose).
    const palette = [
      Color(0xFF728D78),
      Color(0xFF6F86A7),
      Color(0xFFAA8B57),
      Color(0xFF8F6F86),
      Color(0xFFB77568),
    ];
    final nodeColor = palette[group.id.hashCode.abs() % palette.length];

    // 레퍼런스 .routine-group — 빈도 노드 · 제목/부제 · N단계 · 펼침 ⌃/⌄.
    return Container(
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: tk.line))),
      child: GestureDetector(
        onTap: () => repo.setGroupCollapsed(group.id, !group.collapsed),
        onLongPress: () => showRoutineGroupSheet(context, existing: group),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 11, kGutter, 11),
          child: Row(
            children: [
              // routine-frequency-node — 그룹 색 빈도 노드(링 + 점).
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: nodeColor, width: 1.5),
                ),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: nodeColor),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(group.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(tk.ink).copyWith(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('오늘 $doneCount / ${steps.length} 완료',
                        style: AppText.meta(tk.inkSoft, size: 9)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('${steps.length}단계',
                  style: AppText.meta(tk.inkSoft, size: 9)),
              const SizedBox(width: 10),
              Text(group.collapsed ? '⌄' : '⌃',
                  style: AppText.glyph(tk.inkSoft, size: 13)),
              // 블록 손잡이 — 블록 전체를 위아래로 옮긴다.
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: _DragGlyph(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 드래그 손잡이 글리프(≡) — 여러 곳에서 재사용.
class _DragGlyph extends StatelessWidget {
  const _DragGlyph();
  @override
  Widget build(BuildContext context) =>
      Text('≡', style: AppText.glyph(t(context).inkSoft, size: 15));
}

/// 루틴 블록 배지 — 시간대 키워드면 AM/MD/PM, 아니면 제목 앞 2글자.
String routineBadge(String title) {
  final s = title.trim();
  bool has(List<String> ks) => ks.any(s.contains);
  if (has(['아침', '모닝', '기상', '새벽'])) return 'AM';
  if (has(['점심', '오후', '낮'])) return 'MD';
  if (has(['저녁', '밤', '취침', '자기', '자정', '나이트'])) return 'PM';
  final c = s.replaceAll(' ', '');
  if (c.isEmpty) return '·';
  return c.length >= 2 ? c.substring(0, 2) : c;
}

/// "+ 스텝 추가" 줄 + 자주 쓰는 스텝 추천(알약 칩). 칩을 탭하면 바로 추가된다.
class _AddStepRow extends ConsumerWidget {
  const _AddStepRow({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final suggestions =
        ref.watch(routineStepSuggestionsProvider(groupId)).valueOrNull ??
            const <String>[];

    // 레퍼런스 .dash-add — 아이콘 아래로 들여쓴 "+ 단계 추가", 상단 hairline.
    return Container(
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: tk.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => showRoutineStepSheet(context, groupId: groupId),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(kGutter + 47, 10, kGutter, 10),
              child:
                  Text('+ 단계 추가', style: AppText.meta(tk.inkSoft, size: 10)),
            ),
          ),
          if (suggestions.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(kGutter + 47, 0, kGutter, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in suggestions)
                  PillChip(
                    label: s,
                    onTap: () => ref
                        .read(routineBuilderRepoProvider)
                        .addStep(groupId, title: s),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 스텝 한 줄 — 트리거(레일) · □/■ 제목 · 연속수 · 드래그 손잡이.
class _StepRow extends ConsumerWidget {
  const _StepRow({
    super.key,
    required this.step,
    required this.index,
  });
  final RoutineStep step;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final repo = ref.read(routineBuilderRepoProvider);
    final trigger = step.trigger.trim();
    final doneToday =
        step.lastDone != null && dateOnly(step.lastDone!) == todayDate();
    // 우측 소요/상태 라벨 — 레퍼런스 step small(3분) 자리에 트리거·연속·완료시각.
    final String small = doneToday
        ? (step.lastDoneAt != null
            ? DateFormat('HH:mm').format(step.lastDoneAt!)
            : '완료')
        : (trigger.isNotEmpty
            ? trigger
            : (step.streak > 0 ? '×${step.streak}' : ''));

    // 레퍼런스 .routine-step — 아이콘 아래로 들여쓴 [체크 | 이름 | 소요/상태].
    return Container(
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: tk.line))),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => repo.toggleStepDone(step),
              onLongPress: () => showRoutineStepSheet(context,
                  groupId: step.groupId, existing: step),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                // 좌측 들여쓰기 = gutter + 아이콘(36) + 간격(11).
                padding: const EdgeInsets.fromLTRB(kGutter + 47, 9, 8, 9),
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
                        style: AppText.body(doneToday
                                ? tk.ink.withValues(alpha: 0.5)
                                : tk.ink)
                            .copyWith(fontSize: 12),
                      ),
                    ),
                    if (small.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(small,
                            style: AppText.meta(
                                doneToday ? tk.mark : tk.inkSoft,
                                size: 9)),
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
      subtitle: '반복할 흐름의 이름부터 정합니다.',
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
      subtitle: '흐름에 들어갈 한 가지 행동이에요.',
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
        _suggestionPills(
          ref.watch(routineStepSuggestionsProvider(widget.groupId)).valueOrNull,
          (v) => setState(() => _title.text = v),
        ),
        const SizedBox(height: 14),
        Text('언제 (트리거)', style: AppText.meta(tk.inkSoft, size: 10)),
        const SizedBox(height: 6),
        _promptField(tk, _trigger, '예: 눈 뜨면 · 07:20 · 집 나서면 (비우면 “그다음”)'),
        // 트리거 밑 — 자주 쓰는 트리거 추천.
        _suggestionPills(
          ref.watch(routineTriggerSuggestionsProvider).valueOrNull,
          (v) => setState(() => _trigger.text = v),
        ),
      ],
    );
  }

  /// 추천 알약 칩 줄. 탭하면 해당 칸이 그 텍스트로 채워진다.
  Widget _suggestionPills(List<String>? items, ValueChanged<String> onPick) {
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final s in items)
            PillChip(label: s, onTap: () => onPick(s)),
        ],
      ),
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
    this.subtitle,
  });
  final String title;
  final String? subtitle;
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
        top: 12,
        bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 레퍼런스 sheet-head: 핸들 + [ 브래킷 제목 · 부제 ] + (삭제) + ✕
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                  color: tk.line, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppText.hTitle(tk.ink).copyWith(fontSize: 20)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(subtitle!,
                          style: AppText.meta(tk.inkSoft, size: 11)),
                    ],
                  ],
                ),
              ),
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10, top: 8),
                    child: Text('삭제', style: AppText.meta(tk.mark, size: 11)),
                  ),
                ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: tk.line)),
                  child: Text('✕', style: AppText.glyph(tk.ink, size: 15)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
            updatedAt: Value(DateTime.now()),
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
                hintText: '예: 아침 기상, 운동',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(6))),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 11)),
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
