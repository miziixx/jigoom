import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/journal.dart';
import '../../core/theme.dart';
import '../../data/repos/time_track_repository.dart';
import '../../providers.dart';
import '../capture/prompt_bar.dart';
import '../timetrack/time_track_screen.dart';
import 'routine_screen.dart';
import 'schedule_view.dart';

/// 시간 허브 — 일과 탭. 하위 보기: 일정 / 루틴 / 기록(타임트래커).
class TimeHub extends ConsumerStatefulWidget {
  const TimeHub({super.key});

  @override
  ConsumerState<TimeHub> createState() => _TimeHubState();
}

class _TimeHubState extends ConsumerState<TimeHub> {
  int _sub = 0; // 0 일정 · 1 루틴 · 2 기록
  final _scheduleKey = GlobalKey<ScheduleViewState>();

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
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
            children: [
              ScheduleView(key: _scheduleKey),
              const RoutineBody(),
              const TimeTrackBody(),
            ],
          ),
        ),
        // 일정·기록 하위엔 하단 담기 바(빠른 추가). 루틴은 없음.
        if (_sub == 0)
          PromptBar(
            hint: '일정 담기_',
            onSubmit: (text) async {
              final start = DateTime.now().hour * 60;
              await ref.read(scheduleRepoProvider).addSchedule(
                    date: todayDate(),
                    title: text,
                    note: '',
                    color: 0,
                    startMin: start,
                    endMin: (start + 60).clamp(0, 1439),
                  );
            },
          )
        else if (_sub == 2)
          PromptBar(
            hint: '지금 기록_',
            onSubmit: (text) async {
              await ref.read(timeTrackRepoProvider).setBlock(
                  todayDate(), TimeTrackRepository.blockOfNow(), text);
            },
          ),
      ],
    );
  }

  Widget _subBar(AppTokens tk) {
    Widget tab(int i, String label) {
      final sel = _sub == i;
      return GestureDetector(
        onTap: () => setState(() => _sub = i),
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
            child: Text(label,
                style: AppText.nav(sel ? tk.ink : tk.inkSoft, active: sel)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
      child: Row(
        children: [
          tab(0, 'schedule'),
          tab(1, 'routine'),
          tab(2, 'log'),
          const Spacer(),
          GestureDetector(
            onTap: _action,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 8),
              child: Text(_actionLabel, style: AppText.meta(tk.ink, size: 12)),
            ),
          ),
        ],
      ),
    );
  }

  String get _actionLabel => switch (_sub) {
        0 => '+ 일정',
        1 => '+ 루틴',
        _ => '지금 기록',
      };

  void _action() {
    switch (_sub) {
      case 0:
        _scheduleKey.currentState?.addSchedule();
        break;
      case 1:
        showRoutineEditSheet(context);
        break;
      case 2:
        showTimeTrackInput(context, ref,
            date: DateTime.now(), block: TimeTrackRepository.blockOfNow());
        break;
    }
  }
}
