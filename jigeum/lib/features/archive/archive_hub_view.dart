import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../fortune/fortune_view.dart';
import '../inbox/inbox_screen.dart';
import '../schedule/calendar_view.dart';
import '../settings/settings_screen.dart';

/// 보관 허브 — 기준 HTML `data-screen="archive"`.
/// 쏟아내기·보류함·완료 기록·오늘의 운세·달력·설정으로 가는 6개 링크.
/// (상단 헤더는 셸 [Masthead] 가 그린다 — 여기선 본문만.)
class ArchiveHubView extends ConsumerWidget {
  const ArchiveHubView({super.key, required this.onOpenTab});

  final void Function(int index) onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    void push(Widget s) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));

    final links = <_ArchiveLink>[
      _ArchiveLink('01', '쏟아내기', '생각과 메모를 빠르게 기록', () => onOpenTab(2)),
      _ArchiveLink('02', '보류함', '나중에 다시 볼 항목',
          () => push(InboxScreen(repository: ref.read(inboxRepoProvider)))),
      _ArchiveLink('03', '완료 기록', '완료한 항목 모아 보기', () => onOpenTab(5)),
      _ArchiveLink('04', '오늘의 운세', '행동 카드와 하루 흐름',
          () => push(const FortuneView())),
      _ArchiveLink('05', '달력', '일정과 기록을 날짜별로 보기',
          () => push(const CalendarScreen())),
      _ArchiveLink('06', '설정', '테마 · 글자 · 백업 · 연동',
          () => push(const SettingsScreen())),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 8, AppSpace.gutter, 28),
      children: [
        Container(height: 1, color: tk.line),
        for (final link in links) _row(tk, link),
      ],
    );
  }

  Widget _row(AppTokens tk, _ArchiveLink link) => GestureDetector(
        onTap: link.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tk.line)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 34,
                child: Text(link.index, style: AppText.meta(tk.inkSoft, size: 9)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(link.title,
                        style: AppText.serif(tk.ink, size: 16, weight: FontWeight.w400)),
                    const SizedBox(height: 3),
                    Text(link.desc,
                        style: AppText.body(tk.inkSoft).copyWith(fontSize: 10)),
                  ],
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tk.inkSoft),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ArchiveLink {
  const _ArchiveLink(this.index, this.title, this.desc, this.onTap);
  final String index;
  final String title;
  final String desc;
  final VoidCallback onTap;
}
