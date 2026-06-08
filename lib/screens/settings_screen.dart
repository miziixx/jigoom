import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../flavor.dart';
import 'dev_center_screen.dart';
import '../models/entry_display_mode.dart';
import '../services/backup_service.dart';
import '../services/storage_service.dart';
import '../utils/logroom_entries.dart';

// ──────────────────────────────────────────────────────────────────
// Settings Screen (full page, replaces SettingsDialog)
// ──────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  final Color initialBg;
  final Color initialText;
  final bool initialTabLocked;
  final String initialFontFamily;
  final double initialFontSize;
  final double initialSpacing;
  final void Function(
    Color bg,
    Color text,
    String fontFamily,
    double fontSize,
    double spacing,
    bool tabLocked,
  )
  onSave;
  final Future<bool> Function() onBackupSave;
  final void Function(Map<String, dynamic> data, {bool merge})
  onRestoreConfirmed;
  final VoidCallback onClearCache;
  final void Function(List<String> blocks) onImportTxt;

  const SettingsScreen({
    super.key,
    required this.initialBg,
    required this.initialText,
    required this.initialTabLocked,
    required this.initialFontFamily,
    required this.initialFontSize,
    required this.initialSpacing,
    required this.onSave,
    required this.onBackupSave,
    required this.onRestoreConfirmed,
    required this.onClearCache,
    required this.onImportTxt,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Color _bg;
  late Color _text;
  late TextEditingController _bgCtrl;
  late TextEditingController _textCtrl;
  late bool _tabLocked;
  late String _fontFamily;
  late double _fontSize;
  late double _spacing;
  late Color _accent;
  late TextEditingController _accentCtrl;
  late EntryDisplayMode _entryDisplayMode;
  late EntryDisplayMode _initialEntryDisplayMode;
  late AppThemeMode _themeMode;
  late AppThemeMode _initialThemeMode;
  bool _saved = false;
  bool _restoring = false;
  int _versionTapCount = 0;
  Timer? _versionTapTimer;

  // palette slots: null = empty
  late List<(Color, Color)?> _palettes;
  bool _palettesLoaded = false;

  @override
  void initState() {
    super.initState();
    _bg = widget.initialBg;
    _text = widget.initialText;
    _tabLocked = widget.initialTabLocked;
    _fontFamily = widget.initialFontFamily;
    _fontSize = widget.initialFontSize;
    _spacing = widget.initialSpacing;
    _initialEntryDisplayMode = entryDisplayModeNotifier.value;
    _entryDisplayMode = _initialEntryDisplayMode;
    _initialThemeMode = appThemeModeNotifier.value;
    _themeMode = _initialThemeMode;
    _accent = kAccent;
    _bgCtrl = TextEditingController(text: _toHex(_bg));
    _textCtrl = TextEditingController(text: _toHex(_text));
    _accentCtrl = TextEditingController(text: _toHex(_accent));
    _palettes = List.filled(StorageService.paletteSlotCount, null);
    _loadPalettes();
  }

  Future<void> _loadPalettes() async {
    final loaded = await StorageService.loadPalettes();
    if (!mounted) return;
    setState(() {
      _palettes = loaded;
      _palettesLoaded = true;
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _textCtrl.dispose();
    _accentCtrl.dispose();
    _versionTapTimer?.cancel();
    if (!_saved) {
      // Revert real-time preview changes on cancel
      WidgetsBinding.instance.addPostFrameCallback((_) {
        applyColors(widget.initialBg, widget.initialText);
        applyFont(widget.initialFontFamily, widget.initialFontSize);
        applySpacing(widget.initialSpacing);
        applyEntryDisplayMode(_initialEntryDisplayMode);
        applyAppThemeMode(_initialThemeMode);
      });
    }
    super.dispose();
  }

  // ── Color helpers ──────────────────────────────────

  static String _toHex(Color c) {
    int ch(double v) => (v * 255.0).round().clamp(0, 255);
    return [
      ch(c.r),
      ch(c.g),
      ch(c.b),
    ].map((v) => v.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  static Color? _parseHex(String raw) {
    final hex = raw.replaceAll('#', '').trim();
    if (hex.length == 6) {
      try {
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }
    return null;
  }

  int _r(Color c) => (c.r * 255).round().clamp(0, 255);
  int _g(Color c) => (c.g * 255).round().clamp(0, 255);
  int _b(Color c) => (c.b * 255).round().clamp(0, 255);

  Color _fromRGB(int r, int g, int b) => Color.fromARGB(255, r, g, b);

  void _setBg(Color c) {
    setState(() => _bg = c);
    final hex = _toHex(c);
    if (_bgCtrl.text.toUpperCase() != hex) {
      _bgCtrl.value = _bgCtrl.value.copyWith(
        text: hex,
        selection: TextSelection.collapsed(offset: hex.length),
      );
    }
    applyColors(c, _text); // real-time preview
  }

  void _setText(Color c) {
    setState(() => _text = c);
    final hex = _toHex(c);
    if (_textCtrl.text.toUpperCase() != hex) {
      _textCtrl.value = _textCtrl.value.copyWith(
        text: hex,
        selection: TextSelection.collapsed(offset: hex.length),
      );
    }
    applyColors(_bg, c); // real-time preview
  }

  void _setAccent(Color c) {
    setState(() => _accent = c);
    final hex = _toHex(c);
    if (_accentCtrl.text.toUpperCase() != hex) {
      _accentCtrl.value = _accentCtrl.value.copyWith(
        text: hex,
        selection: TextSelection.collapsed(offset: hex.length),
      );
    }
    applyColorsV3(_bg, _text, c);
  }

  void _applyPreset(Color bg, Color text, Color accent) {
    setState(() {
      _bg = bg;
      _text = text;
      _accent = accent;
      _bgCtrl.text = _toHex(bg);
      _textCtrl.text = _toHex(text);
      _accentCtrl.text = _toHex(accent);
    });
    applyColorsV3(bg, text, accent);
  }

  // ── Palette actions ────────────────────────────────

  void _snack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kSurface,
        duration: const Duration(seconds: 2),
        content: Text(msg, style: mono(color: kMint, fontSize: 12)),
      ),
    );
  }

  Future<void> _savePaletteToCurrent() async {
    final emptyIdx = _palettes.indexWhere((s) => s == null);
    if (emptyIdx == -1) {
      _snack('슬롯이 가득 찼어요.');
      return;
    }
    await StorageService.savePaletteSlot(emptyIdx, _bg, _text);
    setState(() => _palettes[emptyIdx] = (_bg, _text));
    _snack('저장했습니다.');
  }

  Future<void> _saveToSlot(int i) async {
    await StorageService.savePaletteSlot(i, _bg, _text);
    setState(() => _palettes[i] = (_bg, _text));
    _snack('저장했습니다.');
  }

  Future<void> _applySlot(int i) async {
    final slot = _palettes[i];
    if (slot == null) return;
    final (bg, text) = slot;
    setState(() {
      _bg = bg;
      _text = text;
      _bgCtrl.text = _toHex(bg);
      _textCtrl.text = _toHex(text);
    });
    applyColors(bg, text);
    _snack('적용했습니다.');
  }

  Future<void> _deleteSlot(int i) async {
    await StorageService.clearPaletteSlot(i);
    setState(() => _palettes[i] = null);
    _snack('삭제했습니다.');
  }

  // ── Actions ────────────────────────────────────────

  void _resetDefaults() {
    final bg = const Color(0xFFEDF2ED);
    final text = const Color(0xFF556B2F);
    setState(() {
      _bg = bg;
      _text = text;
      _tabLocked = false;
      _fontFamily = 'JetBrains Mono';
      _fontSize = 13.0;
      _spacing = 12.0;
      _themeMode = AppThemeMode.normal;
      _bgCtrl.text = _toHex(_bg);
      _textCtrl.text = _toHex(_text);
    });
    applyColors(bg, text);
    applyFont(_fontFamily, _fontSize);
    applySpacing(_spacing);
    applyAppThemeMode(_themeMode);
  }

  void _save() {
    _saved = true;
    StorageService.saveEntryDisplayMode(_entryDisplayMode);
    StorageService.saveAppThemeMode(_themeMode);
    if (isLogroomUi) StorageService.saveAccent(_accent);
    widget.onSave(_bg, _text, _fontFamily, _fontSize, _spacing, _tabLocked);
    Navigator.pop(context);
  }

  Future<void> _doBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: '데이터 백업',
        body: '백업하시겠습니까?\n백업 파일이 휴대폰에 저장됩니다.',
        confirmLabel: '백업',
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
    if (confirmed != true || !mounted) return;
    final saved = await widget.onBackupSave();
    if (!mounted) return;
    _snack(saved ? '백업 완료. 선택한 저장 위치에 저장되었습니다.' : '백업이 취소되었습니다.');
  }

  Future<void> _doRestore() async {
    if (_restoring) return;
    setState(() => _restoring = true);

    final data = await BackupService.import();
    if (!mounted) return;

    if (data == null) {
      setState(() => _restoring = false);
      return;
    }

    final mode = await _showRestoreOptions();
    if (!mounted) return;
    if (mode == null) {
      setState(() => _restoring = false);
      return;
    }

    _saved = true;
    widget.onRestoreConfirmed(data, merge: mode == 'merge');
    if (mounted) Navigator.pop(context);
  }

  Future<String?> _showRestoreOptions() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '데이터 복원',
                style: mono(color: kMint, fontSize: 13, letterSpacing: 1),
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: kBorder),
              const SizedBox(height: 12),
              Text('복원 방법을 선택하세요.', style: mono(color: kText, fontSize: 12)),
              const SizedBox(height: 6),
              Text(
                '• 덮어쓰기: 현재 데이터를 모두 백업으로 교체',
                style: mono(color: kDim, fontSize: 11, height: 1.6),
              ),
              Text(
                '• 합치기: 현재 데이터에 백업 내용을 추가 (중복 제외)',
                style: mono(color: kDim, fontSize: 11, height: 1.6),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _Btn(
                    label: '취소',
                    color: kDim,
                    onTap: () => Navigator.pop(ctx, null),
                  ),
                  const SizedBox(width: 8),
                  _Btn(
                    label: '합치기',
                    color: kText,
                    onTap: () => Navigator.pop(ctx, 'merge'),
                  ),
                  const SizedBox(width: 8),
                  _Btn(
                    label: '덮어쓰기',
                    color: kMint,
                    onTap: () => Navigator.pop(ctx, 'overwrite'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doClearCache() async {
    final confirmed = await _showClearCacheConfirm();
    if (confirmed != true || !mounted) return;
    _saved = true;
    widget.onClearCache();
    if (mounted) Navigator.pop(context);
  }

  void _onVersionTap() {
    if (!isNemo2Test) return;
    _versionTapTimer?.cancel();
    _versionTapCount++;
    if (_versionTapCount >= 5) {
      _versionTapCount = 0;
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const DevCenterScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
        ),
      );
      return;
    }
    _versionTapTimer = Timer(const Duration(seconds: 2), () {
      _versionTapCount = 0;
    });
  }

  Future<void> _doImportTxt() async {
    final blocks = await BackupService.importTxt();
    if (!mounted) return;
    if (blocks == null) {
      _snack('파일을 읽을 수 없습니다.');
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TxtImportPreviewSheet(blocks: blocks),
    );
    if (confirmed != true || !mounted) return;
    widget.onImportTxt(blocks);
    _snack('${blocks.length}개 메모를 가져왔습니다.');
  }

  Future<bool?> _showClearCacheConfirm() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: '캐시 삭제',
        body: '모든 앱 데이터가 삭제됩니다.\n백업 후 진행하세요.',
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
        confirmColor: Colors.red.shade400,
        confirmLabel: '삭제',
      ),
    );
  }

  // ── Build ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: themeNotifier,
      builder: (context2, snap, child2) => Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Container(height: 1, color: kBorder),
              Expanded(
                child: SingleChildScrollView(
                  padding: appInsetsSymmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── V3 PRESETS (logroomUi only) ──────────
                      if (isLogroomUi) ...[
                        _SectionHeader(label: '색상 프리셋'),
                        const SizedBox(height: 12),
                        _V3PresetGrid(onSelect: _applyPreset),
                        const SizedBox(height: 22),
                      ],

                      // ── SAVED PALETTES ───────────────────────
                      _SectionHeader(label: '저장한 색상'),
                      const SizedBox(height: 14),
                      _PaletteGrid(
                        palettes: _palettes,
                        loaded: _palettesLoaded,
                        onTapFilled: _applySlot,
                        onLongPress: _deleteSlot,
                        onTapEmpty: _saveToSlot,
                      ),
                      const SizedBox(height: 12),
                      _SavePaletteBtn(onTap: _savePaletteToCurrent),
                      const SizedBox(height: 22),

                      // ── APPEARANCE ───────────────────────────
                      _SectionHeader(label: '화면'),
                      const SizedBox(height: 14),

                      _RgbColorSection(
                        label: '배경색',
                        color: _bg,
                        hexCtrl: _bgCtrl,
                        onColorChanged: _setBg,
                        onHexInput: (raw) {
                          final c = _parseHex(raw);
                          if (c != null) _setBg(c);
                        },
                        rVal: _r(_bg),
                        gVal: _g(_bg),
                        bVal: _b(_bg),
                        onRChanged: (v) =>
                            _setBg(_fromRGB(v, _g(_bg), _b(_bg))),
                        onGChanged: (v) =>
                            _setBg(_fromRGB(_r(_bg), v, _b(_bg))),
                        onBChanged: (v) =>
                            _setBg(_fromRGB(_r(_bg), _g(_bg), v)),
                      ),

                      const SizedBox(height: 20),

                      _RgbColorSection(
                        label: '글자색',
                        color: _text,
                        hexCtrl: _textCtrl,
                        onColorChanged: _setText,
                        onHexInput: (raw) {
                          final c = _parseHex(raw);
                          if (c != null) _setText(c);
                        },
                        rVal: _r(_text),
                        gVal: _g(_text),
                        bVal: _b(_text),
                        onRChanged: (v) =>
                            _setText(_fromRGB(v, _g(_text), _b(_text))),
                        onGChanged: (v) =>
                            _setText(_fromRGB(_r(_text), v, _b(_text))),
                        onBChanged: (v) =>
                            _setText(_fromRGB(_r(_text), _g(_text), v)),
                      ),

                      if (isLogroomUi) ...[
                        const SizedBox(height: 20),
                        _AccentSection(
                          accent: _accent,
                          hexCtrl: _accentCtrl,
                          onAccentChanged: _setAccent,
                          onHexInput: (raw) {
                            final c = _parseHex(raw);
                            if (c != null) _setAccent(c);
                          },
                          rVal: _r(_accent),
                          gVal: _g(_accent),
                          bVal: _b(_accent),
                          onRChanged: (v) =>
                              _setAccent(_fromRGB(v, _g(_accent), _b(_accent))),
                          onGChanged: (v) =>
                              _setAccent(_fromRGB(_r(_accent), v, _b(_accent))),
                          onBChanged: (v) =>
                              _setAccent(_fromRGB(_r(_accent), _g(_accent), v)),
                        ),
                      ],

                      const SizedBox(height: 20),

                      Text(
                        '글꼴',
                        style: mono(
                          color: kDim,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: kBorder.withValues(alpha: 0.7),
                          ),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 168),
                          child: ListView(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            children: kFontOptions
                                .map(
                                  (f) => _FontOption(
                                    fontName: f,
                                    isSelected: _fontFamily == f,
                                    onTap: () {
                                      setState(() => _fontFamily = f);
                                      applyFont(_fontFamily, _fontSize);
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      _FontSizeSlider(
                        value: _fontSize,
                        min: 10,
                        max: 20,
                        onChanged: (v) {
                          setState(() => _fontSize = v);
                          applyFont(_fontFamily, _fontSize);
                        },
                      ),

                      const SizedBox(height: 22),

                      Text(
                        '간격',
                        style: mono(
                          color: kDim,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SpacingSelector(
                        value: _spacing,
                        onChanged: (v) {
                          setState(() => _spacing = v);
                          applySpacing(v);
                        },
                      ),

                      const SizedBox(height: 22),

                      // ── GENERAL ──────────────────────────────
                      _SectionHeader(label: '기본 설정'),
                      const SizedBox(height: 14),

                      Text(
                        '기록 표시 방식',
                        style: mono(
                          color: kDim,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _EntryDisplayModeSelector(
                        value: _entryDisplayMode,
                        onChanged: (mode) {
                          setState(() => _entryDisplayMode = mode);
                          applyEntryDisplayMode(mode);
                        },
                      ),

                      const SizedBox(height: 16),
                      Text(
                        '화면 모드',
                        style: mono(
                          color: kDim,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ThemeModeSelector(
                        value: _themeMode,
                        onChanged: (mode) {
                          setState(() => _themeMode = mode);
                          if (mode == AppThemeMode.normal) {
                            applyColors(_bg, _text);
                            applyFont(_fontFamily, _fontSize);
                          }
                          applyAppThemeMode(mode);
                        },
                      ),

                      const SizedBox(height: 22),

                      // ── BACKUP ───────────────────────────────
                      _SectionHeader(label: '데이터 백업'),
                      const SizedBox(height: 14),

                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _Btn(label: '데이터 백업', color: kDim, onTap: _doBackup),
                          _Btn(
                            label: _restoring ? '...' : '복원',
                            color: _restoring
                                ? kDim.withValues(alpha: 0.4)
                                : kDim,
                            onTap: _doRestore,
                          ),
                          _Btn(label: '가져오기', color: kDim, onTap: _doRestore),
                          _Btn(
                            label: '캐시 삭제',
                            color: Colors.red.shade400,
                            onTap: _doClearCache,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Text(
                        '앱 삭제 전 반드시 데이터를 백업하세요.\n삭제 후 데이터는 복구되지 않을 수 있습니다.',
                        style: mono(
                          color: kDim.withValues(alpha: 0.72),
                          fontSize: 10,
                          height: 1.55,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── TXT IMPORT ───────────────────────────
                      _SectionHeader(label: 'TXT 가져오기'),
                      const SizedBox(height: 14),

                      _Btn(label: 'TXT 가져오기', color: kDim, onTap: _doImportTxt),
                      const SizedBox(height: 8),
                      Text(
                        '일반 텍스트 / 카카오톡 나에게 보내기 백업용\n빈 줄 기준으로 메모를 분리합니다.',
                        style: mono(
                          color: kDim.withValues(alpha: 0.72),
                          fontSize: 10,
                          height: 1.55,
                        ),
                      ),

                      const SizedBox(height: 28),
                      _dotLine(),
                      const SizedBox(height: 14),

                      // ── Bottom actions ───────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _Btn(
                            label: '초기화',
                            color: kDim,
                            onTap: _resetDefaults,
                          ),
                          const SizedBox(width: 10),
                          _Btn(label: '저장', color: kMint, onTap: _save),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // ── VERSION (nemo2test: 5-tap to open Dev Center) ─
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _onVersionTap,
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Text(
                            'v2.0.0',
                            style: mono(
                              color: kDim.withValues(alpha: 0.35),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 44,
      color: kBg,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _BackBtn(onTap: () => Navigator.pop(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '설정',
              style: mono(color: kMint, fontSize: 13, letterSpacing: 1),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 60), // balance
        ],
      ),
    );
  }

  Widget _dotLine() => Text(
    '. ' * 100,
    style: mono(color: kBorder.withValues(alpha: 0.8), fontSize: 8),
    overflow: TextOverflow.clip,
    maxLines: 1,
    softWrap: false,
  );
}

// ──────────────────────────────────────────────────────────────────
// TXT import preview sheet
// ──────────────────────────────────────────────────────────────────

class _TxtImportPreviewSheet extends StatelessWidget {
  final List<String> blocks;

  const _TxtImportPreviewSheet({required this.blocks});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TXT 가져오기 미리보기',
                  style: mono(color: kMint, fontSize: 13, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  '총 ${blocks.length}개 메모',
                  style: mono(color: kDim, fontSize: 11),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: blocks.length,
              separatorBuilder: (_, __) =>
                  Container(height: 1, color: kBorder),
              itemBuilder: (_, i) {
                final preview = blocks[i].split('\n').take(3).join('\n');
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '[${i + 1}]',
                        style: mono(color: kDim, fontSize: 10),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        preview,
                        style: mono(color: kText, fontSize: 12, height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: kBorder)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _Btn(
                  label: '취소',
                  color: kDim,
                  onTap: () => Navigator.pop(context, false),
                ),
                const SizedBox(width: 10),
                _Btn(
                  label: '가져오기',
                  color: kMint,
                  onTap: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Section header
// ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: mono(
            color: kText,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '- ' * 80,
          style: mono(color: kBorder.withValues(alpha: 0.8), fontSize: 8),
          overflow: TextOverflow.clip,
          maxLines: 1,
          softWrap: false,
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// RGB slider + hex input color section
// ──────────────────────────────────────────────────────────────────

class _RgbColorSection extends StatelessWidget {
  final String label;
  final Color color;
  final TextEditingController hexCtrl;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<String> onHexInput;
  final int rVal, gVal, bVal;
  final ValueChanged<int> onRChanged, onGChanged, onBChanged;

  const _RgbColorSection({
    required this.label,
    required this.color,
    required this.hexCtrl,
    required this.onColorChanged,
    required this.onHexInput,
    required this.rVal,
    required this.gVal,
    required this.bVal,
    required this.onRChanged,
    required this.onGChanged,
    required this.onBChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: mono(color: kDim, fontSize: 11, letterSpacing: 0.5)),
        const SizedBox(height: 10),

        _RgbSliderRow(
          channel: 'R',
          value: rVal,
          trackColor: kText,
          onChanged: onRChanged,
        ),
        const SizedBox(height: 6),
        _RgbSliderRow(
          channel: 'G',
          value: gVal,
          trackColor: kText,
          onChanged: onGChanged,
        ),
        const SizedBox(height: 6),
        _RgbSliderRow(
          channel: 'B',
          value: bVal,
          trackColor: kText,
          onChanged: onBChanged,
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: kBorder),
              ),
            ),
            const SizedBox(width: 10),
            Text('#', style: mono(color: kMint, fontSize: 14)),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: hexCtrl,
                style: mono(color: kText, fontSize: 13),
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                ],
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: kBorder.withValues(alpha: 0.25),
                  hintText: 'RRGGBB',
                  hintStyle: mono(color: kDim, fontSize: 12),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: kBorder),
                    borderRadius: BorderRadius.zero,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: kBorder),
                    borderRadius: BorderRadius.zero,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: kMint),
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onChanged: onHexInput,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Single RGB slider row: "R ──────●──  247"
// ──────────────────────────────────────────────────────────────────

class _RgbSliderRow extends StatelessWidget {
  final String channel;
  final int value;
  final Color trackColor;
  final ValueChanged<int> onChanged;

  const _RgbSliderRow({
    required this.channel,
    required this.value,
    required this.trackColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 14,
          child: Text(channel, style: mono(color: kDim, fontSize: 10)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: trackColor,
              inactiveTrackColor: kBorder.withValues(alpha: 0.4),
              thumbColor: kBg,
              overlayColor: trackColor.withValues(alpha: 0.15),
              thumbShape: _BorderedThumb(
                thumbColor: kBg,
                borderColor: trackColor,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: Text(
            '$value',
            style: mono(color: kDim, fontSize: 10),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _BorderedThumb extends SliderComponentShape {
  final Color thumbColor;
  final Color borderColor;
  const _BorderedThumb({required this.thumbColor, required this.borderColor});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(14, 14);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = thumbColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Font option row
// ──────────────────────────────────────────────────────────────────

class _FontOption extends StatefulWidget {
  final String fontName;
  final bool isSelected;
  final VoidCallback onTap;

  const _FontOption({
    required this.fontName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FontOption> createState() => _FontOptionState();
}

class _FontOptionState extends State<_FontOption> {
  bool _hovered = false;

  TextStyle _nameStyle() {
    final c = widget.isSelected ? kMint : (_hovered ? kText : kDim);
    const sz = 11.0;
    // Preview each option in its own bundled font (offline-safe).
    return TextStyle(fontFamily: widget.fontName, fontSize: sz, color: c);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isSelected
        ? kMint.withValues(alpha: 0.08)
        : (_hovered ? kBorder.withValues(alpha: 0.2) : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Text(
                widget.isSelected ? '> ' : '  ',
                style: mono(color: kMint, fontSize: 11),
              ),
              Expanded(
                child: Text(
                  widget.fontName,
                  style: _nameStyle(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontSizeSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _FontSizeSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '글자 크기',
              style: mono(color: kDim, fontSize: 11, letterSpacing: 0.5),
            ),
            const Spacer(),
            Text(
              value.toInt().toString(),
              style: mono(color: kText, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            activeTrackColor: kText,
            inactiveTrackColor: kBorder.withValues(alpha: 0.4),
            thumbColor: kBg,
            overlayColor: kText.withValues(alpha: 0.12),
            thumbShape: _BorderedThumb(thumbColor: kBg, borderColor: kText),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Toggle switch
// ──────────────────────────────────────────────────────────────────

class _ToggleSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleSwitch({required this.value, required this.onChanged});

  @override
  State<_ToggleSwitch> createState() => _ToggleSwitchState();
}

class _EntryDisplayModeSelector extends StatelessWidget {
  final EntryDisplayMode value;
  final ValueChanged<EntryDisplayMode> onChanged;

  const _EntryDisplayModeSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: appSpace(6),
      runSpacing: appSpace(6),
      children: EntryDisplayMode.values
          .map(
            (mode) => _ModeOption(
              label: mode.settingsLabel,
              active: value == mode,
              onTap: () => onChanged(mode),
            ),
          )
          .toList(),
    );
  }
}

class _ModeOption extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeOption({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_ModeOption> createState() => _ModeOptionState();
}

class _ModeOptionState extends State<_ModeOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: appInsetsSymmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: widget.active
                ? kMint.withValues(alpha: 0.12)
                : (_hovered
                      ? kBorder.withValues(alpha: 0.15)
                      : Colors.transparent),
            border: widget.active
                ? Border.all(color: kMint.withValues(alpha: 0.4))
                : Border.all(color: kBorder.withValues(alpha: 0.5)),
          ),
          child: Text(
            widget.label,
            style: mono(color: widget.active ? kMint : kDim, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  const _ThemeModeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final modes = AppThemeMode.values
        .where((mode) => mode != AppThemeMode.minimal || isLogroomUi)
        .toList();
    return Wrap(
      spacing: appSpace(6),
      runSpacing: appSpace(6),
      children: modes
          .map(
            (mode) => _ModeOption(
              label: mode.label,
              active: value == mode,
              onTap: () => onChanged(mode),
            ),
          )
          .toList(),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Spacing selector
// ──────────────────────────────────────────────────────────────────

class _SpacingSelector extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _SpacingSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: appSpace(6),
      runSpacing: appSpace(6),
      children: kSpacingOptions
          .map(
            (option) => _SpacingOption(
              label: option.toInt().toString(),
              active: value == option,
              onTap: () => onChanged(option),
            ),
          )
          .toList(),
    );
  }
}

class _SpacingOption extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SpacingOption({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_SpacingOption> createState() => _SpacingOptionState();
}

class _SpacingOptionState extends State<_SpacingOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: appInsetsSymmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: widget.active
                ? kMint.withValues(alpha: 0.12)
                : (_hovered
                      ? kBorder.withValues(alpha: 0.15)
                      : Colors.transparent),
            border: widget.active
                ? Border.all(color: kMint.withValues(alpha: 0.4))
                : Border.all(color: kBorder.withValues(alpha: 0.5)),
          ),
          child: Text(
            widget.label,
            style: mono(color: widget.active ? kMint : kDim, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

class _ToggleSwitchState extends State<_ToggleSwitch> {
  @override
  Widget build(BuildContext context) {
    final on = widget.value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SwitchOption(
          label: 'ON',
          active: on,
          onTap: () => widget.onChanged(true),
        ),
        const SizedBox(width: 6),
        _SwitchOption(
          label: 'OFF',
          active: !on,
          onTap: () => widget.onChanged(false),
        ),
      ],
    );
  }
}

class _SwitchOption extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SwitchOption({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_SwitchOption> createState() => _SwitchOptionState();
}

class _SwitchOptionState extends State<_SwitchOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: widget.active
                ? kMint.withValues(alpha: 0.12)
                : (_hovered
                      ? kBorder.withValues(alpha: 0.15)
                      : Colors.transparent),
            border: widget.active
                ? Border.all(color: kMint.withValues(alpha: 0.4))
                : Border.all(color: kBorder.withValues(alpha: 0.5)),
          ),
          child: Text(
            widget.label,
            style: mono(color: widget.active ? kMint : kDim, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Step button  +/-
// ──────────────────────────────────────────────────────────────────

class _StepBtn extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _StepBtn({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_StepBtn> createState() => _StepBtnState();
}

class _StepBtnState extends State<_StepBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.enabled
        ? (_hovered ? kMint : kDim)
        : kDim.withValues(alpha: 0.3);
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.enabled && _hovered
                ? kMint.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Text(widget.label, style: mono(color: c, fontSize: 14)),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Action button
// ──────────────────────────────────────────────────────────────────

class _Btn extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.color, required this.onTap});

  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Text(
            widget.label,
            style: mono(color: widget.color, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Back button
// ──────────────────────────────────────────────────────────────────

class _BackBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});

  @override
  State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered
                ? kMint.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Text(
            '←',
            style: mono(color: _hovered ? kMint : kDim, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Palette grid (5 slots)
// ──────────────────────────────────────────────────────────────────

class _PaletteGrid extends StatelessWidget {
  final List<(Color, Color)?> palettes;
  final bool loaded;
  final void Function(int) onTapFilled;
  final void Function(int) onLongPress;
  final void Function(int) onTapEmpty;

  const _PaletteGrid({
    required this.palettes,
    required this.loaded,
    required this.onTapFilled,
    required this.onLongPress,
    required this.onTapEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(StorageService.paletteSlotCount, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: i < StorageService.paletteSlotCount - 1 ? 6 : 0,
            ),
            child: _PaletteSlotCard(
              slot: loaded ? palettes[i] : null,
              onTap: () {
                if (palettes[i] != null) {
                  onTapFilled(i);
                } else {
                  onTapEmpty(i);
                }
              },
              onLongPress: palettes[i] != null ? () => onLongPress(i) : null,
            ),
          ),
        );
      }),
    );
  }
}

class _PaletteSlotCard extends StatefulWidget {
  final (Color, Color)? slot; // (bg, text)
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PaletteSlotCard({
    required this.slot,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_PaletteSlotCard> createState() => _PaletteSlotCardState();
}

class _PaletteSlotCardState extends State<_PaletteSlotCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    const cardH = 56.0;

    if (slot == null) {
      // Empty slot — dashed border + "+"
      return GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: cardH,
          decoration: BoxDecoration(
            color: _pressed
                ? kBorder.withValues(alpha: 0.15)
                : Colors.transparent,
          ),
          child: CustomPaint(
            painter: _DashBorderPainter(color: kBorder.withValues(alpha: 0.6)),
            child: Center(
              child: Text(
                '+',
                style: mono(color: kDim.withValues(alpha: 0.5), fontSize: 16),
              ),
            ),
          ),
        ),
      );
    }

    final (bg, textColor) = slot;
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: cardH,
        decoration: BoxDecoration(
          border: Border.all(
            color: _pressed
                ? kMint.withValues(alpha: 0.6)
                : kBorder.withValues(alpha: 0.4),
            width: _pressed ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            // Top half — bg color
            Expanded(child: Container(color: bg)),
            // Bottom half — bg color + "Aa" in text color
            Expanded(
              child: Container(
                color: bg,
                alignment: Alignment.center,
                child: Text(
                  'Aa',
                  style: mono(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// v3 Preset grid (logroomUi only)
// ──────────────────────────────────────────────────────────────────

typedef _PresetTriplet = (Color bg, Color text, Color accent);

const List<(String, _PresetTriplet)> _v3Presets = [
  ('Default',  (Color(0xFF0C0B09), Color(0xFFEDE8DF), Color(0xFFB8882A))),
  ('Slate',    (Color(0xFF0D0F12), Color(0xFFE0E6F0), Color(0xFF6891C8))),
  ('Forest',   (Color(0xFF0A0E0B), Color(0xFFD8EAD8), Color(0xFF5A9E5A))),
  ('Dusk',     (Color(0xFF120D12), Color(0xFFEDD8F0), Color(0xFFA06AB0))),
  ('Sepia',    (Color(0xFFF5F0E8), Color(0xFF3C3020), Color(0xFF8A6030))),
  ('Paper',    (Color(0xFFFAFAFA), Color(0xFF2A2A2A), Color(0xFF4A80C8))),
  ('Ash',      (Color(0xFF0F0F0F), Color(0xFFD8D8D8), Color(0xFF888888))),
  ('Ember',    (Color(0xFF110A05), Color(0xFFF0DCC8), Color(0xFFC85818))),
];

class _V3PresetGrid extends StatelessWidget {
  final void Function(Color bg, Color text, Color accent) onSelect;
  const _V3PresetGrid({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _v3Presets.map((entry) {
        final (name, (bg, text, accent)) = entry;
        return _V3PresetChip(
          name: name,
          bg: bg,
          text: text,
          accent: accent,
          onTap: () => onSelect(bg, text, accent),
        );
      }).toList(),
    );
  }
}

class _V3PresetChip extends StatefulWidget {
  final String name;
  final Color bg, text, accent;
  final VoidCallback onTap;
  const _V3PresetChip({
    required this.name,
    required this.bg,
    required this.text,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_V3PresetChip> createState() => _V3PresetChipState();
}

class _V3PresetChipState extends State<_V3PresetChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 72,
        height: 52,
        decoration: BoxDecoration(
          color: widget.bg,
          border: Border.all(
            color: _pressed
                ? widget.accent.withValues(alpha: 0.9)
                : widget.accent.withValues(alpha: 0.45),
            width: _pressed ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  widget.name,
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 9,
                    color: widget.text.withValues(alpha: 0.9),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            Container(
              height: 5,
              color: widget.accent.withValues(alpha: 0.75),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Accent color section (logroomUi only)
// ──────────────────────────────────────────────────────────────────

class _AccentSection extends StatelessWidget {
  final Color accent;
  final TextEditingController hexCtrl;
  final ValueChanged<Color> onAccentChanged;
  final ValueChanged<String> onHexInput;
  final int rVal, gVal, bVal;
  final ValueChanged<int> onRChanged, onGChanged, onBChanged;

  const _AccentSection({
    required this.accent,
    required this.hexCtrl,
    required this.onAccentChanged,
    required this.onHexInput,
    required this.rVal,
    required this.gVal,
    required this.bVal,
    required this.onRChanged,
    required this.onGChanged,
    required this.onBChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _RgbColorSection(
      label: '강조색 (accent)',
      color: accent,
      hexCtrl: hexCtrl,
      onColorChanged: onAccentChanged,
      onHexInput: onHexInput,
      rVal: rVal,
      gVal: gVal,
      bVal: bVal,
      onRChanged: onRChanged,
      onGChanged: onGChanged,
      onBChanged: onBChanged,
    );
  }
}

class _DashBorderPainter extends CustomPainter {
  final Color color;
  const _DashBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dash = 4.0;
    const gap = 4.0;

    void drawDashed(Offset start, Offset end) {
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final len = dx.abs() + dy.abs();
      if (len == 0) return;
      final ux = dx / len;
      final uy = dy / len;
      double pos = 0;
      while (pos < len) {
        final p1 = Offset(start.dx + ux * pos, start.dy + uy * pos);
        final endPos = (pos + dash).clamp(0.0, len);
        final p2 = Offset(start.dx + ux * endPos, start.dy + uy * endPos);
        canvas.drawLine(p1, p2, paint);
        pos += dash + gap;
      }
    }

    drawDashed(Offset.zero, Offset(size.width, 0));
    drawDashed(Offset(size.width, 0), Offset(size.width, size.height));
    drawDashed(Offset(size.width, size.height), Offset(0, size.height));
    drawDashed(Offset(0, size.height), Offset.zero);
  }

  @override
  bool shouldRepaint(_DashBorderPainter old) => old.color != color;
}

// ──────────────────────────────────────────────────────────────────
// Save palette button
// ──────────────────────────────────────────────────────────────────

class _SavePaletteBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _SavePaletteBtn({required this.onTap});

  @override
  State<_SavePaletteBtn> createState() => _SavePaletteBtnState();
}

class _SavePaletteBtnState extends State<_SavePaletteBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 9),
          color: _hovered ? kMint.withValues(alpha: 0.08) : Colors.transparent,
          child: Text(
            '+ 현재 색조합 저장',
            style: mono(color: _hovered ? kMint : kDim, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Confirm dialog
// ──────────────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final Color? confirmColor;
  final String? confirmLabel;

  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.onCancel,
    required this.onConfirm,
    this.confirmColor,
    this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: mono(color: kMint, fontSize: 13, letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            Text(
              '. ' * 100,
              style: mono(color: kBorder.withValues(alpha: 0.8), fontSize: 8),
              overflow: TextOverflow.clip,
              maxLines: 1,
              softWrap: false,
            ),
            const SizedBox(height: 14),
            Text(body, style: mono(color: kDim, fontSize: 12, height: 1.7)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _Btn(label: '취소', color: kDim, onTap: onCancel),
                const SizedBox(width: 10),
                _Btn(
                  label: confirmLabel ?? '확인',
                  color: confirmColor ?? kMint,
                  onTap: onConfirm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
