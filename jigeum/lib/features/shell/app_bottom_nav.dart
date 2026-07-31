import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers.dart';
import '../capture/quick_capture_input.dart';

/// 공용 하단 네비게이션 — 홈/오늘/＋(담기)/일과/전체.
/// 셸(홈 탭)뿐 아니라 푸시 화면(목표·달력·운세·아웃라인·보류함)에서도 재사용한다.
/// 탭을 누르면 [homeTabProvider] 를 바꾸고 루트(셸)까지 돌아가 그 탭을 연다.
class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({super.key, this.onQuickAdd});

  /// 가운데 '담기' 동작을 화면 맥락에 맞게 재정의(예: 목표관리=목표 추가).
  /// null 이면 현재 탭에 맞춘 빠른 담기(할 일/습관/일정/메모).
  final VoidCallback? onQuickAdd;

  /// 현재 탭에 맞는 빠른 담기 유형.
  static String _captureTypeForTab(int index) => switch (index) {
        4 => 'habit',
        3 => 'schedule',
        2 => 'memo',
        _ => 'task',
      };

  void _go(BuildContext context, WidgetRef ref, int i) {
    ref.read(homeTabProvider.notifier).state = i;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final index = ref.watch(homeTabProvider);

    Widget item(int idx, String label, IconData icon) {
      final active = index == idx;
      final color = active ? tk.ink : tk.inkSoft;
      return Expanded(
        child: GestureDetector(
          onTap: () => _go(context, ref, idx),
          behavior: HitTestBehavior.opaque,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: color),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.only(bottom: 2),
                  decoration: active
                      ? BoxDecoration(
                          border: Border(
                              bottom:
                                  BorderSide(color: tk.mark, width: 1.2)))
                      : null,
                  child: Text(label,
                      style: AppText.nav(color).copyWith(fontSize: 8)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tk.line, width: 1))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              item(6, '홈', Icons.home_outlined),
              item(0, '오늘', Icons.calendar_today_outlined),
              Expanded(
                child: GestureDetector(
                  onTap: onQuickAdd ??
                      () => showQuickCaptureInput(context, ref,
                          presetType: _captureTypeForTab(index)),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: tk.mark, shape: BoxShape.circle),
                        child: Icon(Icons.add, color: tk.paper, size: 24),
                      ),
                      const SizedBox(height: 3),
                      Text('담기',
                          style: AppText.nav(tk.inkSoft).copyWith(fontSize: 8)),
                    ],
                  ),
                ),
              ),
              item(3, '일과', Icons.article_outlined),
              item(5, '전체', Icons.reorder),
            ],
          ),
        ),
      ),
    );
  }
}
