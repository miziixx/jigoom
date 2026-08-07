import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/almanac.dart';
import '../../core/constants.dart';
import '../../core/editorial.dart';
import '../../core/journal.dart';
import '../../core/reference_tokens.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../fortune/fortune_view.dart';
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

  // ── 일정 카드 (기준 HTML .schedule-card) — 저채도 색면 + 시간 + 체크 + 본문 ──
  Widget _card(AppTokens tk, _TItem it) {
    final bg = it.done ? tk.paper2 : scheduleCardTint(it.cat, tk.paper);
    final titleColor = it.done ? tk.inkSoft : tk.ink;
    return Container(
      margin: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 9),
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
  List<Widget> _board(AppTokens tk, List<_TItem> all) {
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
      out.add(_card(tk, it));
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
    final doneN = items.where((i) => i.done).length;
    final todoN = items.where((i) => !i.done && !i.held).length;

    return Container(
      color: tk.paper,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _dateStrip(tk),
          _dayContext(tk),
          _todayFilter(tk),
          ..._board(tk, items),
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
