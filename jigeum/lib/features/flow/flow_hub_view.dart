import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/reference_tokens.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../goal/goal_manage_screen.dart';
import '../outline/outline_screen.dart';

/// 흐름 허브 — 기준 HTML `data-screen="flow"`.
/// 아웃라이너·목표 관리·습관·루틴·전체 할 일·매트릭스로 들어가는 6진입 그리드.
/// (상단 헤더는 셸 [Masthead] 가 그린다 — 여기선 본문만.)
///
/// 탭 본문(습관·루틴·전체·매트릭스)은 [onOpenTab] 으로 셸 탭을 바꾸고,
/// 푸시 화면(아웃라이너·목표 관리)은 Navigator push 한다.
class FlowHubView extends ConsumerWidget {
  const FlowHubView({super.key, required this.onOpenTab});

  final void Function(int index) onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    void push(Widget s) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));

    // 최근 흐름 — 완료·추가한 목표/할 일을 시각순 실데이터 피드로.
    final all = ref.watch(allNodesProvider).valueOrNull ?? const <Node>[];
    final recent = (all
            .where((n) => n.type == NodeType.task || n.type == NodeType.goal)
            .map((n) => (
                  time: n.doneAt ?? n.createdAt,
                  title: n.title,
                  done: n.status == NodeStatus.done,
                  goal: n.type == NodeType.goal,
                ))
            .toList()
          ..sort((a, b) => b.time.compareTo(a.time)))
        .take(8)
        .toList();

    final tiles = <_FlowTile>[
      _FlowTile('▤', RefPalette.mineralBlue, '아웃라이너', '목표와 할 일의 전체 구조',
          () => push(const OutlineScreen())),
      _FlowTile('◎', RefPalette.mineralSage, '목표 관리', '진행률과 활동 그래프',
          () => push(const GoalManageScreen())),
      _FlowTile('◇', RefPalette.mineralPlum, '습관', '최근 30일 반복 기록',
          () => onOpenTab(4)),
      _FlowTile('❖', RefPalette.mineralTeal, '루틴', '일과 · 주간 · 로그',
          () => onOpenTab(3)),
      _FlowTile('☰', RefPalette.mineralOchre, '전체 할 일', '필터와 완료 상태',
          () => onOpenTab(5)),
      _FlowTile('⊞', RefPalette.mineralRose, '매트릭스', '중요도와 긴급도',
          () => onOpenTab(1)),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 4, AppSpace.gutter, 28),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          childAspectRatio: 1.5,
          children: [for (final tile in tiles) _tile(tk, tile)],
        ),
        const SizedBox(height: 25),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('최근 흐름', style: AppText.body(tk.ink).copyWith(fontSize: 16)),
            const SizedBox(width: 8),
            Text('완료·추가한 순서대로',
                style: AppText.meta(tk.inkSoft, size: 10)),
          ],
        ),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          Text('아직 활동이 없어요.',
              style: AppText.body(tk.inkSoft).copyWith(fontSize: 11))
        else
          for (final a in recent)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(top: 4, right: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: a.done ? tk.mark : tk.inkSoft,
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(_ago(a.time),
                        style: AppText.meta(tk.inkSoft, size: 10)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(tk.ink).copyWith(fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                            a.done
                                ? (a.goal ? '목표 · 완료' : '완료')
                                : (a.goal ? '목표 · 추가' : '할 일 · 추가'),
                            style: AppText.meta(tk.inkSoft, size: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  String _ago(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (now.year == dt.year && now.month == dt.month && now.day == dt.day) {
      return '오늘 ${_2(dt.hour)}:${_2(dt.minute)}';
    }
    if (diff.inDays < 2) return '어제';
    return '${dt.month}/${dt.day}';
  }

  static String _2(int n) => n.toString().padLeft(2, '0');

  Widget _tile(AppTokens tk, _FlowTile tile) => GestureDetector(
        onTap: tile.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tk.paper2,
            border: Border.all(color: tk.line),
            borderRadius: BorderRadius.circular(RefRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 색별 글리프 방(리디자인 시안) — 기능마다 또렷한 색.
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: mixOver(tile.color, 0.14, tk.paper),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(tile.glyph, style: AppText.glyph(tile.color, size: 16)),
              ),
              const Spacer(),
              Text(tile.title, style: AppText.body(tk.ink).copyWith(fontSize: 13)),
              const SizedBox(height: 4),
              Text(tile.desc,
                  style: AppText.body(tk.inkSoft)
                      .copyWith(fontSize: 9, height: 1.45)),
            ],
          ),
        ),
      );
}

class _FlowTile {
  const _FlowTile(this.glyph, this.color, this.title, this.desc, this.onTap);
  final String glyph;
  final Color color;
  final String title;
  final String desc;
  final VoidCallback onTap;
}
