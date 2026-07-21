import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/journal.dart';
import '../../core/settings_controller.dart';
import '../../providers.dart';
import '../widgetkit/widget_bridge.dart';

/// 설정 화면 — 백업/복원 · 폰트 크기 · 굵기 · 위젯 투명도.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: Container(
        color: Journal.pageBg(context),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 미리보기
            _card(context, [
              Text('미리보기', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Text('지금 할 것 · 오늘의 기록', style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text('이 정도 크기와 굵기로 보여요',
                  style: theme.textTheme.bodyMedium),
            ]),
            const SizedBox(height: 8),

            // 폰트 크기
            _card(context, [
              _rowLabel(theme, '글자 크기', '${(s.fontScale * 100).round()}%'),
              Slider(
                value: s.fontScale,
                min: 0.85,
                max: 1.4,
                divisions: 11,
                onChanged: (v) => ctrl.setFontScale(
                    (v * 100).round() / 100),
              ),
            ]),
            const SizedBox(height: 8),

            // 글자 굵기
            _card(context, [
              _rowLabel(theme, '글자 굵기', _weightLabel(s.weightDelta)),
              Slider(
                value: s.weightDelta.toDouble(),
                min: -1,
                max: 2,
                divisions: 3,
                onChanged: (v) => ctrl.setWeightDelta(v.round()),
              ),
            ]),
            const SizedBox(height: 8),

            // 위젯 투명도
            _card(context, [
              _WidgetOpacityTile(),
            ]),
            const SizedBox(height: 16),

            // 백업 / 복원
            _sectionLabel(theme, '데이터'),
            _menuTile(context, Icons.upload_outlined, '백업 내보내기',
                '모든 데이터를 파일로 저장', () => _export(context, ref)),
            _menuTile(context, Icons.download_outlined, '백업 가져오기 (복원)',
                '파일에서 전체 되돌리기', () => _import(context, ref)),
          ],
        ),
      ),
    );
  }

  // ---- 위젯 조각 ----
  Widget _card(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.dividerTheme.color ?? Colors.black12, width: 0.5),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _rowLabel(ThemeData theme, String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodySmall),
        ],
      );

  Widget _sectionLabel(ThemeData theme, String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(t, style: theme.textTheme.bodySmall),
      );

  Widget _menuTile(BuildContext context, IconData icon, String title,
      String sub, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.dividerTheme.color ?? Colors.black12, width: 0.5),
      ),
      child: ListTile(
        leading: Icon(icon, size: 20),
        title: Text(title, style: theme.textTheme.bodyMedium),
        subtitle: Text(sub, style: theme.textTheme.bodySmall),
        onTap: onTap,
      ),
    );
  }

  static String _weightLabel(int d) => switch (d) {
        -1 => '얇게',
        0 => '보통',
        1 => '조금 굵게',
        _ => '굵게',
      };

  // ---- 백업/복원 ----
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final json = await ref.read(backupServiceProvider).exportJson();
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final ok =
          await WidgetBridge.saveBackup('jigeum-backup-$stamp.json', json);
      if (context.mounted) {
        _toast(context, ok ? '백업을 저장했어요' : '저장을 취소했어요');
      }
    } catch (e) {
      if (context.mounted) _toast(context, '백업 실패: $e');
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final json = await WidgetBridge.openBackup();
    if (json == null || !context.mounted) return;
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
      if (context.mounted) _toast(context, '복원했어요');
    } catch (e) {
      if (context.mounted) {
        _toast(context, '복원 실패 — 올바른 백업 파일인지 확인해 주세요');
      }
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// 위젯 투명도 조절 타일.
class _WidgetOpacityTile extends StatefulWidget {
  @override
  State<_WidgetOpacityTile> createState() => _WidgetOpacityTileState();
}

class _WidgetOpacityTileState extends State<_WidgetOpacityTile> {
  double _value = 90;

  @override
  void initState() {
    super.initState();
    WidgetBridge.getWidgetOpacity().then((v) {
      if (mounted) setState(() => _value = v.toDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('위젯 투명도', style: theme.textTheme.bodyMedium),
            Text('${_value.round()}%', style: theme.textTheme.bodySmall),
          ],
        ),
        Slider(
          value: _value,
          min: 0,
          max: 100,
          divisions: 20,
          onChanged: (v) => setState(() => _value = v),
          onChangeEnd: (v) => WidgetBridge.setWidgetOpacity(v.round()),
        ),
      ],
    );
  }
}
