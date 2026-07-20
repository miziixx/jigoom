import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'features/all/all_view.dart';
import 'features/capture/quick_capture_bar.dart';
import 'features/matrix/matrix_view.dart';
import 'features/outline/outline_view.dart';
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

  static const _titles = ['오늘', '매트릭스', '아웃라인', '전체'];

  @override
  Widget build(BuildContext context) {
    final body = switch (_index) {
      0 => const TodayView(),
      1 => const MatrixView(),
      2 => const OutlineView(),
      _ => const AllView(),
    };

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            icon: const Icon(Icons.opacity_outlined),
            tooltip: '위젯 투명도',
            onPressed: _widgetOpacityDialog,
          ),
          if (_index == 2)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: '새 목표',
              onPressed: _newGoal,
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
              icon: Icon(Icons.list_alt_outlined), label: '전체'),
        ],
      ),
    );
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
