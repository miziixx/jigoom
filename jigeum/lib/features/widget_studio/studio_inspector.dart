import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'studio_controller.dart';
import 'studio_tokens.dart';
import 'widget_config.dart';

/// ============================================================
/// WIDGET STUDIO — 속성 인스펙터(§11 오른쪽 패널)
///
/// 레퍼런스 .inspector 의 컨트롤 그룹을 그대로 옮겼다. 모바일에서는 바텀시트로
/// 재배치하되 각 컨트롤의 값·범위는 레퍼런스와 동일하게 유지한다.
/// ============================================================
class StudioInspector extends ConsumerWidget {
  const StudioInspector({super.key, required this.panel});

  /// 패널 색(레퍼런스 --panel/--ink/--muted/--line/--primary).
  final InspectorPalette panel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(studioControllerProvider);
    final ctrl = ref.read(studioControllerProvider.notifier);
    final w = session.selected;
    if (w == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('위젯을 선택하면 크기, 투명도, 선 색상, 테마와 화면 모드를 조절할 수 있습니다.',
            style: _mono(panel.muted, 10, height: 1.7)),
      );
    }
    final theme = ctrl.themeFor(w);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
      children: [
        _title(context),
        // 위젯 제목
        _group(
          label: '위젯',
          output: w.type.label,
          child: _TextRow(
            key: ValueKey('title-${w.id}'),
            initial: w.title,
            hint: '위젯 제목',
            panel: panel,
            onChanged: (v) => ctrl.mutateSelected((e) => e.copyWith(title: v)),
          ),
        ),
        // 화면 모드 (캘린더)
        if (w.type == StudioWidgetType.calendar)
          _group(
            label: '화면',
            output: 'DAY / WEEK / MONTH',
            child: Row(
              children: [
                for (final v in StudioCalView.values)
                  Expanded(
                    child: _modeTab(
                      v.name.toUpperCase(),
                      w.view == v,
                      () => ctrl.mutateSelected((e) => e.copyWith(view: v)),
                    ),
                  ),
              ],
            ),
          ),
        // 크기 프리셋
        _group(
          label: '크기 프리셋',
          output: 'RESIZABLE',
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2.6,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final p in kSizePresets)
                _presetBtn(p.label, () => ctrl.applyPreset(p.size)),
            ],
          ),
        ),
        // 직접 크기
        _group(
          label: '직접 크기',
          output: '${w.width.round()} × ${w.height.round()}',
          child: Row(
            children: [
              Expanded(
                child: _NumRow(
                  key: ValueKey('w-${w.id}-${w.width.round()}'),
                  initial: w.width.round().toString(),
                  hint: '너비',
                  panel: panel,
                  onSubmit: (v) {
                    final n = double.tryParse(v);
                    if (n != null) {
                      ctrl.mutateSelected((e) => e.copyWith(width: n));
                    }
                  },
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _NumRow(
                  key: ValueKey('h-${w.id}-${w.height.round()}'),
                  initial: w.height.round().toString(),
                  hint: '높이',
                  panel: panel,
                  onSubmit: (v) {
                    final n = double.tryParse(v);
                    if (n != null) {
                      ctrl.mutateSelected((e) => e.copyWith(height: n));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // 개별 테마
        _group(
          label: '개별 테마',
          output: 'OVERRIDE',
          child: _dropdown<String>(
            value: w.theme,
            items: [
              const DropdownMenuItem(value: 'global', child: Text('전체 테마 사용')),
              for (final t in StudioTheme.all)
                DropdownMenuItem(value: t.key, child: Text(t.label)),
            ],
            onChanged: (v) => ctrl.mutateSelected(
                (e) => e.copyWith(theme: v, lineColor: null, accentColor: null)),
          ),
        ),
        // 표면
        _group(
          label: '표면',
          output: w.surface.name.toUpperCase(),
          child: _dropdown<StudioSurface>(
            value: w.surface,
            items: const [
              DropdownMenuItem(value: StudioSurface.glass, child: Text('유리·반투명')),
              DropdownMenuItem(value: StudioSurface.paper, child: Text('종이')),
              DropdownMenuItem(value: StudioSurface.solid, child: Text('불투명')),
              DropdownMenuItem(
                  value: StudioSurface.transparent, child: Text('완전 투명')),
            ],
            onChanged: (v) => ctrl.mutateSelected((e) => e.copyWith(surface: v)),
          ),
        ),
        // 슬라이더들
        _slider('배경 투명도', '${w.backgroundOpacity.round()}%',
            w.backgroundOpacity, StudioRange.bgOpacity.min, StudioRange.bgOpacity.max,
            (v) => ctrl.mutateSelected((e) => e.copyWith(backgroundOpacity: v),
                persist: false),
            () => ctrl.saveNow()),
        _slider('전체 투명도', '${w.opacity.round()}%', w.opacity,
            StudioRange.opacity.min, StudioRange.opacity.max,
            (v) => ctrl.mutateSelected((e) => e.copyWith(opacity: v),
                persist: false),
            () => ctrl.saveNow()),
        _slider('글자 크기', '${w.fontScale.round()}%', w.fontScale,
            StudioRange.fontScale.min, StudioRange.fontScale.max,
            (v) => ctrl.mutateSelected((e) => e.copyWith(fontScale: v),
                persist: false),
            () => ctrl.saveNow()),
        _slider('모서리', '${w.radius.round()}px', w.radius,
            StudioRange.radius.min, StudioRange.radius.max,
            (v) => ctrl.mutateSelected((e) => e.copyWith(radius: v),
                persist: false),
            () => ctrl.saveNow()),
        // 선 색상 + 두께
        _group(
          label: '선 색상',
          output: 'CUSTOM',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _swatchRow(
                current: w.lineColor,
                fallback: theme.line,
                onPick: (c) =>
                    ctrl.mutateSelected((e) => e.copyWith(lineColor: c)),
              ),
              const SizedBox(height: 7),
              _slider('선 두께', w.lineWidth.toStringAsFixed(1), w.lineWidth,
                  StudioRange.lineWidth.min, StudioRange.lineWidth.max,
                  (v) => ctrl.mutateSelected(
                      (e) => e.copyWith(lineWidth: double.parse(v.toStringAsFixed(1))),
                      persist: false),
                  () => ctrl.saveNow(),
                  divisions: 30),
            ],
          ),
        ),
        // 포인트 색상
        _group(
          label: '포인트 색상',
          output: 'CUSTOM',
          child: _swatchRow(
            current: w.accentColor,
            fallback: theme.primary,
            onPick: (c) => ctrl.mutateSelected((e) => e.copyWith(accentColor: c)),
          ),
        ),
        const SizedBox(height: 10),
        // 액션
        Row(
          children: [
            Expanded(child: _actionBtn('복제', ctrl.duplicateSelected)),
            const SizedBox(width: 7),
            Expanded(child: _actionBtn('맨 앞으로', ctrl.bringToFront)),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
                child: _actionBtn('삭제', () {
              ctrl.deleteSelected();
              Navigator.of(context).maybePop();
            }, danger: true)),
            const SizedBox(width: 7),
            Expanded(child: _actionBtn('가운데 정렬', ctrl.centerSelected)),
          ],
        ),
      ],
    );
  }

  // --- 조각 --------------------------------------------------------------

  Widget _title(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Container(
          decoration: BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: panel.line, width: 0.7))),
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('속성',
                  style: TextStyle(
                      fontFamily: StudioFont.serif,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: panel.ink)),
              Text('INSPECTOR', style: _mono(panel.muted, 8, spacing: 0.13)),
            ],
          ),
        ),
      );

  Widget _group(
      {required String label, required String output, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: _mono(panel.muted, 8, spacing: 0.10)),
                Text(output, style: _mono(panel.primary, 8)),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _slider(String label, String output, double value, double min,
      double max, ValueChanged<double> onChanged, VoidCallback onEnd,
      {int? divisions}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: _mono(panel.muted, 8, spacing: 0.10)),
              Text(output, style: _mono(panel.primary, 8)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: panel.primary,
              inactiveTrackColor: panel.line,
              thumbColor: panel.primary,
              trackHeight: 2,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: (_) => onEnd(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeTab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: active ? panel.primary : panel.line, width: 0.7)),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: _mono(active ? panel.primary : panel.ink, 8)),
      ),
    );
  }

  Widget _presetBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: panel.line, width: 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: _mono(panel.ink, 8)),
      ),
    );
  }

  Widget _dropdown<T>(
      {required T value,
      required List<DropdownMenuItem<T>> items,
      required ValueChanged<T> onChanged}) {
    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        border: Border.all(color: panel.line, width: 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: panel.panel,
          style: TextStyle(fontFamily: StudioFont.sans, fontSize: 12, color: panel.ink),
          items: items,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _swatchRow(
      {required int? current,
      required Color fallback,
      required ValueChanged<int> onPick}) {
    // 8테마의 line·primary + 기본 그레이 몇 종을 스와치로 노출.
    final colors = <Color>{
      fallback,
      for (final t in StudioTheme.all) t.primary,
      for (final t in StudioTheme.all) t.line,
    }.toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in colors)
          GestureDetector(
            onTap: () => onPick(c.toARGB32()),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: c,
                border: Border.all(
                    color: (current == c.toARGB32())
                        ? panel.primary
                        : panel.line,
                    width: (current == c.toARGB32()) ? 2 : 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      ],
    );
  }

  Widget _actionBtn(String label, VoidCallback onTap, {bool danger = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: panel.line, width: 0.7),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: StudioFont.sans,
                fontSize: 11,
                color: danger ? const Color(0xFFA4514D) : panel.ink)),
      ),
    );
  }

  static TextStyle _mono(Color c, double size,
          {double spacing = 0.05, double height = 1}) =>
      TextStyle(
        fontFamily: StudioFont.mono,
        fontFamilyFallback: StudioFont.monoFallback,
        fontSize: size,
        fontWeight: FontWeight.w500,
        height: height,
        letterSpacing: spacing * size,
        color: c,
      );
}

