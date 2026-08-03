import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/repos/time_track_repository.dart';
import '../../providers.dart';
import '../capture/prompt_bar.dart';
import '../timetrack/time_track_screen.dart';
import 'calendar_view.dart';
import 'day_view.dart';
import 'routine_screen.dart';
import 'weekly_plan_view.dart';

/// 시간 허브 — 일과 탭. 하위: 데이 / 주간 / 달력 / 루틴 / 기록.
/// (기존 plan·day·schedule 은 'day' 하나로 통합됨.)
class TimeHub extends ConsumerStatefulWidget {
  const TimeHub({super.key});

  @override
  ConsumerState<TimeHub> createState() => _TimeHubState();
}

class _TimeHubState extends ConsumerState<TimeHub> {
  // 하위 탭은 provider 로 관리(하단 담기가 탭별 추가 흐름을 열 수 있게).
  int get _sub => ref.read(timeHubSubProvider);

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    ref.watch(timeHubSubProvider); // 하위 탭 변경 시 다시 그림.
    return Column(
      children: [
        _subBar(tk),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: kGutter),
          height: 1,
          color: tk.line,
        ),
        Expanded(
          child: IndexedStack(
            index: _sub,
            children: const [
              DayView(),
              WeeklyPlanBody(),
              CalendarView(),
              RoutineBody(),
              TimeTrackBody(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _subBar(AppTokens tk) {
    Widget tab(int i, String label) {
      final sel = _sub == i;
      return GestureDetector(
        onTap: () => ref.read(timeHubSubProvider.notifier).state = i,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: sel ? tk.ink : Colors.transparent, width: 1.5),
              ),
            ),
            // 레퍼런스 최종 .segmented button — 모노 10px, 굵기 500, 활성만 밑줄.
            child: Text(label,
                style: AppText.meta(sel ? tk.ink : tk.inkSoft, size: 11)
                    .copyWith(
                        fontWeight:
                            sel ? FontWeight.w500 : FontWeight.w400)),
          ),
        ),
      );
    }

    final label = _actionLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  tab(0, 'day'),
                  tab(1, 'week'),
                  tab(2, 'month'),
                  tab(3, 'routine'),
                  tab(4, 'log'),
                ],
              ),
            ),
          ),
          if (label != null)
            GestureDetector(
              onTap: _action,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 8),
                child: Text(label, style: AppText.meta(tk.ink, size: 12)),
              ),
            ),
        ],
      ),
    );
  }

  String? get _actionLabel => switch (_sub) {
        3 => '+ 루틴',
        4 => '지금 기록',
        _ => null,
      };

  void _action() {
    switch (_sub) {
      case 3:
        showRoutineGroupSheet(context);
        break;
      case 4:
        showTimeQuickAdd(context, ref,
            date: DateTime.now(), block: TimeTrackRepository.blockOfNow());
        break;
    }
  }
}
