import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../fortune/fortune_view.dart';
import '../inbox/inbox_screen.dart';
import '../outline/outline_screen.dart';
import '../schedule/calendar_view.dart';
import '../settings/settings_screen.dart';

/// 사이드바 메뉴(에디토리얼) — 홈 셸뿐 아니라 푸시 화면(아웃라인·달력·운세·
/// 보류함·설정)에서도 endDrawer 로 재사용한다. 탭 항목은 [homeTabProvider] 를
/// 바꾸고 루트(셸)까지 pop 해서 그 탭으로, 푸시 항목은 루트로 돌아간 뒤 push.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final currentTab = ref.watch(homeTabProvider);

    // 탭을 먼저 바꾸고(셸이 구독 중) 루트까지 pop — pop 후 ref 사용을 피한다.
    void goTab(int index) {
      ref.read(homeTabProvider.notifier).state = index;
      Navigator.of(context).popUntil((r) => r.isFirst);
    }

    // 루트(셸)까지 되돌아간 뒤 해당 화면 push.
    void goPush(Widget screen) {
      final nav = Navigator.of(context);
      nav.popUntil((r) => r.isFirst);
      nav.push(MaterialPageRoute(builder: (_) => screen));
    }

    Widget row(String index, String label, VoidCallback onTap,
        {int? tabIndex}) {
      final current = tabIndex != null && currentTab == tabIndex;
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tk.line, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Container(
                width: 2,
                height: 16,
                color: current ? tk.mark : Colors.transparent,
              ),
              const SizedBox(width: 11),
              SizedBox(
                width: 24,
                child: Text(index, style: AppText.meta(tk.inkSoft, size: 9)),
              ),
              Expanded(
                child: Text(label,
                    style: AppText.body(current ? tk.mark : tk.ink).copyWith(
                        fontSize: 12, fontWeight: FontWeight.w400)),
              ),
              Text('›', style: AppText.glyph(tk.inkSoft, size: 14)),
            ],
          ),
        ),
      );
    }

    return Drawer(
      backgroundColor: tk.paper,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kGutter),
          child: ListView(
            children: [
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('지금',
                            style: AppText.hTitle(tk.ink)
                                .copyWith(fontSize: 24, letterSpacing: -1.0)),
                        const SizedBox(height: 4),
                        Text('내 하루를 바깥에 꺼내두는 곳',
                            style: AppText.meta(tk.inkSoft, size: 9)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: tk.line),
                      ),
                      child: Text('×', style: AppText.glyph(tk.ink, size: 20)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: tk.line),
              row('01', '홈', () => goTab(6), tabIndex: 6),
              row('02', '오늘', () => goTab(0), tabIndex: 0),
              row('03', '매트릭스', () => goTab(1), tabIndex: 1),
              row('04', '일과', () => goTab(3), tabIndex: 3),
              row('05', '쏟아내기', () => goTab(2), tabIndex: 2),
              row('06', '전체', () => goTab(5), tabIndex: 5),
              row('07', '아웃라인', () => goPush(const OutlineScreen())),
              row('08', '습관', () => goTab(4), tabIndex: 4),
              row('09', '달력', () => goPush(const CalendarScreen())),
              row('10', '오늘의 운세', () => goPush(const FortuneView())),
              row('11', '설정', () => goPush(const SettingsScreen())),
              row('12', '보류함',
                  () => goPush(InboxScreen(repository: ref.read(inboxRepoProvider)))),
            ],
          ),
        ),
      ),
    );
  }
}
