import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'core/dialogs.dart';
import 'core/journal.dart';
import 'core/theme.dart';
import 'data/repos/time_track_repository.dart';
import 'features/all/all_view.dart';
import 'features/capture/quick_capture_bar.dart';
import 'features/capture/quick_capture_input.dart';
import 'features/fortune/fortune_view.dart';
import 'features/habit/habit_view.dart';
import 'features/matrix/matrix_view.dart';
import 'features/outline/outline_view.dart';
import 'features/schedule/calendar_view.dart';
import 'features/schedule/time_hub.dart';
import 'features/settings/settings_screen.dart';
import 'features/timetrack/time_track_screen.dart';
import 'features/today/intention_sheet.dart';
import 'features/today/today_view.dart';
import 'features/today/two_minute_sheet.dart';
import 'providers.dart';

/// 셸: 오늘 / 매트릭스 / 아웃라인 / 전체.
/// 입력바는 body 안에 있어 키보드가 올라와도 항상 보인다.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // 포커스·매트릭스 위젯 탭 진입 → 빠른 담기 입력창.
    quickCaptureFocusRequest.addListener(_onQuickCapture);
    // 타임트래커 위젯 탭 진입 → 현재 블록 입력창.
    timeTrackLaunchRequest.addListener(_onTimeTrackLaunch);
  }

  @override
  void dispose() {
    quickCaptureFocusRequest.removeListener(_onQuickCapture);
    timeTrackLaunchRequest.removeListener(_onTimeTrackLaunch);
    super.dispose();
  }

  void _onQuickCapture() {
    if (!mounted) return;
    showQuickCaptureInput(context, ref);
  }

  void _onTimeTrackLaunch() {
    if (!mounted) return;
    showTimeTrackInput(
      context,
      ref,
      date: DateTime.now(),
      block: TimeTrackRepository.blockOfNow(),
    );
  }

  static const _titles = ['오늘', '매트릭스', '아웃라인', '일과', '습관', '전체'];
  static const _navLabels = [
    'today',
    'matrix',
    'outline',
    'time',
    'habit',
    'all'
  ];

  @override
  Widget build(BuildContext context) {
    final body = switch (_index) {
      0 => const TodayView(),
      1 => const MatrixView(),
      2 => const OutlineView(),
      3 => const TimeHub(),
      4 => const HabitView(),
      _ => const AllView(),
    };

    return Scaffold(
      resizeToAvoidBottomInset: true,
      drawer: _buildDrawer(context),
      // 입력바가 키보드 위로 따라 올라오도록 body 에 배치.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Builder(
              builder: (ctx) => Masthead(
                title: _titles[_index],
                actions: _mastheadActions(ctx),
              ),
            ),
            Expanded(child: body),
            // 하단 담기 바는 할 일 계열 탭에만 (시간=3, 습관=4 제외).
            if (_index != 3 && _index != 4) const QuickCaptureBar(),
            _bottomNav(context),
          ],
        ),
      ),
    );
  }

  /// 마스트헤드 우측: 탭별 액션 + ≡ MENU (모노).
  List<Widget> _mastheadActions(BuildContext ctx) {
    final actions = <Widget>[];
    if (_index == 2) {
      actions.add(_act('+폴더', _newFolder));
      actions.add(_act('+목표', _newGoal));
    } else if (_index == 4) {
      actions.add(_act('+습관', _newHabit));
    }
    actions.add(_act('≡ MENU', () => Scaffold.of(ctx).openDrawer()));
    return actions;
  }

  Widget _act(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // 세로 여백으로 터치 영역 확보.
          padding: const EdgeInsets.only(left: 10, top: 8, bottom: 8),
          child: Text(label,
              style: AppText.meta(t(context).inkSoft, size: 11)),
        ),
      );

  /// 하단 탭 — 소문자 모노, 상단 규칙선, 활성 = ink + 밑줄.
  /// 각 탭은 Expanded + 세로 여백으로 셀 전체가 터치되도록 함.
  Widget _bottomNav(BuildContext context) {
    final tk = t(context);
    return Container(
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tk.line, width: 1))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              for (var i = 0; i < _navLabels.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _index = i),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      alignment: Alignment.center,
                      // 넉넉한 터치 영역(≈44dp).
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 3),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _index == i ? tk.ink : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Text(_navLabels[i],
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            style: AppText.nav(
                                _index == i ? tk.ink : tk.inkSoft,
                                active: _index == i)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 새 습관 만들기 (이름만 — 카테고리는 상세에서).
  Future<void> _newHabit() async {
    final name = await showInputDialog(context,
        title: '새 습관', hint: '예: 아침 산책, 물 마시기');
    if (name == null || name.trim().isEmpty) return;
    await ref.read(habitRepoProvider).addHabit(name.trim());
  }

  /// 새 폴더(카테고리) 생성 — 아웃라인 최상위에 추가.
  Future<void> _newFolder() async {
    final title =
        await showInputDialog(context, title: '새 폴더', hint: '예: 회사, 집, 공부');
    if (title == null || title.trim().isEmpty) return;
    await ref
        .read(nodeRepoProvider)
        .create(type: NodeType.folder, title: title.trim());
  }

  /// 새 목표 → 저장 직후 첫 2분 행동 시트 (규칙 5).
  Future<void> _newGoal() async {
    final title =
        await showInputDialog(context, title: '새 목표', hint: '이루고 싶은 것');
    if (title == null || title.trim().isEmpty || !mounted) return;
    final repo = ref.read(nodeRepoProvider);
    final id = await repo.create(type: NodeType.goal, title: title.trim());
    if (!mounted) return;
    final saved = await showTwoMinuteSheet(context, ref,
        goalId: id, goalTitle: title.trim());
    // 첫 행동을 실제로 정했을 때만 이어서 실행의도(선택) 시트.
    if (saved == true && mounted) {
      await showIntentionSheet(context, ref,
          goalId: id, goalTitle: title.trim());
    }
  }

  void _openSettings() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  void _openFortune() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const FortuneView()));

  void _openCalendar() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const CalendarScreen()));

  /// 사이드바 메뉴 (편집형).
  Widget _buildDrawer(BuildContext context) {
    final tk = t(context);
    Widget item(IconData icon, String label, VoidCallback onTap) => InkWell(
          onTap: () {
            Navigator.of(context).pop(); // 드로어 닫기
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 14),
            child: Row(
              children: [
                Icon(icon, size: 19, color: tk.inkSoft),
                const SizedBox(width: 14),
                Text(label, style: AppText.body(tk.ink)),
              ],
            ),
          ),
        );

    return Drawer(
      backgroundColor: tk.paper,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 20, kGutter, 12),
              child: Text('지금', style: AppText.hTitle(tk.ink)),
            ),
            Container(
                margin: const EdgeInsets.symmetric(horizontal: kGutter),
                height: 1,
                color: tk.ink),
            const SizedBox(height: 6),
            item(Icons.calendar_today, '달력', _openCalendar),
            item(Icons.auto_awesome, '오늘의 운세', _openFortune),
            item(Icons.tune, '설정', _openSettings),
          ],
        ),
      ),
    );
  }
}
