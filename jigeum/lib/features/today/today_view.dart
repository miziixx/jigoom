import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/almanac.dart';
import '../../core/constants.dart';
import '../../core/editorial.dart';
import '../../core/gomgom_bear.dart';
import '../../core/journal.dart';
import '../../core/reference_tokens.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../capture/dump_staging.dart';
import '../capture/quick_capture_input.dart';
import '../fortune/fortune_view.dart';
import '../goal/goal_manage_screen.dart';
import '../timetrack/timer_panel.dart';
import 'node_detail_sheet.dart';

/// 오늘 — 기준 HTML `data-screen="today"` 구조를 그대로 이식.
/// 날짜 스트립 + day-context + today-filter + 저채도 일정 보드(오전/오후/저녁) + 요약.
/// (지금 v1 의 '오늘의 목표' 블록·글리프 목록 레이아웃은 제거.)
class TodayView extends ConsumerStatefulWidget {
  const TodayView({super.key});

  @override
  ConsumerState<TodayView> createState() => _TodayViewState();
}

/// 오늘 보드 한 항목.
class _TItem {
  const _TItem(this.title, this.cat,
      {this.min, this.done = false, this.held = false, this.meta = '', this.onToggle});
  final String title;
  final String cat; // study/focus/calm/habit/external/done
  final int? min; // 분(0~1439), null=시간 없음(종일)
  final bool done;
  final bool held;
  final String meta;
  final VoidCallback? onToggle;
}

class _TodayViewState extends ConsumerState<TodayView> {
  /// 선택 날짜(날짜 스트립). 기본 오늘.
  DateTime _sel = todayDate();

  /// 0 할 일 · 1 완료 · 2 보류.
  int _filter = 0;

  String _hhmm(int m) => minToShort(m);

