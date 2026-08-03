import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../providers.dart';
import 'studio_tokens.dart';
import 'widget_config.dart';

/// ============================================================
/// WIDGET STUDIO — 편집 세션 상태 + 컨트롤러 (§15 영속화)
///
/// 레퍼런스 스크립트의 `state` 와 mutation 함수들을 Riverpod StateNotifier 로
/// 옮긴 것. 위젯 배치·전역 테마·캔버스 크기·그리드·줌·선택·타임트래커 상태를
/// 하나의 불변 세션으로 들고, 모든 변경 뒤 drift `Settings` kv 에 JSON 으로
/// write-through 한다. 앱 재시작·프로세스 종료 후에도 배치와 타이머(시작 시각)가
/// 그대로 복원된다.
/// ============================================================

const String _kStudioKey = 'jigeum-widget-studio-v2';

/// 편집 세션(불변). widgets/전역설정 + UI 상태(selected/zoom/grid) +
/// 타임트래커 상태(위젯 id → TrackerState).
@immutable
class StudioSession {
  const StudioSession({
    this.studio = const StudioState(),
    this.trackers = const {},
    this.selectedId,
    this.zoom = 1.0,
    this.grid = true,
    this.nextZ = 10,
  });

  final StudioState studio;
  final Map<String, TrackerState> trackers;
  final String? selectedId;
  final double zoom;
  final bool grid;
  final int nextZ;

  List<WidgetConfig> get widgets => studio.widgets;
  Size get canvas => studio.largeCanvas ? StudioCanvas.large : StudioCanvas.base;

  WidgetConfig? get selected {
    if (selectedId == null) return null;
    for (final w in studio.widgets) {
      if (w.id == selectedId) return w;
    }
    return null;
  }

  TrackerState trackerFor(String id) => trackers[id] ?? const TrackerState();

  StudioSession copyWith({
    StudioState? studio,
    Map<String, TrackerState>? trackers,
    Object? selectedId = _noArg,
    double? zoom,
    bool? grid,
    int? nextZ,
  }) =>
      StudioSession(
        studio: studio ?? this.studio,
        trackers: trackers ?? this.trackers,
        selectedId:
            identical(selectedId, _noArg) ? this.selectedId : selectedId as String?,
        zoom: zoom ?? this.zoom,
        grid: grid ?? this.grid,
        nextZ: nextZ ?? this.nextZ,
      );

  static const _noArg = Object();

