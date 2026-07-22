import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dialogs.dart';
import '../../core/journal.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../widgetkit/widget_bridge.dart';

/// 설정 화면 — 편집형. 테마 · 글자 크기/굵기 · 위젯 투명도 · 백업/복원.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: Container(
        color: tk.paper,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const SectionLabel('THEME'),
            _ThemePicker(current: s.themeKey, onPick: ctrl.setThemeKey),

            const SectionLabel('TYPE'),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
              child: Text('지금 할 것 · 오늘의 기록', style: AppText.body(tk.ink)),
            ),
            _sliderRow(
              context,
              label: '글자 크기',
              value: '${(s.fontScale * 100).round()}%',
              slider: Slider(
                value: s.fontScale,
                min: 0.85,
                max: 1.4,
                divisions: 11,
                onChanged: (v) => ctrl.setFontScale((v * 100).round() / 100),
              ),
            ),
            _sliderRow(
              context,
              label: '글자 굵기',
              value: _weightLabel(s.weightDelta),
              slider: Slider(
                value: s.weightDelta.toDouble(),
                min: -1,
                max: 2,
                divisions: 3,
                onChanged: (v) => ctrl.setWeightDelta(v.round()),
              ),
            ),
            _switchRow(
              context,
              title: '기기 글꼴로 통일',
              sub: '라벨·숫자(모노)까지 폰에서 쓰는 글꼴로',
              value: s.systemFont,
              onChanged: ctrl.setSystemFont,
            ),

            const SectionLabel('WIDGET'),
            const _WidgetOpacityTile(),

            const SectionLabel('DATA'),
            _menuTile(context, '↑', '백업 내보내기', '모든 데이터를 파일로 저장',
                () => _export(context, ref)),
            _menuTile(context, '↓', '백업 가져오기 (복원)', '파일에서 전체 되돌리기',
                () => _import(context, ref)),
          ],
        ),
      ),
    );
  }

  Widget _sliderRow(BuildContext context,
      {required String label,
      required String value,
      required Widget slider}) {
    final tk = t(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppText.body(tk.ink)),
              Text(value, style: AppText.meta(tk.inkSoft)),
            ],
          ),
          slider,
        ],
      ),
    );
  }

  Widget _switchRow(BuildContext context,
      {required String title,
      required String sub,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    final tk = t(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(tk.ink)),
                const SizedBox(height: 2),
                Text(sub, style: AppText.meta(tk.inkSoft)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _menuTile(BuildContext context, String glyph, String title,
      String sub, VoidCallback onTap) {
    final tk = t(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tk.line, width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 14),
        child: Row(
          children: [
            SizedBox(
                width: 22,
                child: Text(glyph, style: AppText.glyph(tk.inkSoft))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body(tk.ink)),
                  const SizedBox(height: 2),
                  Text(sub, style: AppText.meta(tk.inkSoft)),
                ],
              ),
            ),
          ],
        ),
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
    final ok = await showConfirmDialog(context,
        title: '복원할까요?',
        message: '지금의 모든 데이터를 지우고\n선택한 백업으로 되돌립니다.',
        confirmLabel: '복원',
        danger: true);
    if (!ok) return;
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

/// 내장 10종 테마 스와치 — paper / ink / mark 3색 바. 선택 = ink 1.5px 테두리.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.current, required this.onPick});
  final String current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final spec in kThemes)
            GestureDetector(
              onTap: () => onPick(spec.key),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: current == spec.key ? tk.ink : spec.tokens.line,
                        width: current == spec.key ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                            child: Container(color: spec.tokens.paper)),
                        Expanded(child: Container(color: spec.tokens.ink)),
                        Expanded(child: Container(color: spec.tokens.mark)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 58,
                    child: Text(spec.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.nav(
                            current == spec.key ? tk.ink : tk.inkSoft,
                            active: current == spec.key)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 위젯 투명도 조절 타일.
class _WidgetOpacityTile extends StatefulWidget {
  const _WidgetOpacityTile();

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
    final tk = t(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('위젯 투명도', style: AppText.body(tk.ink)),
              Text('${_value.round()}%', style: AppText.meta(tk.inkSoft)),
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
      ),
    );
  }
}
