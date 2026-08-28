import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/almanac.dart';
import '../../core/constants.dart';
import '../../core/dialogs.dart';
import '../../core/editorial.dart';
import '../../core/gomgom_bear.dart';
import '../../core/journal.dart';
import '../../core/regions.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../gcal/gcal_settings_section.dart';
import '../notion/notion_settings_section.dart';
import '../widgetkit/lock_wallpaper_screen.dart';
import '../widgetkit/notification_service.dart';
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
      body: SafeArea(
        child: Column(
          children: [
            Masthead(
                eyebrow: 'SETTINGS',
                title: '설정',
                onBack: () => Navigator.of(context).pop(),
                actions: const [
                  Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: GomgomBear(size: 36)),
                ],),
            Expanded(
              child: Container(
                color: tk.paper,
                child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // 레퍼런스: 섹션 라벨 아래 그룹을 카드(.card)로 묶는다. 카드 안 마지막
            // 행은 하단 구분선을 끈다(.setting:last-child). 테마 그룹만 카드 없이.
            const SectionLabel('테마', topRule: false),
            _ThemePicker(current: s.themeKey, onPick: ctrl.setThemeKey),

            const SectionLabel('내 팔레트', topRule: false),
            _CustomPalette(settings: s, ctrl: ctrl),

            const SectionLabel('글자와 화면', topRule: false),
            _card(tk, [
              _adjustRow(context,
                  title: '글자 크기',
                  value: '현재 ${(s.fontScale * 100).round()}%',
                  onTap: () => _openTypeSheet(context, ref)),
              _PillSwitchRow(
                title: '휴대폰 글꼴 사용',
                sub: '휴대폰의 기본 글꼴을 사용합니다.',
                value: s.systemFont,
                onChanged: ctrl.setSystemFont,
                divider: false,
              ),
            ]),

            const SectionLabel('별자리 · 만세력', topRule: false),
            _card(tk, [
              _PillSwitchRow(
                title: '별자리 표시',
                sub: '오늘·일과·달력 화면',
                value: s.skyMode == 'both' || s.skyMode == 'zodiac',
                onChanged: (v) => ctrl.setSkyMode(
                    _deriveSky(v, s.skyMode == 'both' || s.skyMode == 'saju')),
              ),
              _PillSwitchRow(
                title: '만세력 표시',
                sub: '간지와 음력 정보를 표시',
                value: s.skyMode == 'both' || s.skyMode == 'saju',
                onChanged: (v) => ctrl.setSkyMode(_deriveSky(
                    s.skyMode == 'both' || s.skyMode == 'zodiac', v)),
              ),
              _SajuRow(settings: s, ctrl: ctrl, divider: false),
            ]),

            const SectionLabel('집중 설정', topRule: false),
            _card(tk, [
              _PillSwitchRow(
                title: '집중 중 방해 금지',
                sub: '집중 기록 중 알림과 브리핑을 숨깁니다.',
                value: s.quietMode,
                onChanged: (v) async {
                  await ctrl.setQuietMode(v);
                  if (v) await NotificationService.instance.silenceAll();
                },
              ),
              _PillSwitchRow(
                title: '알림 문구 바꾸기',
                sub: '같은 알림에 무뎌지지 않게 문구를 매번 조금씩 바꿉니다.',
                value: s.variedNudges,
                onChanged: ctrl.setVariedNudges,
              ),
              _PillSwitchRow(
                title: '완료 효과',
                sub: '작은 진동과 완료 메시지를 표시합니다.',
                value: !s.reduceMotion,
                onChanged: (v) => ctrl.setReduceMotion(!v),
              ),
              // 레퍼런스 '다음 할 일 자동 제안' — 완료 직후 다음 항목 한 개.
              _PillSwitchRow(
                title: '다음 할 일 자동 제안',
                sub: '완료 직후 다음 항목 한 개만 보여줍니다.',
                value: s.autoSuggestNext,
                onChanged: ctrl.setAutoSuggestNext,
                divider: false,
              ),
            ]),

            const SectionLabel('Google Calendar', topRule: false),
            _card(tk, const [GcalSettingsSection()]),

            const SectionLabel('Notion', topRule: false),
            _card(tk, const [NotionSettingsSection()]),

            const SectionLabel('위젯', topRule: false),
            _card(tk, [
              _WidgetOpacityRow(
                  onAdjust: () => _openWidgetOpacitySheet(context)),
              // 레퍼런스 '위젯에서 빠른 입력' — 위젯 탭 → 앱 담기 입력창.
              _PillSwitchRow(
                title: '위젯에서 빠른 입력',
                sub: '홈 화면 위젯에서 바로 할 일을 담습니다.',
                value: s.widgetQuickAdd,
                onChanged: ctrl.setWidgetQuickAdd,
              ),
              // 갤럭시 등 잠금화면엔 앱 위젯을 못 올려서, 상주 알림으로 대신 표시.
              _PillSwitchRow(
                title: '잠금화면에 오늘 일정',
                sub: '오늘 일정을 잠금화면 알림으로 띄웁니다.',
                value: s.lockAgenda,
                onChanged: ctrl.setLockAgenda,
              ),
              // 달력을 배경 이미지로 구워 잠금화면 배경으로 설정.
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LockWallpaperScreen())),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('잠금화면 배경 만들기',
                                style: AppText.body(tk.ink)),
                            const SizedBox(height: 3),
                            Text('이번 달 달력을 배경 이미지로 굽기',
                                style: AppText.meta(tk.inkSoft, size: 10)),
                          ],
                        ),
                      ),
                      Text('열기', style: AppText.meta(tk.mark, size: 11)),
                    ],
                  ),
                ),
              ),
            ]),

            const SectionLabel('백업', topRule: false),
            _card(tk, [
              _navRow(context, '백업 내보내기', '모든 데이터를 파일로 저장합니다.',
                  () => _export(context, ref)),
              _navRow(context, '백업 가져오기', '백업 파일로 전체 데이터를 복원합니다.',
                  () => _import(context, ref), divider: false),
            ]),
          ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 설정 그룹 카드 — 레퍼런스 .card(테두리 + 라운드). 행들을 감싼다.
  Widget _card(AppTokens tk, List<Widget> rows) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: kGutter),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: tk.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: rows),
        ),
      );

  /// 조절형 행 — 제목 + 현재값(작게) + 우측 "조절" 텍스트. 하단 헤어라인.
  Widget _adjustRow(BuildContext context,
      {required String title, required String value, required VoidCallback onTap}) {
    final tk = t(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: tk.line))),
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body(tk.ink)),
                  const SizedBox(height: 3),
                  Text(value, style: AppText.meta(tk.inkSoft, size: 10)),
                ],
              ),
            ),
            Text('조절', style: AppText.meta(tk.mark, size: 11)),
          ],
        ),
      ),
    );
  }

  /// 이동형 행 — 제목 + 부제 + 우측 › 셰브런. 하단 헤어라인.
  Widget _navRow(
      BuildContext context, String title, String sub, VoidCallback onTap,
      {bool divider = true}) {
    final tk = t(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: divider
            ? BoxDecoration(border: Border(bottom: BorderSide(color: tk.line)))
            : null,
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body(tk.ink)),
                  const SizedBox(height: 3),
                  Text(sub, style: AppText.meta(tk.inkSoft, size: 10)),
                ],
              ),
            ),
            Text('›', style: AppText.glyph(tk.inkSoft, size: 16)),
          ],
        ),
      ),
    );
  }

  /// 별자리(z)·만세력(s) 두 토글 → 앱의 skyMode 단일 값으로 환산.
  static String _deriveSky(bool z, bool s) =>
      z && s ? 'both' : (z ? 'zodiac' : (s ? 'saju' : 'none'));

  /// 글자 크기·굵기·글꼴을 한 시트에서 조절 (레퍼런스의 "조절").
  void _openTypeSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: t(context).paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _TypeSheet(),
    );
  }

  void _openWidgetOpacitySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: t(context).paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _WidgetOpacitySheet(),
    );
  }

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
    // 복원 방식 두 가지 중 선택.
    final mode = await _pickRestoreMode(context);
    if (mode == null) return;
    try {
      await ref
          .read(backupServiceProvider)
          .importJson(json, merge: mode == 'merge');
      if (context.mounted) {
        _toast(context, mode == 'merge' ? '백업을 합쳤어요' : '백업으로 되돌렸어요');
      }
    } catch (e) {
      if (context.mounted) {
        _toast(context, '복원 실패 — 올바른 백업 파일인지 확인해 주세요');
      }
    }
  }

  /// 복원 방식 선택 — 'replace'(전체 교체) / 'merge'(합치기) / null(취소).
  Future<String?> _pickRestoreMode(BuildContext context) {
    // 앱 공통 에디토리얼 시트(플랫 핸들·각진 테두리·명조 제목)로 통일.
    return showEditorialSheet<String>(
      context,
      scrollable: false,
      builder: (ctx) {
        final tk = t(ctx);
        Widget option(String value, String title, String sub, bool danger) =>
            GestureDetector(
              onTap: () => Navigator.pop(ctx, value),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    border:
                        Border.all(color: danger ? tk.mark : tk.line)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppText.body(danger ? tk.mark : tk.ink)
                            .copyWith(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(sub, style: AppText.meta(tk.inkSoft, size: 10)),
                  ],
                ),
              ),
            );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('어떻게 복원할까요?', style: AppText.serif(tk.ink, size: 18)),
            const SizedBox(height: 5),
            Text('선택한 백업을 어떻게 되돌릴지 골라주세요.',
                style: AppText.meta(tk.inkSoft, size: 11)),
            const SizedBox(height: 12),
            // 두 선택지를 한 줄에 나란히 — 카드 높이는 IntrinsicHeight 로 맞춘다.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: option('merge', '합치기 (덮어쓰기)',
                        '지금 쓴 기록은 그대로 두고, 백업을 그 위에 얹어요.', false),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: option('replace', '전체 교체',
                        '백업 안 한 기록까지 모두 지우고, 백업만 남겨요.', true),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// 내장 10종 테마 스와치 — paper / ink / mark 3색 바. 선택 = ink 1.5px 테두리.