  // ── 상단 일진·음력·달·별자리 (기준 HTML .day-context) → 탭 시 운세 ──
  Widget _dayContext(AppTokens tk) {
    final manse =
        '${iljin(_sel)} ${iljinHanja(_sel)} · ${lunarLabel(_sel)} · ${moonName(_sel)}';
    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: 64,
                  child: Text(label, style: AppText.meta(tk.inkSoft, size: 9))),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(value,
                      style: AppText.metaSans(tk.ink, size: 11)
                          .copyWith(height: 1.45))),
            ],
          ),
        );
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const FortuneView())),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: kGutter),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [line('오늘', manse), line('내 별자리', byeoljariLabel(_sel))],
            ),
          ),
          const SizedBox(width: 8),
          Text('›', style: AppText.glyph(tk.inkSoft, size: 18)),
        ]),
      ),
    );
  }

  // ── 곰곰이 인사 (리디자인 시안 — 아기곰 마스코트) ──
  Widget _greeting(AppTokens tk) => Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 2),
        child: Row(
          children: [
            const GomgomBear(size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Text('오늘도 곰곰이,\n천천히 시작해요.',
                  style: AppText.serif(tk.ink, size: 18, weight: FontWeight.w400)
                      .copyWith(height: 1.25)),
            ),
          ],
        ),
      );

  void _openTab(int i) => ref.read(homeTabProvider.notifier).state = i;
  void _pushScreen(Widget s) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));

  // ── 상시 캡처 바 — 탭하면 빠른 담기(리디자인 시안 capture) ──
  Widget _captureBar(AppTokens tk) => Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 2),
        child: GestureDetector(
          onTap: () => showQuickCaptureInput(context, ref),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(15, 13, 13, 13),
            decoration: BoxDecoration(
              color: tk.paper2,
              border: Border.all(color: tk.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('지금 떠오른 거, 그냥 적어요',
                          style: AppText.body(tk.ink).copyWith(fontSize: 15)),
                      const SizedBox(height: 3),
                      Text('적으면 알아서 정리돼요',
                          style: AppText.meta(tk.inkSoft, size: 9)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: tk.ink, borderRadius: BorderRadius.circular(12)),
                  child: Text('↑', style: AppText.glyph(tk.paper, size: 18)),
                ),
              ],
            ),
          ),
        ),
      );

  // ── 모멘텀 (오늘 완료 · 연속 · 진행 중) — 전부 실데이터 ──
  Widget _momentum(AppTokens tk, int doneN) {
    final streak = ref.watch(streakProvider);
    return ValueListenableBuilder<List<ActiveTimer>>(
      valueListenable: activeTimersNotifier,
      builder: (context, timers, _) => Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 2),
        child: Row(
          children: [
            Expanded(child: _mcard(tk, '오늘 완료', '$doneN', '개')),
            const SizedBox(width: 9),
            Expanded(child: _mcard(tk, '연속', '$streak', '일', honey: true)),
            const SizedBox(width: 9),
            Expanded(
                child: _mcard(tk, '진행 중', '${timers.length}', '개', live: true)),
          ],
        ),
      ),
    );
  }

  Widget _mcard(AppTokens tk, String label, String value, String unit,
      {bool live = false, bool honey = false}) {
    final bg = live ? mixOver(tk.mark, 0.12, tk.paper) : tk.paper2;
    final valColor = live || honey ? tk.mark : tk.ink;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: bg,
        border: live ? null : Border.all(color: tk.line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (live)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 5),
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: tk.mark),
              ),
            Text(label, style: AppText.meta(tk.inkSoft, size: 9)),
          ]),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: AppText.serif(valColor, size: 26, weight: FontWeight.w500)),
              const SizedBox(width: 2),
              Text(unit, style: AppText.meta(tk.inkSoft, size: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ── 섹션 라벨 ──
  Widget _sectionLabel(AppTokens tk, String title, {String? trailing, bool amber = false}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 22, kGutter, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(title,
                style: AppText.serif(tk.ink, size: 16, weight: FontWeight.w600)),
            const Spacer(),
            if (trailing != null)
              Text(trailing,
                  style: AppText.meta(amber ? tk.mark : tk.inkSoft, size: 10)),
          ],
        ),
      );

  // ── 기능 방 그리드 — 색으로 또렷하게, 실데이터 서브라벨 ──
  Widget _rooms(AppTokens tk) {
    final dumpN = ref.watch(dumpStagingProvider).length;
    final goalN = (ref.watch(goalsProvider).valueOrNull ?? const []).length;
    final habitN = (ref.watch(habitsProvider).valueOrNull ?? const []).length;
    final tickN =
        (ref.watch(habitTicksOnDateProvider(todayDate())).valueOrNull ?? const [])
            .length;
    final routineN =
        (ref.watch(routineStepsProvider).valueOrNull ?? const []).length;
    final activeN = activeTimersNotifier.value.length;
    final tiles = <Widget>[
      _roomTile(tk,
          glyph: '✦',
          name: '쏟아내기',
          sub: dumpN > 0 ? '$dumpN개 정리하기' : '생각나면 적어요',
          color: RefPalette.mineralBlue,
          onTap: () => _openTab(2)),
      _roomTile(tk,
          glyph: '◷',
          name: '시간',
          sub: activeN > 0 ? '$activeN개 진행 중' : '지금 뭐 하세요?',
          color: tk.mark,
          onTap: () => _openTab(3)),
      _roomTile(tk,
          glyph: '◎',
          name: '목표',
          sub: goalN > 0 ? '$goalN개 하는 중' : '목표 만들기',
          color: RefPalette.mineralSage,
          onTap: () => _pushScreen(const GoalManageScreen())),
      _roomTile(tk,
          glyph: '◇',
          name: '습관',
          sub: habitN > 0 ? '오늘 $tickN / $habitN' : '습관 만들기',
          color: RefPalette.mineralPlum,
          onTap: () => _openTab(4)),
      _roomTile(tk,
          glyph: '❖',
          name: '루틴',
          sub: routineN > 0 ? '$routineN단계' : '루틴 만들기',
          color: RefPalette.mineralTeal,
          onTap: () {
            ref.read(timeHubSubProvider.notifier).state = 3;
            _openTab(3);
          }),
      _roomTile(tk,
          glyph: '☾',
          name: '오늘 운세',
          sub: '오늘 운세 보기',
          color: RefPalette.mineralOchre,
          onTap: () => _pushScreen(const FortuneView())),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: tiles,
      ),
    );
  }

  Widget _roomTile(AppTokens tk,
          {required String glyph,
          required String name,
          required String sub,
          required Color color,
          required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tk.paper2,
            border: Border.all(color: tk.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: mixOver(color, 0.14, tk.paper),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(glyph, style: AppText.glyph(color, size: 16)),
              ),
              const Spacer(),
              Text(name,
                  style: AppText.body(tk.ink)
                      .copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(sub, style: AppText.meta(tk.inkSoft, size: 10)),
            ],
          ),
        ),
      );

  // ── 날짜 스트립 (기준 HTML .date-strip) — 선택 날짜가 속한 주(월~일) ──
  Widget _dateStrip(AppTokens tk) {
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    final monday = _sel.subtract(Duration(days: _sel.weekday - 1));
    final today = todayDate();
    return Container(
      margin: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
      padding: const EdgeInsets.only(bottom: 12),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Builder(builder: (_) {
              final d = monday.add(Duration(days: i));
              final sel = d == _sel;
              final isToday = d == today;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _sel = d),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: sel
                        ? BoxDecoration(
                            color: mixOver(tk.mark, 0.14, tk.paper),
                            borderRadius: BorderRadius.circular(14))
                        : null,
                    child: Column(
                      children: [
                        Text(wd[i],
                            style: AppText.meta(
                                sel ? tk.ink : tk.inkSoft,
                                size: 9)),
                        const SizedBox(height: 6),
                        Text('${d.day}',
                            style: AppText.metaSans(
                                sel ? tk.ink : tk.inkSoft,
                                size: 13)),
                        const SizedBox(height: 4),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday ? tk.mark : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── 필터 (기준 HTML .today-filter) 할 일 / 완료 / 보류 ──
  Widget _todayFilter(AppTokens tk) {
    Widget seg(int i, String label) {
      final sel = _filter == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _filter = i),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: sel
                ? BoxDecoration(
                    color: tk.paper, borderRadius: BorderRadius.circular(10))
                : null,
            child: Text(label,
                style: AppText.body(sel ? tk.ink : tk.inkSoft)
                    .copyWith(fontSize: 12)),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: tk.paper2, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [seg(0, '할 일'), seg(1, '완료'), seg(2, '보류')]),
    );
  }

  // 선택 날짜가 오늘일 때, '지금 진행 중'인 카드(가장 최근 시작한 미완료 시간 항목).
  // 다음 시간 항목이 시작되면 그쪽으로 넘어간다. 6시간 넘게 지난 잔여 항목은 제외.
  _TItem? _currentCard(List<_TItem> items) {
    if (_sel != todayDate()) return null;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    _TItem? best;
    for (final it in items) {
      if (it.done || it.held || it.min == null) continue;
      if (it.min! <= nowMin && (best == null || it.min! > best!.min!)) {
        best = it;
      }
    }
    if (best == null || nowMin - best!.min! > 360) return null;
    return best;
  }

  // ── 일정 카드 (기준 HTML .schedule-card) — 저채도 색면 + 시간 + 체크 + 본문 ──
  // current=true 면 좌측 포인트 레일 + `진행 중 · HH:MM:SS` 실시간 경과(card-kicker).
  Widget _card(AppTokens tk, _TItem it, {bool current = false}) {
    final bg = it.done ? tk.paper2 : scheduleCardTint(it.cat, tk.paper);
    final titleColor = it.done ? tk.inkSoft : tk.ink;
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(RefRadius.card)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(it.min != null ? _hhmm(it.min!) : '',
                style: AppText.meta(tk.inkSoft, size: 9)),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: it.onToggle,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 1),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: it.done ? tk.mark : Colors.transparent,
                border: Border.all(
                    color: it.done ? tk.mark : tk.inkSoft, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: it.done
                  ? Icon(Icons.check, size: 10, color: tk.paper)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // .card-kicker — 진행 중 + 실시간 경과(시작 시각부터 실제 경과).
                if (current) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('진행 중', style: AppText.meta(tk.mark, size: 9)),
                      _CurrentElapsed(startMin: it.min!, color: tk.ink),
                    ],
                  ),
                  const SizedBox(height: 7),
                ],
                Text(it.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(titleColor).copyWith(fontSize: 13)),
                if (it.meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(it.meta,
                        style: AppText.meta(tk.inkSoft, size: 10)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!current) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 9),
        child: card,
      );
    }
    // .schedule-card.current:before — 좌측 2px 포인트 레일(위아래 12 인셋).
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 9),
      child: Stack(
        children: [
          card,
          Positioned(
            left: 0,
            top: 12,
            bottom: 12,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: tk.mark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 선택 날짜의 모든 항목(일정·할 일·완료·보류) → _TItem 목록.
  List<_TItem> _collect(List<Schedule> schedules, List<Node> open, List<Node> wins) {
    final items = <_TItem>[];
    for (final s in schedules) {
      items.add(_TItem(
        s.title,
        s.gcalCalendarId != null ? 'external' : 'focus',
        min: s.startMin,
        done: s.done,
        meta: s.allDay ? '일정 · 종일' : '일정 · ${_hhmm(s.startMin)}',
        onToggle: () =>
            ref.read(scheduleRepoProvider).toggleDone(s.id, !s.done),
      ));
    }
    for (final n in open) {
      if (n.type != NodeType.task) continue;
      final held = n.status == NodeStatus.drawer;
      items.add(_TItem(
        n.title,
        held ? 'study' : 'calm',
        held: held,
        meta: held ? '보류' : '할 일',
        onToggle: () => ref.read(nodeRepoProvider).complete(n.id),
      ));
    }
    for (final n in wins) {
      final m = n.doneAt == null ? null : n.doneAt!.hour * 60 + n.doneAt!.minute;
      items.add(_TItem(
        n.title,
        'done',
        min: m,
        done: true,
        meta: m != null ? '완료 ${_hhmm(m)}' : '완료',
        onToggle: () => ref.read(nodeRepoProvider).reopen(n.id),
      ));
    }
    return items;
  }

  // 필터 + 시간대(오전/오후/저녁/종일) 그룹으로 카드 렌더.
  List<Widget> _board(AppTokens tk, List<_TItem> all, _TItem? current) {
    final list = all.where((it) {
      switch (_filter) {
        case 1:
          return it.done;
        case 2:
          return it.held;
        default:
          return !it.done && !it.held;
      }
    }).toList();

    if (list.isEmpty) {
      final msg = _filter == 1
          ? '아직 완료한 게 없어요'
          : _filter == 2
              ? '보류한 항목이 없어요'
              : '담아둔 게 없어요';
      return [emptyNote(context, msg)];
    }

    // 시간 있는 것 먼저(시간순), 없는 것 종일 그룹.
    list.sort((a, b) => (a.min ?? 1 << 30).compareTo(b.min ?? 1 << 30));
    String part(int? m) {
      if (m == null) return '종일';
      if (m < 720) return '오전';
      if (m < 1080) return '오후';
      return '저녁';
    }

    final out = <Widget>[];
    String? cur;
    for (final it in list) {
      final p = part(it.min);
      if (p != cur) {
        cur = p;
        final cnt = list.where((x) => part(x.min) == p).length;
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(kGutter + 1, 12, kGutter + 1, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(p, style: AppText.body(tk.ink).copyWith(fontSize: 12)),
              Text('$cnt', style: AppText.meta(tk.inkSoft, size: 10)),
            ],
          ),
        ));
      }
      out.add(_card(tk, it, current: identical(it, current)));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final schedules =
        ref.watch(schedulesForDateProvider(_sel)).valueOrNull ?? const [];
    final open =
        ref.watch(openNodesForDateProvider(_sel)).valueOrNull ?? const [];
    final wins = ref.watch(winsForDateProvider(_sel)).valueOrNull ?? const [];
    final items = _collect(schedules, open, wins);
    final current = _currentCard(items);
    final doneN = items.where((i) => i.done).length;
    final todoN = items.where((i) => !i.done && !i.held).length;

    return Container(
      color: tk.paper,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _greeting(tk),
          _captureBar(tk),
          _momentum(tk, doneN),
          _sectionLabel(tk, '지금 진행 중', trailing: '동시에 기록', amber: true),
          const TimerPanel(),
          _sectionLabel(tk, '바로 들어가기'),
          _rooms(tk),
          _sectionLabel(tk, '오늘의 흐름'),
          _dateStrip(tk),
          _dayContext(tk),
          _todayFilter(tk),
          ..._board(tk, items, current),
          // today-summary
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 20),
            child: Row(children: [
              Text('완료 $doneN', style: AppText.meta(tk.inkSoft, size: 9)),
              const SizedBox(width: 18),
              Text('남은 일정 $todoN', style: AppText.meta(tk.inkSoft, size: 9)),
            ]),
          ),
        ],
      ),
    );
  }
}

