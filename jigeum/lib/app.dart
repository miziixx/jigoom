import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'data/repos/time_track_repository.dart';
import 'features/all/all_view.dart';
import 'features/capture/quick_capture_bar.dart';
import 'features/habit/habit_view.dart';
import 'features/matrix/matrix_view.dart';
import 'features/outline/outline_view.dart';
import 'features/schedule/schedule_view.dart';
import 'features/timetrack/time_track_screen.dart';
import 'features/today/today_view.dart';
import 'features/today/two_minute_sheet.dart';
import 'features/widgetkit/widget_bridge.dart';
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
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_index == 3) ...[
            IconButton(
              icon: const Icon(Icons.repeat),
              tooltip: '루틴',
              onPressed: () => _scheduleKey.currentState?.openRoutines(),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '새 일정',
              onPressed: () => _scheduleKey.currentState?.addSchedule(),
            ),
          ],
          if (_index == 4)
            IconButton(
              icon: const Icon(Icons.auto_awesome_outlined),
              tooltip: '새 습관',
              onPressed: _newHabit,
            ),
          if (_index == 2) ...[
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined),
              tooltip: '새 폴더',
              onPressed: _newFolder,
            ),
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: '새 목표',
              onPressed: _newGoal,
            ),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'timetrack':
                  _openTimeTrack();
                case 'opacity':
                  _widgetOpacityDialog();
                case 'export':
                  _exportBackup();
                case 'import':
                  _importBackup();
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'timetrack', child: Text('기록 (타임트래커)')),
              PopupMenuItem(value: 'opacity', child: Text('위젯 투명도')),
              PopupMenuItem(value: 'export', child: Text('백업 내보내기')),
              PopupMenuItem(value: 'import', child: Text('백업 가져오기 (복원)')),
            ],
          ),
        ],
      ),
      // 입력바가 키보드 위로 따라 올라오도록 body 에 배치.
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: body),
            const QuickCaptureBar(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.wb_sunny_outlined), label: '오늘'),
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined), label: '매트릭스'),
          NavigationDestination(
              icon: Icon(Icons.account_tree_outlined), label: '아웃라인'),
          NavigationDestination(
              icon: Icon(Icons.schedule_outlined), label: '일과'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined), label: '습관'),
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined), label: '전체'),
        ],
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

  /// 백업 내보내기: 전체 데이터를 JSON 으로 → 문서창(SAF) 저장.
  Future<void> _exportBackup() async {
    try {
      final json = await ref.read(backupServiceProvider).exportJson();
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final ok = await WidgetBridge.saveBackup('jigeum-backup-$stamp.json', json);
      if (!mounted) return;
      _toast(ok ? '백업을 저장했어요' : '저장을 취소했어요');
    } catch (e) {
      if (mounted) _toast('백업 실패: $e');
    }
  }

  /// 백업 가져오기(전체 교체): 파일 선택 → 확인 → 복원.
  Future<void> _importBackup() async {
    final json = await WidgetBridge.openBackup();
    if (json == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('복원할까요?'),
        content: const Text('지금의 모든 데이터를 지우고\n선택한 백업으로 되돌립니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('복원')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(backupServiceProvider).importJson(json);
      if (mounted) _toast('복원했어요');
    } catch (e) {
      if (mounted) _toast('복원 실패 — 올바른 백업 파일인지 확인해 주세요');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 홈/잠금 위젯 배경 투명도 설정 (0=투명 ~ 100=불투명).
  Future<void> _widgetOpacityDialog() async {
    var value = (await WidgetBridge.getWidgetOpacity()).toDouble();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('위젯 투명도'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${value.round()}%',
                  style: Theme.of(ctx).textTheme.titleMedium),
              Slider(
                value: value,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (v) => setDialogState(() => value = v),
              ),
              Text('0% = 완전 투명 · 100% = 불투명',
                  style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('취소')),
            FilledButton(
              onPressed: () async {
                await WidgetBridge.setWidgetOpacity(value.round());
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
  }
}