  Map<String, dynamic> toJson() => {
        'studio': studio.toJson(),
        'grid': grid,
        'nextZ': nextZ,
        'trackers':
            trackers.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory StudioSession.fromJson(Map<String, dynamic> j) {
    final studio = StudioState.fromJson(
        (j['studio'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{});
    final trackers = <String, TrackerState>{};
    final tj = (j['trackers'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    tj.forEach((k, v) {
      trackers[k] = TrackerState.fromJson((v as Map).cast<String, dynamic>());
    });
    final maxZ = studio.widgets.fold<int>(
        10, (m, w) => w.zIndex > m ? w.zIndex : m);
    return StudioSession(
      studio: studio,
      trackers: trackers,
      grid: j['grid'] as bool? ?? true,
      nextZ: (j['nextZ'] as num?)?.toInt() ?? maxZ + 1,
    );
  }
}

/// 최초 실행 배치 (레퍼런스 initialWidgets). 좌표·크기 그대로.
List<WidgetConfig> _initialWidgets() {
  int z = 10;
  WidgetConfig make(StudioWidgetType type, double x, double y, double w, double h,
      {StudioCalView? view}) {
    return WidgetConfig(
      id: _uid(),
      type: type,
      title: type.label,
      x: x,
      y: y,
      width: w,
      height: h,
      zIndex: ++z,
      view: view,
    );
  }

  return [
    make(StudioWidgetType.calendar, 18, 18, 354, 230, view: StudioCalView.month),
    make(StudioWidgetType.goal, 18, 262, 354, 100),
    make(StudioWidgetType.tracker, 18, 376, 354, 224),
    make(StudioWidgetType.tasks, 18, 614, 224, 210),
    make(StudioWidgetType.capture, 256, 614, 116, 88),
    make(StudioWidgetType.habits, 256, 716, 116, 108),
  ];
}

String _uid() =>
    'w${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_seq++).toRadixString(36)}';
int _seq = 0;

double _clamp(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

/// 스튜디오 컨트롤러 — 모든 편집 mutation + kv 영속화.
class StudioController extends StateNotifier<StudioSession> {
  StudioController(this._db) : super(const StudioSession()) {
    _load();
  }

  final AppDatabase _db;
  bool _loaded = false;

  Future<void> _load() async {
    try {
      final row = await (_db.select(_db.settings)
            ..where((s) => s.key.equals(_kStudioKey)))
          .getSingleOrNull();
      if (row == null) {
        state = StudioSession(
          studio: StudioState(widgets: _initialWidgets()),
          nextZ: 20,
        );
      } else {
        state = StudioSession.fromJson(
            jsonDecode(row.value) as Map<String, dynamic>);
      }
    } catch (_) {
      state = StudioSession(
          studio: StudioState(widgets: _initialWidgets()), nextZ: 20);
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    if (!_loaded) return;
    await _db.into(_db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(
            key: _kStudioKey, value: jsonEncode(state.toJson())));
  }

  // --- 위젯 목록 헬퍼 -------------------------------------------------------

  void _replaceWidget(String id, WidgetConfig Function(WidgetConfig) fn,
      {bool persist = true}) {
    final list = [
      for (final w in state.widgets) w.id == id ? fn(w) : w,
    ];
    state = state.copyWith(studio: state.studio.copyWith(widgets: list));
    if (persist) _persist();
  }

  /// 선택 위젯을 [fn] 으로 바꾼다. slider 드래그 중엔 persist=false 로.
  void mutateSelected(WidgetConfig Function(WidgetConfig) fn,
      {bool persist = true}) {
    final id = state.selectedId;
    if (id == null) return;
    _replaceWidget(id, fn, persist: persist);
  }

  // --- 선택 / 캔버스 --------------------------------------------------------

  void select(String? id) => state = state.copyWith(selectedId: id);

  void setZoom(double z) =>
      state = state.copyWith(zoom: _clamp(z, 0.65, 1.25));

  void toggleGrid() {
    state = state.copyWith(grid: !state.grid);
    _persist();
  }

  void setLargeCanvas(bool large) {
    final canvas = large ? StudioCanvas.large : StudioCanvas.base;
    // 새 캔버스 밖으로 나간 위젯을 안으로 되돌린다.
    final list = [
      for (final w in state.widgets)
        w.copyWith(
          x: _clamp(w.x, 0, canvas.width - w.width),
          y: _clamp(w.y, 0, canvas.height - w.height),
        ),
    ];
    state = state.copyWith(
        studio: state.studio.copyWith(widgets: list, largeCanvas: large));
    _persist();
  }

  // --- 배치 (드래그 / 리사이즈) --------------------------------------------

  void moveTo(String id, double x, double y) {
    final w = state.widgets.firstWhere((e) => e.id == id);
    final c = state.canvas;
    _replaceWidget(
      id,
      (e) => e.copyWith(
        x: _clamp(x, 0, c.width - w.width),
        y: _clamp(y, 0, c.height - w.height),
      ),
      persist: false,
    );
  }

  void resizeTo(String id, double width, double height) {
    final w = state.widgets.firstWhere((e) => e.id == id);
    final c = state.canvas;
    _replaceWidget(
      id,
      (e) => e.copyWith(
        width: _clamp(width, StudioFrame.minWidth, c.width - w.x),
        height: _clamp(height, StudioFrame.minHeight, c.height - w.y),
      ),
      persist: false,
    );
  }

  /// 드래그/리사이즈 종료 시 한 번 저장.
  void commit() => _persist();

  // --- 카탈로그 / 인스펙터 액션 --------------------------------------------

  void addWidget(StudioWidgetType type) {
    final c = state.canvas;
    final cascade = state.widgets.length % 8;
    final z = state.nextZ;
    var w = WidgetConfig.create(
      id: _uid(),
      type: type,
      x: 18 + cascade * 7,
      y: 18 + cascade * 10,
      zIndex: z,
    );
    w = w.copyWith(
      width: w.width > c.width - 36 ? c.width - 36 : w.width,
      height: w.height > c.height - 36 ? c.height - 36 : w.height,
    );
    state = state.copyWith(
      studio: state.studio.copyWith(widgets: [...state.widgets, w]),
      selectedId: w.id,
      nextZ: z + 1,
    );
    _persist();
  }

  void duplicateSelected() {
    final w = state.selected;
    if (w == null) return;
    final c = state.canvas;
    final z = state.nextZ;
    final copy = w.copyWith(
      x: _clamp(w.x + 18, 0, c.width - w.width),
      y: _clamp(w.y + 18, 0, c.height - w.height),
      zIndex: z,
    );
    // copyWith 는 id/type 을 유지하므로 새 id 로 재생성.
    final dup = WidgetConfig(
      id: _uid(),
      type: w.type,
      title: w.title,
      x: copy.x,
      y: copy.y,
      width: w.width,
      height: w.height,
      zIndex: z,
      view: w.view,
      theme: w.theme,
      surface: w.surface,
      backgroundOpacity: w.backgroundOpacity,
      opacity: w.opacity,
      fontScale: w.fontScale,
      radius: w.radius,
      lineWidth: w.lineWidth,
      lineColor: w.lineColor,
      accentColor: w.accentColor,
    );
    state = state.copyWith(
      studio: state.studio.copyWith(widgets: [...state.widgets, dup]),
      selectedId: dup.id,
      nextZ: z + 1,
    );
    _persist();
  }

  void deleteSelected() {
    final id = state.selectedId;
    if (id == null) return;
    state = state.copyWith(
      studio: state.studio
          .copyWith(widgets: [for (final w in state.widgets) if (w.id != id) w]),
      selectedId: null,
    );
    _persist();
  }

  void bringToFront() {
    final z = state.nextZ;
    mutateSelected((w) => w.copyWith(zIndex: z), persist: false);
    state = state.copyWith(nextZ: z + 1);
    _persist();
  }

  void centerSelected() {
    final w = state.selected;
    if (w == null) return;
    final c = state.canvas;
    mutateSelected((e) => e.copyWith(
          x: (c.width - w.width) / 2,
          y: (c.height - w.height) / 2,
        ));
  }

  void applyPreset(Size size) {
    final w = state.selected;
    if (w == null) return;
    final c = state.canvas;
    mutateSelected((e) => e.copyWith(
          width: size.width > c.width - e.x ? c.width - e.x : size.width,
          height: size.height > c.height - e.y ? c.height - e.y : size.height,
        ));
  }

  // --- 테마 ----------------------------------------------------------------

  void setGlobalTheme(String key) {
    state = state.copyWith(studio: state.studio.copyWith(globalTheme: key));
    _persist();
  }

  StudioTheme themeFor(WidgetConfig w) => StudioTheme.byKey(
      w.theme == 'global' ? state.studio.globalTheme : w.theme);

  // --- 초기화 / 저장 -------------------------------------------------------

  void resetLayout() {
    state = StudioSession(
      studio: StudioState(widgets: _initialWidgets()),
      nextZ: 20,
    );
    _persist();
  }

  Future<void> saveNow() => _persist();

  /// 설정 내보내기용 JSON 문자열.
  String exportJson() {
    final c = state.canvas;
    return const JsonEncoder.withIndent('  ').convert({
      'theme': state.studio.globalTheme,
      'canvas': {'width': c.width, 'height': c.height},
      'widgets': state.widgets.map((w) => w.toJson()).toList(),
    });
  }

  // --- 타임트래커 ----------------------------------------------------------

  void trackerDraft(String id, String draft) {
    final t = state.trackerFor(id).copyWith(draft: draft);
    state = state.copyWith(trackers: {...state.trackers, id: t});
    _persist();
  }

  /// 기록 시작 — 시작 시각을 영속 저장(재렌더/재시작에도 유지). draft 필요.
  bool trackerStart(String id) {
    final t = state.trackerFor(id);
    if (t.draft.trim().isEmpty) return false;
    final started = t.copyWith(
        running: true, startedAt: DateTime.now().millisecondsSinceEpoch);
    state = state.copyWith(trackers: {...state.trackers, id: started});
    bringToFrontOf(id);
    _persist();
    return true;
  }

  /// 기록 종료 — 시작·종료·소요 계산, 기록 저장, draft/타이머 초기화.
  void trackerStop(String id) {
    final t = state.trackerFor(id);
    if (!t.running) return;
    final end = DateTime.now().millisecondsSinceEpoch;
    final start = t.startedAt ?? end;
    final parsed = TimeRecord.parse(t.draft);
    final rec = TimeRecord(
      startedAt: start,
      endedAt: end < start + 1000 ? start + 1000 : end,
      title: parsed.title,
      work: parsed.work,
      writtenAt: end,
    );
    final next = t.copyWith(
      running: false,
      startedAt: null,
      draft: '',
      records: [...t.records, rec],
    );
    state = state.copyWith(trackers: {...state.trackers, id: next});
    _persist();
  }

  void bringToFrontOf(String id) {
    final z = state.nextZ;
    _replaceWidget(id, (w) => w.copyWith(zIndex: z), persist: false);
    state = state.copyWith(nextZ: z + 1);
  }
}

final studioControllerProvider =
    StateNotifierProvider<StudioController, StudioSession>((ref) {
  return StudioController(ref.watch(dbProvider));
});
