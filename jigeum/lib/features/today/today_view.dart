import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/almanac.dart';
import '../../core/constants.dart';
import '../../core/editorial.dart';
import '../../core/journal.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../capture/quick_capture_input.dart';
import '../fortune/fortune_view.dart';
import 'goal_editor.dart';
import 'node_detail_sheet.dart';

/// 오늘 뷰 (홈) — 편집(에디토리얼) 목차형.
/// 큰 날짜(Sans) → NOW(포커스) → TO-DO → DONE, 규칙선으로 구분. 카드 없음.
class TodayView extends ConsumerStatefulWidget {
  const TodayView({super.key});

  @override
  ConsumerState<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends ConsumerState<TodayView> {
  /// 오늘 목록 필터 — 0 전체 · 1 미완료 · 2 중요 · 3 긴급.
  int _filter = 0;
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

  /// 상단 일진·음력·달 위상·별자리 컨텍스트 (기준 HTML `.day-context`).
  /// 탭하면 오늘의 운세로 이동. 계산은 기존 만세력/별자리 코어 재사용.
  Widget _dayContext(AppTokens tk) {
    final today = todayDate();
    final manse =
        '${iljin(today)} ${iljinHanja(today)} · ${lunarLabel(today)} · ${moonName(today)}';
    final zodiac = byeoljariLabel(today);

    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Text(label, style: AppText.meta(tk.inkSoft, size: 9)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(value,
                    style: AppText.metaSans(tk.ink, size: 11)
                        .copyWith(height: 1.45)),
              ),
            ],
          ),
        );

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FortuneView())),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: kGutter),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [line('오늘', manse), line('내 별자리', zodiac)],
              ),
            ),
            const SizedBox(width: 8),
            Text('›', style: AppText.glyph(tk.inkSoft, size: 18)),
          ],
        ),
      ),
    );
  }

  /// 오늘의 목표 블록 — v17: 중앙 정렬. 짧은 초록 밑줄 + TODAY'S GOAL + 큰 세리프
  /// 목표 + 안내문 + 진행바(오늘 완료/전체). 탭해서 편집.
  Widget _goalBlock(AppTokens tk, int done, int total) {
    final lines = _goal
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final pct = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    // 레퍼런스 .goal-card(에디토리얼) — 왼쪽 포인트 세로선, 왼쪽정렬.
    return InkWell(
      onTap: _editGoal,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: tk.mark, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("TODAY'S GOAL",
                  style: AppText.meta(tk.mark, size: 10)
                      .copyWith(letterSpacing: 0.5)),
              const SizedBox(height: 10),
              if (lines.isEmpty)
                Text('탭해서 오늘의 목표를 적어요',
                    style: AppText.serif(tk.inkSoft, size: 16, height: 1.3))
              else
                for (final line in lines)
                  Text(line,
                      style: AppText.serif(tk.ink, size: 16, height: 1.3)),
              const SizedBox(height: 6),
              Text('오늘 가장 중요한 결과 하나. 탭해서 언제든 수정할 수 있어요.',
                  style: AppText.body(tk.inkSoft)
                      .copyWith(fontSize: 10, height: 1.55)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Container(height: 3, color: tk.line),
                        FractionallySizedBox(
                          widthFactor: pct,
                          child: Container(height: 3, color: tk.ink),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('$done / $total',
                      style: AppText.meta(tk.inkSoft, size: 10)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 필터에 맞춰 오늘 항목을 타일 목록으로. 미완료(open)+완료(wins)를 합쳐
  /// 필터링하므로 '전체·중요·긴급'에서 완료 항목도 계속 보이고 토글도 된다.
  List<Widget> _filteredTiles(
      BuildContext context, List<Node> open, List<Node> wins) {
    final all = <Node>[...open, ...wins];
    final List<Node> list;
    switch (_filter) {
      case 1: // 미완료
        list = open;
        break;
      case 2: // 중요
        list = all.where((n) => n.important).toList();
        break;
      case 3: // 긴급
        list = all.where((n) => n.urgent).toList();
        break;
      default: // 전체
        list = all;
    }
    if (list.isEmpty) {
      return [
        emptyNote(context, _filter == 0 ? '아래에 적으면 여기 쌓여요' : '해당하는 일이 없어요'),
      ];
    }
    return [for (final n in list) SimpleTile(node: n)];
  }

  /// § 오늘 할 일 + 추가 (레퍼런스 헤더).
  Widget _todoSectionHead() {
    final tk = t(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 22, kGutter, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('§ ', style: AppText.hTitle(tk.mark).copyWith(fontSize: 15)),
              Text('오늘 할 일',
                  style: AppText.hTitle(tk.ink).copyWith(fontSize: 16)),
              const Spacer(),
              GestureDetector(
                onTap: () => showQuickCaptureInput(context, ref),
                behavior: HitTestBehavior.opaque,
                child: Text('＋ 추가', style: AppText.meta(tk.mark, size: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: tk.line),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final today = ref.watch(todayNodesProvider).valueOrNull ?? const [];
    final wins = ref.watch(todayWinsProvider).valueOrNull ?? const [];

    final children = <Widget>[
      // 상단 컨텍스트 — 일진·음력·달 위상·별자리 (기준 HTML .day-context)
      _dayContext(tk),

      // GOAL — 오늘의 목표 (중앙 정렬 + 진행바, 탭해서 편집)
      _goalBlock(tk, wins.length, today.length + wins.length),

      // § 오늘 할 일 + 추가 (레퍼런스 헤더)
      _todoSectionHead(),

      // 필터 — 전체 / 미완료 / 중요 / 긴급 (레퍼런스 .filter-row 칩).
      Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                PillChip(
                  label: const ['전체', '미완료', '중요', '긴급'][i],
                  selected: _filter == i,
                  onTap: () => setState(() => _filter = i),
                ),
              ],
            ],
          ),
        ),
      ),
      ..._filteredTiles(context, today, wins),

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