/// 오늘 진행 중 카드의 실시간 경과 — 시작 시각(오늘 startMin)부터 실제 경과를
/// 매초 다시 그려 HH:MM:SS 로 보여준다(가짜 시계 없음 · 화면 살아있는 동안만 틱).
class _CurrentElapsed extends StatefulWidget {
  const _CurrentElapsed({required this.startMin, required this.color});
  final int startMin;
  final Color color;

  @override
  State<_CurrentElapsed> createState() => _CurrentElapsedState();
}

class _CurrentElapsedState extends State<_CurrentElapsed> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _2(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(
        now.year, now.month, now.day, widget.startMin ~/ 60, widget.startMin % 60);
    final s = now.difference(start).inSeconds;
    final sec = s < 0 ? 0 : s;
    final text = '${_2(sec ~/ 3600)}:${_2((sec % 3600) ~/ 60)}:${_2(sec % 60)}';
    return Text(text, style: AppText.meta(widget.color, size: 9));
  }
}

/// 완료 시 짧은 텍스트 피드백 (코인·랜덤박스 없이 — 에세이의 "나쁜 보상" 회피).
/// 오늘 완료 누계를 세어 "완료했어요 · 오늘 N개째" SnackBar 를 띄운다.
Future<void> showDoneFeedback(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsProvider);
  // 모션·팝업 줄이기가 켜져 있으면 조용히 넘어간다(센서리 예민 대응).
  if (settings.reduceMotion) return;
  final n = await ref.read(nodeRepoProvider).winsCountForDate(todayDate());
  if (!context.mounted) return;
  var message = '완료했어요 · 오늘 $n개째';
  // '다음 할 일 자동 제안' — 완료 직후 남은 오늘 할 일 한 개만 짚어준다.
  if (settings.autoSuggestNext) {
    final open = (ref.read(todayNodesProvider).valueOrNull ?? const <Node>[])
        .where((x) => x.type != 'memo')
        .toList();
    if (open.isNotEmpty) message = '완료 · 다음 할 일 → ${open.first.title}';
  }
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 1400),
    ));
}

