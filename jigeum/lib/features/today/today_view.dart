import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/energy.dart';
import '../../core/journal.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../focus/focus_timer_view.dart';
import 'goal_editor.dart';
import 'node_detail_sheet.dart';
import 'plant_view.dart';
import 'stuck_sheet.dart';

/// 오늘 뷰 (홈) — 편집(에디토리얼) 목차형.
/// 큰 날짜(Sans) → NOW(포커스) → TO-DO → DONE, 규칙선으로 구분. 카드 없음.
class TodayView extends ConsumerStatefulWidget {
  const TodayView({super.key});

  @override
  ConsumerState<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends ConsumerState<TodayView> {
  bool _winsOpen = false;
  String _goal = '';

  @override
  void initState() {
    super.initState();
    ref.read(scheduleRepoProvider).getDayGoal(todayDate()).then((v) {
      if (mounted) setState(() => _goal = v ?? '');
    });
  }

  Future<void> _editGoal() async {
    final g = await showGoalEditor(context, ref);
    if (g == null) return;
    if (mounted) setState(() => _goal = g);
  }

  /// 오늘의 목표 블록 — 맨 위, 크고 굵게, 여러 줄 리스트. 탭해서 편집.
  Widget _goalBlock(AppTokens tk) {
    final lines = _goal
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final goalStyle = AppText.hTitle(tk.ink).copyWith(fontSize: 22, height: 1.3);
    return InkWell(
      onTap: _editGoal,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('GOAL', style: AppText.sec(tk.mark)),
                const SizedBox(width: 12),
                Expanded(child: Container(height: 1, color: tk.line)),
              ],
            ),
            const SizedBox(height: 12),
            if (lines.isEmpty)
              Text('탭해서 오늘의 목표 적기',
                  style: goalStyle.copyWith(color: tk.inkSoft))
            else
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('★ ', style: goalStyle.copyWith(color: tk.mark)),
                      Expanded(child: Text(line, style: goalStyle)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final focus = ref.watch(focusProvider);
    final today = ref.watch(todayNodesProvider).valueOrNull ?? const [];
    final wins = ref.watch(todayWinsProvider).valueOrNull ?? const [];
    final sky = ref.watch(settingsProvider);
    final now = DateTime.now();

    final metaParts = <String>[DateFormat('EEEE', 'ko').format(now)];
    if (sky.showSaju) metaParts.add(sajuLabel(now));
    if (sky.showZodiac) metaParts.add(byeoljariLabel(now));

    // 시작 카운트(완료 아닌 '시작'을 세는 자기효능감) + 다음 일정까지 남은 시간(시간 실명 대응).
    final startedToday = ref.watch(startedTodayProvider).valueOrNull ?? 0;
    final todaySchedules =
        ref.watch(schedulesForDateProvider(todayDate())).valueOrNull ??
            const [];
    final nowMin = now.hour * 60 + now.minute;
    final upcoming = [...todaySchedules]
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
    Schedule? nextSchedule;
    for (final s in upcoming) {
      if (!s.done && !s.allDay && s.startMin > nowMin) {
        nextSchedule = s;
        break;
      }
    }
    // 에너지 사이클 — 집중 피크(사주 運氣를 행동 데이터로 근사).
    final peak = ref.watch(energyPeakProvider);
    final peakStr =
        peak != null ? peakLabel(peak.startHour, peak.endHour) : null;

    final scaffoldParts = <String>[
      if (startedToday > 0) '오늘 $startedToday번 시작',
      if (nextSchedule != null)
        '다음 · ${nextSchedule.title} 까지 ${_untilLabel(nextSchedule.startMin - nowMin)}',
      if (peakStr != null) '피크 $peakStr',
    ];

    final children = <Widget>[
      // GOAL — 오늘의 목표 (맨 위, 크고 굵게, 탭해서 편집)
      _goalBlock(tk),

      // 큰 날짜 (Sans) + 요일 (Mono meta)
      Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(DateFormat('M월 d일', 'ko').format(now),
                style: AppText.hTitle(tk.ink)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(metaParts.join(' · '),
                  style: AppText.metaSans(tk.inkSoft)),
            ),
          ],
        ),
      ),

      // 시작 카운트 + 다음 일정 카운트다운 (있을 때만)
      if (scaffoldParts.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
          child: Text(scaffoldParts.join('   ·   '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.meta(tk.inkSoft, size: 11)),
        ),

      // 오늘의 식물 — 완료·시작이 쌓일수록 자라는 잔잔한 보상
      const PlantBand(),

      // NOW — 지금 이것부터
      focus.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (node) =>
            node == null ? const SizedBox.shrink() : _FocusBlock(node: node),
      ),

      // TO-DO
      SectionLabel('TO-DO', count: today.length),
      if (today.isEmpty)
        emptyNote(context, '아래에 적으면 여기 쌓여요')
      else
        for (final n in today) SimpleTile(node: n),

      // DONE (오늘의 승리)
      if (wins.isNotEmpty) ...[
        SectionLabel(
          'DONE',
          count: wins.length,
          onTap: () => setState(() => _winsOpen = !_winsOpen),
          trailing: Text(_winsOpen ? '−' : '+',
              style: AppText.meta(tk.inkSoft, size: 13)),
        ),
        if (_winsOpen)
          for (final n in wins) SimpleTile(node: n),
      ],