/// 인스펙터가 쓰는 패널 색(현재 전역 테마에서 파생).
class InspectorPalette {
  const InspectorPalette(
      this.panel, this.ink, this.muted, this.line, this.primary);
  final Color panel, ink, muted, line, primary;
}

/// 전역 테마 → 인스펙터 팔레트.
InspectorPalette inspectorPalette(StudioTheme t) =>
    InspectorPalette(t.surface, t.ink, t.muted, t.line, t.primary);

// --- 편집 필드 (외부 값 변경 시 컨트롤러 유지) -----------------------------

class _TextRow extends StatefulWidget {
  const _TextRow(
      {super.key,
      required this.initial,
      required this.hint,
      required this.panel,
      required this.onChanged});
  final String initial;
  final String hint;
  final InspectorPalette panel;
  final ValueChanged<String> onChanged;
  @override
  State<_TextRow> createState() => _TextRowState();
}

class _TextRowState extends State<_TextRow> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _fieldBox(
      widget.panel,
      TextField(
        controller: _c,
        onChanged: widget.onChanged,
        style: TextStyle(
            fontFamily: StudioFont.sans, fontSize: 10, color: widget.panel.ink),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: widget.hint,
        ),
      ),
    );
  }
}

class _NumRow extends StatefulWidget {
  const _NumRow(
      {super.key,
      required this.initial,
      required this.hint,
      required this.panel,
      required this.onSubmit});
  final String initial;
  final String hint;
  final InspectorPalette panel;
  final ValueChanged<String> onSubmit;
  @override
  State<_NumRow> createState() => _NumRowState();
}

class _NumRowState extends State<_NumRow> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _fieldBox(
      widget.panel,
      TextField(
        controller: _c,
        keyboardType: TextInputType.number,
        onSubmitted: widget.onSubmit,
        onEditingComplete: () => widget.onSubmit(_c.text),
        style: TextStyle(
            fontFamily: StudioFont.sans, fontSize: 10, color: widget.panel.ink),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: widget.hint,
        ),
      ),
    );
  }
}

Widget _fieldBox(InspectorPalette panel, Widget child) => Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: panel.line, width: 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