/// 태그 칩 — v17 레퍼런스 .tag(테두리 칩 + '#' 접두). accent=포인트색 테두리.
Widget _hash(AppTokens tk, String label, {bool accent = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: accent ? tk.mark : tk.line),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text('#$label',
          style: AppText.meta(accent ? tk.mark : tk.inkSoft, size: 9)),
    );

/// 편집형 할 일 줄: 글리프 체크 · 제목 · #해시태그 태그. 스와이프 우=완료, 좌=삭제.
/// (전체 할 일 화면에서 재사용.)
class SimpleTile extends ConsumerWidget {
  const SimpleTile({super.key, required this.node, this.showStar = true});

  final Node node;
  final bool showStar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final repo = ref.read(nodeRepoProvider);
    final done = node.status == NodeStatus.done;

    final tile = InkWell(
      onTap: () => showNodeDetailSheet(context, node),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 7, kGutter, 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                if (done) {
                  await repo.reopen(node.id);
                } else {
                  await repo.complete(node.id);
                  if (context.mounted) showDoneFeedback(context, ref);
                }
              },
              child: EdCheck(done: done),
            ),
            const SizedBox(width: 12),
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
                  if (!done)
                    Builder(builder: (_) {
                      final tags = <Widget>[];
                      if (node.date == todayDate()) {
                        tags.add(_hash(tk, '오늘', accent: true));
                      } else if (node.date != null) {
                        tags.add(
                            _hash(tk, DateFormat('M/d').format(node.date!)));
                      }
                      if (node.important) {
                        tags.add(_hash(tk, '중요', accent: true));
                      }
                      if (node.urgent) tags.add(_hash(tk, '긴급', accent: true));
                      if (tags.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child:
                            Wrap(spacing: 8, runSpacing: 2, children: tags),
                      );
                    }),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => showNodeDetailSheet(context, node),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 1),
                child: Text('⋯', style: AppText.glyph(tk.inkSoft, size: 16)),
              ),
            ),
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
