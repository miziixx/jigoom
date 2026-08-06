import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/reference_tokens.dart';
import '../../core/theme.dart';
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

    final tiles = <_FlowTile>[
      _FlowTile('01', '아웃라이너', '목표와 할 일의 전체 구조',
          () => push(const OutlineScreen())),
      _FlowTile('02', '목표 관리', '진행률과 활동 그래프',
          () => push(const GoalManageScreen())),
      _FlowTile('03', '습관', '최근 30일 반복 기록', () => onOpenTab(4)),
      _FlowTile('04', '루틴', '일과 · 주간 · 로그', () => onOpenTab(3)),
      _FlowTile('05', '전체 할 일', '필터와 완료 상태', () => onOpenTab(5)),
      _FlowTile('06', '매트릭스', '중요도와 긴급도', () => onOpenTab(1)),
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
        Text('최근 흐름', style: AppText.body(tk.ink).copyWith(fontSize: 16)),
        const SizedBox(height: 5),
        Text('열어본 화면이 여기에 모입니다.',
            style: AppText.body(tk.inkSoft).copyWith(fontSize: 11)),
      ],
    );
  }

  Widget _tile(AppTokens tk, _FlowTile tile) => GestureDetector(
        onTap: tile.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tk.paper2,
            border: Border.all(color: tk.line),
            borderRadius: BorderRadius.circular(RefRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tile.index, style: AppText.meta(tk.inkSoft, size: 9)),
              const Spacer(),
              Text(tile.title, style: AppText.body(tk.ink).copyWith(fontSize: 13)),
              const SizedBox(height: 5),
              Text(tile.desc,
                  style: AppText.body(tk.inkSoft)
                      .copyWith(fontSize: 9, height: 1.45)),
            ],
          ),
        ),
      );
}

class _FlowTile {
  const _FlowTile(this.index, this.title, this.desc, this.onTap);
  final String index;
  final String title;
  final String desc;
  final VoidCallback onTap;
}
