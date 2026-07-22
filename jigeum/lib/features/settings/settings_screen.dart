import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/almanac.dart';
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

/// 사주 요약 타일 — 현재 입력 상태를 보여주고, 탭하면 정밀 입력 폼으로.
class _SajuTile extends StatelessWidget {
  const _SajuTile({required this.settings, required this.ctrl});
  final AppSettings settings;
  final SettingsController ctrl;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final b = settings.birth;

    void openEditor() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SajuEditorPage(ctrl: ctrl, initial: settings)));

    if (b == null) {
      return InkWell(
        onTap: openEditor,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tk.line, width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 14),
          child: Row(
            children: [
              Expanded(
                  child: Text('생년월일·시각 입력하기',
                      style: AppText.body(tk.ink))),
              Text('입력', style: AppText.meta(tk.mark, size: 12)),
            ],
          ),
        ),
      );
    }

    final calLabel = settings.birthCalendar == 'lunar'
        ? '음력${settings.birthLeap ? ' 윤달' : ''}'
        : '양력';
    final dateStr =
        '${b.year}.${b.month.toString().padLeft(2, '0')}.${b.day.toString().padLeft(2, '0')}';
    final timeStr = settings.birthHasTime
        ? '${b.hour.toString().padLeft(2, '0')}:${b.minute.toString().padLeft(2, '0')}'
        : '시 모름';
    final chart = computeSaju(b,
        hasHour: settings.birthHasTime,
        longitude: settings.birthLongitude,
        male: settings.birthMale);
    final z = zodiacOf(b);

    return Column(
      children: [
        InkWell(
          onTap: openEditor,
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tk.line, width: 1)),
            ),
            padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$dateStr · $timeStr',
                          style: AppText.body(tk.ink)),
                      const SizedBox(height: 3),
                      Text(
                          '$calLabel · ${settings.birthMale ? '남' : '여'} · '
                          '${settings.birthPlace}',
                          style: AppText.meta(tk.inkSoft, size: 11)),
                    ],
                  ),
                ),
                Text('수정', style: AppText.meta(tk.mark, size: 12)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '→ 일주 ${chart.day.hanja}(${chart.day.kor}) · 일간 '
                  '${stemHanja[chart.dayStem]} ${wuxingKor[stemWuxing(chart.dayStem)]}'
                  ' · ${z.symbol} ${z.name}',
                  style: AppText.meta(tk.ink, size: 11),
                ),
              ),
              GestureDetector(
                onTap: ctrl.clearBirth,
                child: Text('지우기', style: AppText.meta(tk.mark, size: 11)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 사주 정밀 입력 폼 — 성별·양력/음력(윤달)·생년월일·시각(시 모름)·출생지(경도).
class SajuEditorPage extends StatefulWidget {
  const SajuEditorPage({super.key, required this.ctrl, required this.initial});
  final SettingsController ctrl;
  final AppSettings initial;

  @override
  State<SajuEditorPage> createState() => _SajuEditorPageState();
}

class _SajuEditorPageState extends State<SajuEditorPage> {
  bool _male = true;
  String _cal = 'solar'; // solar | lunar
  bool _leap = false;
  late int _year, _month, _day;
  bool _timeUnknown = false;
  int _hour = 12, _minute = 0;
  int _cityIndex = 0; // koreaCities index, -1 = 직접입력
  double _customLng = 127.0;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    final b = s.birth;
    _male = s.birthMale;
    _cal = s.birthCalendar;
    _leap = s.birthLeap;
    _timeUnknown = b != null && !s.birthHasTime;
    // 경도 → 도시 index 매칭.
    _cityIndex = koreaCities.indexWhere((c) => (c.$2 - s.birthLongitude).abs() < 0.01);
    if (_cityIndex < 0) {
      _customLng = s.birthLongitude;
    }
    if (b == null) {
      _year = 1995;
      _month = 1;
      _day = 1;
    } else if (_cal == 'lunar') {
      final l = lunarOf(b); // 저장은 양력 → 음력 숫자로 역표시
      _year = l.year;
      _month = l.month;
      _day = l.day;
      _leap = l.leap;
      _hour = b.hour;
      _minute = b.minute;
    } else {
      _year = b.year;
      _month = b.month;
      _day = b.day;
      _hour = b.hour;
      _minute = b.minute;
    }
  }

  double get _longitude =>
      _cityIndex < 0 ? _customLng : koreaCities[_cityIndex].$2;
  String get _placeName => _cityIndex < 0 ? '직접입력' : koreaCities[_cityIndex].$1;

  Future<void> _save() async {
    DateTime? solar;
    if (_cal == 'solar') {
      solar = DateTime(_year, _month, _day, _hour, _minute);
    } else {
      final base = solarFromLunar(_year, _month, _day, _leap);
      if (base == null) {
        setState(() => _error = '해당 음력 날짜를 찾지 못했어요. 날짜를 확인해 주세요.');
        return;
      }
      solar = DateTime(base.year, base.month, base.day, _hour, _minute);
    }
    await widget.ctrl.setBirth(
      solar,
      hasTime: !_timeUnknown,
      longitude: _longitude,
      male: _male,
      place: _placeName,
      calendar: _cal,
      leap: _cal == 'lunar' && _leap,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    // 음력이면 양력 미리보기.
    String preview = '';
    if (_cal == 'lunar') {
      final s = solarFromLunar(_year, _month, _day, _leap);
      preview = s == null
          ? '변환 불가'
          : '양력 ${s.year}.${s.month.toString().padLeft(2, '0')}.${s.day.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('사주 정보'),
        actions: [
          TextButton(onPressed: _save, child: const Text('저장')),
        ],
      ),
      body: Container(
        color: tk.paper,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            const SectionLabel('성별 (대운 계산)'),
            _seg(['남', '여'], _male ? 0 : 1, (i) => setState(() => _male = i == 0)),
            const SectionLabel('달력'),
            _seg(['양력', '음력'], _cal == 'solar' ? 0 : 1,
                (i) => setState(() => _cal = i == 0 ? 'solar' : 'lunar')),
            if (_cal == 'lunar')
              Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
                child: Row(
                  children: [
                    Expanded(
                        child: Text('윤달', style: AppText.body(tk.ink))),
                    Switch(
                        value: _leap,
                        onChanged: (v) => setState(() => _leap = v)),
                  ],
                ),
              ),
            const SectionLabel('생년월일'),
            _ymdWheels(tk),
            if (_cal == 'lunar')
              Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
                child: Text('→ $preview', style: AppText.meta(tk.mark, size: 12)),
              ),
            const SectionLabel('태어난 시각'),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
              child: Row(
                children: [
                  Expanded(
                      child: Text('시각을 몰라요',
                          style: AppText.body(tk.ink))),
                  Switch(
                      value: _timeUnknown,
                      onChanged: (v) => setState(() => _timeUnknown = v)),
                ],
              ),
            ),
            if (!_timeUnknown) _hmWheels(tk),
            if (_timeUnknown)
              Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
                child: Text('시각 없이도 년·월·일주로 분석해요 (시주만 제외).',
                    style: AppText.meta(tk.inkSoft, size: 11)),
              ),
            const SectionLabel('출생지 (경도 보정)'),
            _cityPicker(tk),
            if (_cityIndex < 0) _lngField(tk),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
              child: Text('경도로 진태양시를 보정합니다 (동경 ${_longitude.toStringAsFixed(2)}°). '
                  '서머타임·한국 표준시 변천은 자동 반영.',
                  style: AppText.meta(tk.inkSoft, size: 11)),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 0),
                child: Text(_error!, style: AppText.meta(tk.mark, size: 12)),
              ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: FilledButton(
                onPressed: _save,
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg(List<String> labels, int sel, ValueChanged<int> onPick) {
    final tk = t(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () => onPick(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: sel == i ? tk.ink : tk.line,
                      width: sel == i ? 1.5 : 1,
                    ),
                  ),
                  child: Text(labels[i],
                      style: AppText.nav(sel == i ? tk.ink : tk.inkSoft,
                          active: sel == i)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ymdWheels(AppTokens tk) {
    final years = [for (var y = 1920; y <= DateTime.now().year; y++) y];
    return SizedBox(
      height: 120,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kGutter),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _wheel(
                years.length,
                years.indexOf(_year),
                (i) => setState(() => _year = years[i]),
                (i) => '${years[i]}년',
              ),
            ),
            Expanded(
              flex: 2,
              child: _wheel(12, _month - 1,
                  (i) => setState(() => _month = i + 1), (i) => '${i + 1}월'),
            ),
            Expanded(
              flex: 2,
              child: _wheel(31, _day - 1,
                  (i) => setState(() => _day = i + 1), (i) => '${i + 1}일'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hmWheels(AppTokens tk) {
    return SizedBox(
      height: 120,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kGutter),
        child: Row(
          children: [
            Expanded(
              child: _wheel(24, _hour, (i) => setState(() => _hour = i),
                  (i) => '${i.toString().padLeft(2, '0')}시'),
            ),
            Expanded(
              child: _wheel(60, _minute, (i) => setState(() => _minute = i),
                  (i) => '${i.toString().padLeft(2, '0')}분'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel(int count, int selected, ValueChanged<int> onChanged,
          String Function(int) label) =>
      _Wheel(
          count: count,
          selected: selected < 0 ? 0 : selected,
          onChanged: onChanged,
          label: label);

  Widget _cityPicker(AppTokens tk) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < koreaCities.length; i++)
            _cityChip(koreaCities[i].$1, _cityIndex == i,
                () => setState(() => _cityIndex = i)),
          _cityChip('직접입력', _cityIndex < 0, () => setState(() => _cityIndex = -1)),
        ],
      ),
    );
  }

  Widget _cityChip(String label, bool sel, VoidCallback onTap) {
    final tk = t(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(
              color: sel ? tk.ink : tk.line, width: sel ? 1.5 : 1),
        ),
        child: Text(label,
            style: AppText.chip(sel ? tk.ink : tk.inkSoft)),
      ),
    );
  }

  Widget _lngField(AppTokens tk) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
      child: Row(
        children: [
          Text('경도(동경) ', style: AppText.body(tk.ink)),
          Expanded(
            child: TextFormField(
              initialValue: _customLng.toStringAsFixed(2),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppText.body(tk.ink),
              onChanged: (v) {
                final d = double.tryParse(v);
                if (d != null && d > 100 && d < 150) _customLng = d;
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 자체 컨트롤러를 가진 스크롤 휠 — 부모 rebuild 에도 위치가 튀지 않는다.
class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.count,
    required this.selected,
    required this.onChanged,
    required this.label,
  });
  final int count;
  final int selected;
  final ValueChanged<int> onChanged;
  final String Function(int) label;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final FixedExtentScrollController _c =
      FixedExtentScrollController(initialItem: widget.selected);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return ListWheelScrollView.useDelegate(
      controller: _c,
      itemExtent: 34,
      perspective: 0.004,
      diameterRatio: 1.6,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: widget.onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.count,
        builder: (context, i) => Center(
          child: Text(widget.label(i), style: AppText.meta(tk.ink, size: 15)),
        ),
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
