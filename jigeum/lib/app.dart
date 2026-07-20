import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/all/all_view.dart';
import 'features/capture/quick_capture_bar.dart';
import 'features/today/today_view.dart';
import 'features/widgetkit/widget_bridge.dart';

/// 단순 모드 셸: 오늘 / 전체 두 탭.
/// 입력바는 body 안에 있어 키보드가 올라와도 항상 보인다.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final body = _index == 0 ? const TodayView() : const AllView();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_index == 0 ? '오늘' : '전체'),
        actions: [
          IconButton(
            icon: const Icon(Icons.opacity_outlined),
            tooltip: '위젯 투명도',
            onPressed: _widgetOpacityDialog,
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
              icon: Icon(Icons.list_alt_outlined), label: '전체'),
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
}
