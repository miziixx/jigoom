import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'core/journal.dart';
import 'core/theme.dart';
import 'data/repos/time_track_repository.dart';
import 'features/all/all_view.dart';
import 'features/capture/quick_capture_bar.dart';
import 'features/habit/habit_view.dart';
import 'features/matrix/matrix_view.dart';
import 'features/outline/outline_view.dart';
import 'features/schedule/schedule_view.dart';
import 'features/settings/settings_screen.dart';
import 'features/timetrack/time_track_screen.dart';
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
  final _scheduleKey = GlobalKey<ScheduleViewState>();

  @override
  void initState() {
    super.initState();
    // 타임트래커 위젯 탭 진입 → 현재 블록 입력창.
    timeTrackLaunchRequest.addListener(_onTimeTrackLaunch);
  }

  @override
  void dispose() {
    timeTrackLaunchRequest.removeListener(_onTimeTrackLaunch);
    super.dispose();
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

  void _openTimeTrack() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const TimeTrackScreen()));

  static const _titles = ['오늘', '매트릭스', '아웃라인', '일과', '습관', '전체'];
  static const _navLabels = [
    'today',
    'matrix',
    'outline',
    'routine',
    'habit',
    'all'
  ];

  /// 하단 담기 대상: 일과 탭=일정, 습관 탭=습관, 그 외=할 일.
  CaptureMode get _captureMode => switch (_index) {
        3 => CaptureMode.schedule,
        4 => CaptureMode.habit,
        _ => CaptureMode.task,
      };

  @override
  Widget build(BuildContext context) {
    final body = switch (_index) {
      0 => const TodayView(),
      1 => const MatrixView(),
      2 => const OutlineView(),
      3 => ScheduleView(key: _scheduleKey),
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
            QuickCaptureBar(mode: _captureMode),
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
    } else if (_index == 3) {
      actions.add(_act('루틴', () => _scheduleKey.currentState?.openRoutines()));
      actions.add(_act('+일정', () => _scheduleKey.currentState?.addSchedule()));
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

  /// 새 습관 만들기 (이름 + 카테고리).
  Future<void> _newHabit() async {
    final name = TextEditingController();
    final cat = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 습관'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration:
                  const InputDecoration(hintText: '예: 아침 산책, 물 마시기'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: cat,
              decoration: const InputDecoration(
                  hintText: '카테고리 (선택 · 예: 건강, 공부)'),
              onSubmitted: (_) => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('만들기')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    await ref
        .read(habitRepoProvider)
        .addHabit(name.text.trim(), category: cat.text.trim());
  }

  /// 새 폴더(카테고리) 생성 — 아웃라인 최상위에 추가.
  Future<void> _newFolder() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 폴더'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 회사, 집, 공부'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('만들기')),
        ],
      ),
    );
    if (title == null || title.trim().isEmpty) return;
    await ref
        .read(nodeRepoProvider)
        .create(type: NodeType.folder, title: title.trim());
  }

  /// 새 목표 → 저장 직후 첫 2분 행동 시트 (규칙 5).
  Future<void> _newGoal() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 목표'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '이루고 싶은 것'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('만들기')),
        ],
      ),
    );
    if (title == null || title.trim().isEmpty || !mounted) return;
    final repo = ref.read(nodeRepoProvider);
    final id = await repo.create(type: NodeType.goal, title: title.trim());
    if (!mounted) return;
    await showTwoMinuteSheet(context, ref, goalId: id, goalTitle: title.trim());
  }

  void _openSettings() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

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
            item(Icons.schedule_outlined, '기록 · 타임트래커', _openTimeTrack),
            item(Icons.tune, '설정', _openSettings),
          ],
        ),
      ),
    );
  }
}
