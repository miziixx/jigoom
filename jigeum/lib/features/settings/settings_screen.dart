import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/dialogs.dart';
import '../../core/journal.dart';
import '../../core/saju.dart';
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

            const SectionLabel('SKY'),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
              child: Text('헤더의 별자리·만세력 표시', style: AppText.body(tk.ink)),
            ),
            _SkyPicker(current: s.skyMode, onPick: ctrl.setSkyMode),

            const SectionLabel('SAJU'),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
              child: Text('오늘의 운세용 — 생년월일과 태어난 시각', style: AppText.body(tk.ink)),
            ),
            _SajuTile(settings: s, ctrl: ctrl),

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

/// 별자리·만세력 표시 모드 선택 — 둘다/별자리만/만세력만/둘다빼기.
class _SkyPicker extends StatelessWidget {
  const _SkyPicker({required this.current, required this.onPick});
  final String current;
  final ValueChanged<String> onPick;

  static const _opts = [
    ('both', '둘 다 보기'),
    ('zodiac', '별자리만'),
    ('saju', '만세력만'),
    ('none', '둘 다 빼기'),
  ];

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (key, label) in _opts)
            GestureDetector(
              onTap: () => onPick(key),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: current == key ? tk.ink : tk.line,
                    width: current == key ? 1.5 : 1,
                  ),
                ),
                child: Text(label,
                    style: AppText.nav(current == key ? tk.ink : tk.inkSoft,
                        active: current == key)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 사주(생년월일시) 입력 타일 — 날짜/시각 피커. '오늘의 운세'의 원천 데이터.
class _SajuTile extends StatelessWidget {
  const _SajuTile({required this.settings, required this.ctrl});
  final AppSettings settings;
  final SettingsController ctrl;

  Future<void> _pickDate(BuildContext context) async {
    final b = settings.birth;
    final picked = await showDatePicker(
      context: context,
      initialDate: b ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: '생년월일 선택',
    );
    if (picked == null) return;
    // 기존 시각 유지(없으면 정오).
    final h = settings.birthHasTime && b != null ? b.hour : 12;
    final m = settings.birthHasTime && b != null ? b.minute : 0;
    await ctrl.setBirth(
      DateTime(picked.year, picked.month, picked.day, h, m),
      hasTime: settings.birthHasTime,
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final b = settings.birth;
    if (b == null) {
      // 날짜부터.
      await _pickDate(context);
      if (settings.birth == null) return;
    }
    final base = settings.birth ?? DateTime(1995, 1, 1, 12);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
      helpText: '태어난 시각 선택',
    );
    if (picked == null) return;
    await ctrl.setBirth(
      DateTime(base.year, base.month, base.day, picked.hour, picked.minute),
      hasTime: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final b = settings.birth;
    final dateStr = b == null
        ? '입력 안 됨'
        : '${b.year}.${b.month.toString().padLeft(2, '0')}.${b.day.toString().padLeft(2, '0')}';
    final timeStr = b == null
        ? '—'
        : settings.birthHasTime
            ? '${b.hour.toString().padLeft(2, '0')}:${b.minute.toString().padLeft(2, '0')}'
            : '모름';

    Widget row(String label, String value, VoidCallback onTap,
        {Widget? trailing}) {
      return InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tk.line, width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 14),
          child: Row(
            children: [
              Expanded(child: Text(label, style: AppText.body(tk.ink))),
              Text(value, style: AppText.meta(tk.inkSoft, size: 12)),
              if (trailing != null) trailing,
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('음력이면 양력으로 변환해 입력하세요',
                  style: AppText.meta(tk.inkSoft, size: 10)),
              if (b != null)
                GestureDetector(
                  onTap: ctrl.clearBirth,
                  child: Text('지우기', style: AppText.meta(tk.mark, size: 11)),
                ),
            ],
          ),
        ),
        row('생년월일 (양력)', dateStr, () => _pickDate(context)),
        row('태어난 시각', timeStr, () => _pickTime(context),
            trailing: b == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: GestureDetector(
                      onTap: () => ctrl.setBirth(
                          DateTime(b.year, b.month, b.day, 12, 0),
                          hasTime: false),
                      child:
                          Text('시 모름', style: AppText.meta(tk.inkSoft, size: 10)),
                    ),
                  )),
        if (b != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
            child: Builder(builder: (_) {
              final chart = computeSaju(b, hasHour: settings.birthHasTime);
              final z = zodiacOf(b);
              return Text(
                '→ 일주 ${chart.day.hanja}(${chart.day.kor}) · 일간 '
                '${stemHanja[chart.dayStem]} ${wuxingKor[stemWuxing(chart.dayStem)]}'
                ' · ${z.symbol} ${z.name}',
                style: AppText.meta(tk.ink, size: 11),
              );
            }),
          ),
      ],
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