/// 글꼴 선택기 — 각 폰트를 그 폰트로 렌더한 미리보기와 함께 세로 나열.
class _FontPicker extends StatelessWidget {
  const _FontPicker({required this.current, required this.onPick});
  final String current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final selected =
        kFonts.any((f) => f.key == current) ? current : kDefaultFontKey;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
      child: Column(
        children: [
          for (final f in kFonts)
            GestureDetector(
              onTap: () => onPick(f.key),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected == f.key ? tk.ink : tk.line,
                    width: selected == f.key ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(f.name,
                                  style: AppText.meta(
                                      selected == f.key ? tk.ink : tk.inkSoft)),
                              if (f.oneWeight) ...[
                                const SizedBox(width: 8),
                                Text('굵기 고정',
                                    style: AppText.meta(tk.inkSoft, size: 9)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          // 미리보기: 그 폰트로 렌더.
                          Text(f.sample,
                              style: TextStyle(
                                  fontFamily: f.family,
                                  fontSize: 18,
                                  color: tk.ink)),
                        ],
                      ),
                    ),
                    if (selected == f.key)
                      Text('›', style: AppText.glyph(tk.mark, size: 18)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 테마 카드 가로 스크롤 — 레퍼런스 .theme-row(overflow:auto). 스와치(paper/ink/mark)
/// + 이름. 선택 = 마크색 2px 아웃라인.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.current, required this.onPick});
  final String current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
      child: Row(
        children: [
          for (final spec in kThemes)
            Padding(
              padding: const EdgeInsets.only(right: 9),
              child: GestureDetector(
                onTap: () => onPick(spec.key),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 92,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: spec.tokens.paper,
                    border: Border.all(
                      color: current == spec.key ? tk.mark : tk.line,
                      width: current == spec.key ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 40,
                        child: Row(
                          children: [
                            Expanded(
                                child: Container(color: spec.tokens.paper2)),
                            Expanded(child: Container(color: spec.tokens.ink)),
                            Expanded(child: Container(color: spec.tokens.mark)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(spec.name.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.meta(
                              current == spec.key ? tk.ink : tk.inkSoft,
                              size: 8)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 커스텀 팔레트 편집 — 배경·글자·보조 글자·구분선·포인트 색을 직접 고른다.
/// 아무 색이나 바꾸면 테마가 '내 팔레트(custom)'로 전환된다.
class _CustomPalette extends StatelessWidget {
  const _CustomPalette({required this.settings, required this.ctrl});
  final AppSettings settings;
  final SettingsController ctrl;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final active = settings.themeKey == kCustomThemeKey;
    Widget row(String name, String hint, Color color, bool last,
        ValueChanged<int> onPick) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          final picked = await _pickColor(context, name, color);
          if (picked != null) onPick(picked.toARGB32());
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(bottom: BorderSide(color: tk.line, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppText.body(tk.ink)),
                    const SizedBox(height: 2),
                    Text(hint, style: AppText.meta(tk.inkSoft, size: 10)),
                  ],
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: tk.ink.withValues(alpha: 0.25)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
      child: Container(
        decoration: BoxDecoration(
          color: tk.paper,
          border: Border.all(
              color: active ? tk.mark : tk.line, width: active ? 2 : 1),
        ),
        child: Column(
          children: [
            row('배경', '위젯·화면 바탕색', Color(settings.customPaper), false,
                (v) => ctrl.setCustomColor(paper: v)),
            row('글자', '본문·제목 글자색', Color(settings.customInk), false,
                (v) => ctrl.setCustomColor(ink: v)),
            row('보조 글자', '메타·날짜·흐린 글자', Color(settings.customInkSoft), false,
                (v) => ctrl.setCustomColor(inkSoft: v)),
            row('구분선', '얇은 선·경계', Color(settings.customLine), false,
                (v) => ctrl.setCustomColor(line: v)),
            row('포인트', '오늘·강조 색', Color(settings.customMark), true,
                (v) => ctrl.setCustomColor(mark: v)),
          ],
        ),
      ),
    );
  }
}

/// 색 선택 시트 — 스와치 격자에서 하나 고른다. 고른 색을 반환(취소 시 null).
Future<Color?> _pickColor(BuildContext context, String title, Color current) {
  const swatches = <int>[
    // 배경/밝은 톤
    0xFFEAE4D9, 0xFFF1EADF, 0xFFF3E7E4, 0xFFECE5EF, 0xFFE7E9DE, 0xFFF7F8F4,
    0xFFFBF8F0, 0xFFF0E4D8, 0xFFEAE7D6, 0xFFE6E8EA, 0xFFF0E7E4, 0xFFECE6EA,
    // 구분선/중간 톤
    0xFFDAD2C3, 0xFFDCD3E3, 0xFFD6DACB, 0xFFE0D4C1, 0xFFE7D6D3, 0xFFCDD1D4,
    0xFF897F70, 0xFF8A8092, 0xFF7C8377, 0xFF8C7C68, 0xFF907E82, 0xFF9A9678,
    // 글자/어두운 톤
    0xFF231E18, 0xFF2E2733, 0xFF2B322A, 0xFF263029, 0xFF3A2A20, 0xFF23292E,
    0xFF102A22, 0xFF141613, 0xFF201E1A, 0xFF322523, 0xFF2C2330, 0xFF11192A,
    // 포인트
    0xFFD6852A, 0xFFD79E3B, 0xFFC4794A, 0xFFC1854E, 0xFFD08A6A, 0xFFC0603A,
    0xFFA64B54, 0xFF7A4A6E, 0xFF607D6C, 0xFF4A5A66, 0xFF7A6A2E, 0xFFB0392E,
  ];
  return showModalBottomSheet<Color>(
    context: context,
    builder: (ctx) {
      final tk = t(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$title 색', style: AppText.hTitle(tk.ink)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final v in swatches)
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(Color(v)),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(v),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (current.toARGB32() == v)
                                ? tk.mark
                                : tk.ink.withValues(alpha: 0.18),
                            width: (current.toARGB32() == v) ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 편집 톤 플랫 토글 — 레퍼런스 .switch. 46×28 트랙, 켜짐=마크색.
class _PillSwitch extends StatelessWidget {
  const _PillSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: value ? tk.mark : tk.line,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 토글 행 — 제목 + 부제 + 우측 플랫 토글. 하단 헤어라인.
class _PillSwitchRow extends StatelessWidget {
  const _PillSwitchRow(
      {required this.title,
      required this.sub,
      required this.value,
      required this.onChanged,
      this.divider = true});
  final String title;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return Container(
      decoration: divider
          ? BoxDecoration(border: Border(bottom: BorderSide(color: tk.line)))
          : null,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(tk.ink)),
                const SizedBox(height: 3),
                Text(sub, style: AppText.meta(tk.inkSoft, size: 10)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _PillSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// 생년월일과 시간 행 — 값(있으면) 또는 안내 + 우측 "수정"/"입력". 상세는 SajuEditorPage.
class _SajuRow extends StatelessWidget {
  const _SajuRow(
      {required this.settings, required this.ctrl, this.divider = true});
  final AppSettings settings;
  final SettingsController ctrl;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    final b = settings.birth;
    void open() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SajuEditorPage(ctrl: ctrl, initial: settings)));

    String sub;
    String action;
    if (b == null) {
      sub = '오늘의 운세·사주 분석에 사용해요';
      action = '입력';
    } else {
      final dateStr =
          '${b.year}.${b.month.toString().padLeft(2, '0')}.${b.day.toString().padLeft(2, '0')}';
      final timeStr = settings.birthHasTime
          ? '${b.hour.toString().padLeft(2, '0')}:${b.minute.toString().padLeft(2, '0')}'
          : '시 모름';
      sub = '$dateStr · $timeStr · ${settings.birthMale ? '남' : '여'}';
      action = '수정';
    }

    return GestureDetector(
      onTap: open,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: divider
            ? BoxDecoration(border: Border(bottom: BorderSide(color: tk.line)))
            : null,
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('생년월일과 시간', style: AppText.body(tk.ink)),
                  const SizedBox(height: 3),
                  Text(sub, style: AppText.meta(tk.inkSoft, size: 10)),
                ],
              ),
            ),
            Text(action, style: AppText.meta(tk.mark, size: 11)),
          ],
        ),
      ),
    );
  }
}

/// 위젯 투명도 행 — 현재값 표시 + "조절"(시트). 값은 비동기 로드.
class _WidgetOpacityRow extends StatefulWidget {
  const _WidgetOpacityRow({required this.onAdjust, this.divider = true});
  final VoidCallback onAdjust;
  final bool divider;
  @override
  State<_WidgetOpacityRow> createState() => _WidgetOpacityRowState();
}

class _WidgetOpacityRowState extends State<_WidgetOpacityRow> {
  int _value = 90;
  @override
  void initState() {
    super.initState();
    WidgetBridge.getWidgetOpacity().then((v) {
      if (mounted) setState(() => _value = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tk = t(context);
    return GestureDetector(
      onTap: widget.onAdjust,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: widget.divider
            ? BoxDecoration(border: Border(bottom: BorderSide(color: tk.line)))
            : null,
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('위젯 배경 진하기', style: AppText.body(tk.ink)),
                  const SizedBox(height: 3),
                  Text('현재 $_value% · 0%면 완전 투명',
                      style: AppText.meta(tk.inkSoft, size: 10)),
                ],
              ),
            ),
            Text('조절', style: AppText.meta(tk.mark, size: 11)),
          ],
        ),
      ),
    );
  }
}

/// 글자 크기·굵기·글꼴 조절 시트.
class _TypeSheet extends ConsumerWidget {
  const _TypeSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = t(context);
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 24),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                    color: tk.line, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 16),
            Text('글자 조절',
                style: AppText.hTitle(tk.ink).copyWith(fontSize: 20)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('글자 크기', style: AppText.body(tk.ink)),
                Text('${(s.fontScale * 100).round()}%',
                    style: AppText.meta(tk.inkSoft)),
              ],
            ),
            Slider(
              value: s.fontScale,
              min: 0.85,
              max: 1.4,
              divisions: 11,
              onChanged: (v) => ctrl.setFontScale((v * 100).round() / 100),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('글자 굵기', style: AppText.body(tk.ink)),
                Text(_weightLabel(s.weightDelta),
                    style: AppText.meta(tk.inkSoft)),
              ],
            ),
            Slider(
              value: s.weightDelta.toDouble(),
              min: -1,
              max: 2,
              divisions: 3,
              onChanged: (v) => ctrl.setWeightDelta(v.round()),
            ),
            const SizedBox(height: 8),
            const SectionLabel('앱 글꼴'),
            _FontPicker(current: s.fontKey, onPick: ctrl.setFontKey),
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
}

/// 위젯 투명도 조절 시트.
class _WidgetOpacitySheet extends StatefulWidget {
  const _WidgetOpacitySheet();
  @override
  State<_WidgetOpacitySheet> createState() => _WidgetOpacitySheetState();
}

class _WidgetOpacitySheetState extends State<_WidgetOpacitySheet> {
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                    color: tk.line, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('위젯 배경 진하기', style: AppText.body(tk.ink)),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0% 완전 투명', style: AppText.meta(tk.inkSoft, size: 10)),
                Text('100% 꽉 찬 배경', style: AppText.meta(tk.inkSoft, size: 10)),
              ],
            ),
          ],
        ),
      ),
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
  Region _region = seoulRegion;
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    final b = s.birth;
    _male = s.birthMale;
    _cal = s.birthCalendar;
    _leap = s.birthLeap;
    _timeUnknown = b != null && !s.birthHasTime;
    // 저장된 지역명(우선)·경도로 지역 되살리기.
    _region = resolveRegion(s.birthPlace, s.birthLongitude);
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
      longitude: _region.lng,
      latitude: _region.lat,
      male: _male,
      place: _region.name,
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
            _seg(['남', '여'], _male ? 0 : 1,
                (i) => setState(() => _male = i == 0)),
            const SectionLabel('달력'),
            _seg(['양력', '음력'], _cal == 'solar' ? 0 : 1,
                (i) => setState(() => _cal = i == 0 ? 'solar' : 'lunar')),
            if (_cal == 'lunar')
              Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
                child: Row(
                  children: [
                    Expanded(child: Text('윤달', style: AppText.body(tk.ink))),
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
                child:
                    Text('→ $preview', style: AppText.meta(tk.mark, size: 12)),
              ),
            const SectionLabel('태어난 시각'),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 0),
              child: Row(
                children: [
                  Expanded(child: Text('시각을 몰라요', style: AppText.body(tk.ink))),
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
            const SectionLabel('출생지 (지역)'),
            _regionPicker(tk),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
              child: Text(
                  '지역으로 진태양시(사주)와 상승궁(점성학)을 자동 보정해요. '
                  '서머타임·한국 표준시 변천도 자동 반영.',
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
              child: _wheel(31, _day - 1, (i) => setState(() => _day = i + 1),
                  (i) => '${i + 1}일'),
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

  Widget _regionPicker(AppTokens tk) {
    final results = searchRegions(_query).take(30).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
          child: TextField(
            controller: _search,
            style: AppText.body(tk.ink),
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              isDense: true,
              hintText: '지역 이름 검색 (예: 성남, 강릉, 제주)',
              hintStyle: AppText.meta(tk.inkSoft),
              prefixIcon: Icon(Icons.search, size: 18, color: tk.inkSoft),
              suffixIcon: _query.isEmpty
                  ? null
                  : GestureDetector(
                      onTap: () => setState(() {
                        _query = '';
                        _search.clear();
                      }),
                      child: Icon(Icons.close, size: 18, color: tk.inkSoft),
                    ),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: tk.line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: tk.ink, width: 1.5)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
          child: Text('선택한 지역: ${_region.name}',
              style: AppText.meta(tk.mark, size: 12)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (results.isEmpty)
                Text('검색 결과가 없어요. 시·군 이름으로 다시 찾아보세요.',
                    style: AppText.meta(tk.inkSoft))
              else
                for (final r in results)
                  _regionChip(r, _region.name == r.name,
                      () => setState(() => _region = r)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _regionChip(Region r, bool sel, VoidCallback onTap) {
    final tk = t(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border:
              Border.all(color: sel ? tk.ink : tk.line, width: sel ? 1.5 : 1),
        ),
        child: Text(r.name, style: AppText.chip(sel ? tk.ink : tk.inkSoft)),
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
