import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'features/capture/quick_capture_bar.dart';
import 'features/widgetkit/widget_bridge.dart';
import 'features/matrix/matrix_view.dart';
import 'features/outline/outline_view.dart';
import 'features/today/today_view.dart';
import 'features/today/two_minute_sheet.dart';
import 'providers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _titles = ['오늘', '매트릭스', '아웃라인'];

  @override
  Widget build(BuildContext context) {
    final body = switch (_index) {
      0 => const TodayView(),
      1 => const MatrixView(),
      _ => const OutlineView(),
    };

    return Scaffold(
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
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const QuickCaptureBar(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.wb_sunny_outlined), label: '오늘'),
              NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined), label: '매트릭스'),
              NavigationDestination(
                  icon: Icon(Icons.account_tree_outlined), label: '아웃라인'),
            ],
          ),
        ],
      ),
    );
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

  Future<void> _newGoal() async {
    final title = await _promptTitle();
    if (title == null || title.trim().isEmpty) return;
    final repo = ref.read(nodeRepoProvider);
    final id = await repo.create(type: NodeType.goal, title: title.trim());
    if (!mounted) return;
    // 규칙 5: 목표 저장 직후 첫 2분 행동 강제.
    await showTwoMinuteSheet(context, ref, goalId: id, goalTitle: title.trim());
  }

  Future<String?> _promptTitle() {
    final controller = TextEditingController();
    return showDialog<String>(
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
  }
}