      const SizedBox(height: 16),
    ];

    return Container(
      color: tk.paper,
      child: ListView(
        padding: EdgeInsets.zero,
        children: children,
      ),
    );
  }
}

/// 남은 시간 라벨 — 60분 미만은 분, 그 이상은 시간+분.
String _untilLabel(int minutes) {
  if (minutes < 60) return '$minutes분';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h시간' : '$h시간 $m분';
}

/// 포커스 블록 — 카드가 아니라 라벨 + 규칙선 + 한 줄. mark 캐럿으로 강조.
class _FocusBlock extends ConsumerWidget {
  const _FocusBlock({required this.node});
  final Node node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 26, kGutter, 12),
          child: Row(
            children: [
              Text('› NOW', style: AppText.sec(tk.mark)),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 1, color: tk.line)),
            ],
          ),
        ),
        InkWell(
          onTap: () => showNodeDetailSheet(context, node),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlyphCheck(
                  done: false,
                  onTap: () async {
                    await ref.read(nodeRepoProvider).complete(node.id);
                    if (context.mounted) showDoneFeedback(context, ref);
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(node.title, style: AppText.body(tk.ink)),
                      if (node.nextStep != null && node.nextStep!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text('다음 · ${node.nextStep}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.meta(tk.inkSoft)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // 지금 조금만 시작 — 생각 단계를 줄여 바로 진입. + 막혔을 때 탈출구.
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 4),
          child: Row(
            children: [
              GestureDetector(
                onTap: () =>
                    openFocusTimer(context, node: node, autoStartMinutes: 3),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: tk.line, width: 1),
                  ),
                  child: Text('▷ 3분만 시작', style: AppText.chip(tk.ink)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => showStuckSheet(context, ref, node),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: tk.line, width: 1),
                  ),
                  child: Text('막혔어', style: AppText.chip(tk.inkSoft)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 완료 시 짧은 텍스트 피드백 (코인·랜덤박스 없이 — 에세이의 "나쁜 보상" 회피).
/// 오늘 완료 누계를 세어 "완료했어요 · 오늘 N개째" SnackBar 를 띄운다.
Future<void> showDoneFeedback(BuildContext context, WidgetRef ref) async {
  // 모션·팝업 줄이기가 켜져 있으면 조용히 넘어간다(센서리 예민 대응).
  if (ref.read(settingsProvider).reduceMotion) return;
  final n = await ref.read(nodeRepoProvider).winsCountForDate(todayDate());
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text('완료했어요 · 오늘 $n개째'),
      duration: const Duration(milliseconds: 1400),
    ));
}

/// 편집형 할 일 줄: 글리프 체크 · 제목(한글 Sans) · 메타(메모/마감) · 우선순위 라벨.
/// 완료 = 글리프 ■ + 제목 inkSoft + 취소선. 스와이프 우=완료, 좌=삭제.
class SimpleTile extends ConsumerWidget {
  const SimpleTile({super.key, required this.node, this.showStar = true});

  final Node node;
  final bool showStar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final repo = ref.read(nodeRepoProvider);
    final done = node.status == NodeStatus.done;
    final showDeadline = node.date != null && node.date != todayDate() && !done;
    final pri = done
        ? null
        : priorityLabel(context,
            urgent: node.urgent, important: node.important);

    final tile = InkWell(
      onTap: () => showNodeDetailSheet(context, node),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 7, kGutter, 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlyphCheck(
              done: done,
              onTap: () async {
                if (done) {
                  await repo.reopen(node.id);
                } else {
                  await repo.complete(node.id);
                  if (context.mounted) showDoneFeedback(context, ref);
                }
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.title,
                      // v17: 완료는 취소선이 아니라 흐림(opacity)으로 — EdTaskRow와 통일.
                      style: AppText.body(
                          done ? tk.ink.withValues(alpha: 0.5) : tk.ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (node.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(node.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.meta(tk.inkSoft)),
                    ),
                  if (done && node.doneAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                          '${DateFormat('HH:mm').format(node.doneAt!)} 완료',
                          style: AppText.meta(tk.mark, size: 10)),
                    ),
                ],
              ),
            ),
            if (showDeadline) ...[
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: deadlineLabel(context, node.date!),
              ),
            ],
            if (pri != null) ...[
              const SizedBox(width: 10),
              Padding(padding: const EdgeInsets.only(top: 2), child: pri),
            ],
          ],
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('tile_${node.id}'),
      background: _swipeBg(tk, Alignment.centerLeft, done ? '□' : '■'),
      secondaryBackground: _swipeBg(tk, Alignment.centerRight, '×'),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          if (done) {
            await repo.reopen(node.id);
          } else {
            await repo.complete(node.id);
            if (context.mounted) showDoneFeedback(context, ref);
          }
          return false;
        }
        await repo.deleteNode(node.id);
        return false;
      },
      child: tile,
    );
  }

  Widget _swipeBg(AppTokens tk, Alignment align, String glyph) => Container(
        alignment: align,
        color: tk.paper2,
        padding: const EdgeInsets.symmetric(horizontal: kGutter),
        child: Text(glyph, style: AppText.glyph(tk.inkSoft, size: 16)),
      );
}
