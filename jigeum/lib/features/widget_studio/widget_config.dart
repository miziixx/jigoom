import 'studio_tokens.dart';

/// ============================================================
/// WIDGET STUDIO — 저장 데이터 모델 (§15)
/// 위젯별 배치·크기·표면·투명도·개별 테마 등을 담고 JSON 으로 영속화한다.
/// 앱 재시작·프로세스 종료·위젯 업데이트 후에도 배치와 타이머가 유지되도록,
/// 이 모델을 그대로 직렬화해 저장한다.
/// ============================================================

enum StudioCalView { day, week, month }

/// 위젯 하나의 설정.
class WidgetConfig {
  const WidgetConfig({
    required this.id,
    required this.type,
    required this.title,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zIndex,
    this.view,
    this.theme = 'global',
    this.surface = StudioSurface.glass,
    this.backgroundOpacity = 92, // %  (레퍼런스 --widget-bg-alpha .92)
    this.opacity = 100, // %
    this.fontScale = 100, // %
    this.radius = StudioFrame.radius, // 14
    this.lineWidth = StudioFrame.lineWidth, // 0.7
    this.lineColor,
    this.accentColor,
  });

  final String id;
  final StudioWidgetType type;
  final String title;

  final double x, y, width, height;
  final int zIndex;

  final StudioCalView? view; // 캘린더 전용

  /// 'global' 또는 StudioTheme.key.
  final String theme;
  final StudioSurface surface;

  final double backgroundOpacity; // 0~100
  final double opacity; // 20~100
  final double fontScale; // 75~135
  final double radius; // 0~30
  final double lineWidth; // 0~3

  final int? lineColor; // ARGB, null = 테마 line
  final int? accentColor; // ARGB, null = 테마 primary

  WidgetConfig copyWith({
    String? title,
    double? x,
    double? y,
    double? width,
    double? height,
    int? zIndex,
    Object? view = _noArg,
    String? theme,
    StudioSurface? surface,
    double? backgroundOpacity,
    double? opacity,
    double? fontScale,
    double? radius,
    double? lineWidth,
    Object? lineColor = _noArg,
    Object? accentColor = _noArg,
  }) =>
      WidgetConfig(
        id: id,
        type: type,
        title: title ?? this.title,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        zIndex: zIndex ?? this.zIndex,
        view: identical(view, _noArg) ? this.view : view as StudioCalView?,
        theme: theme ?? this.theme,
        surface: surface ?? this.surface,
        backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
        opacity: opacity ?? this.opacity,
        fontScale: fontScale ?? this.fontScale,
        radius: radius ?? this.radius,
        lineWidth: lineWidth ?? this.lineWidth,
        lineColor:
            identical(lineColor, _noArg) ? this.lineColor : lineColor as int?,
        accentColor: identical(accentColor, _noArg)
            ? this.accentColor
            : accentColor as int?,
      );

  static const _noArg = Object();

  /// 새 위젯 — 기본 크기·기본값으로 생성.
  factory WidgetConfig.create({
    required String id,
    required StudioWidgetType type,
    required double x,
    required double y,
    required int zIndex,
  }) {
    final s = kDefaultWidgetSizes[type]!;
    return WidgetConfig(
      id: id,
      type: type,
      title: type.label,
      x: x,
      y: y,
      width: s.width,
      height: s.height,
      zIndex: zIndex,
      view: type == StudioWidgetType.calendar ? StudioCalView.month : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'zIndex': zIndex,
        if (view != null) 'view': view!.name,
        'theme': theme,
        'surface': surface.name,
        'backgroundOpacity': backgroundOpacity,
        'opacity': opacity,
        'fontScale': fontScale,
        'radius': radius,
        'lineWidth': lineWidth,
        if (lineColor != null) 'lineColor': lineColor,
        if (accentColor != null) 'accentColor': accentColor,
      };

  factory WidgetConfig.fromJson(Map<String, dynamic> j) => WidgetConfig(
        id: j['id'] as String,
        type: StudioWidgetType.values.byName(j['type'] as String),
        title: j['title'] as String? ?? '',
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        width: (j['width'] as num).toDouble(),
        height: (j['height'] as num).toDouble(),
        zIndex: (j['zIndex'] as num?)?.toInt() ?? 0,
        view: j['view'] == null
            ? null
            : StudioCalView.values.byName(j['view'] as String),
        theme: j['theme'] as String? ?? 'global',
        surface: j['surface'] == null
            ? StudioSurface.glass
            : StudioSurface.values.byName(j['surface'] as String),
        backgroundOpacity: (j['backgroundOpacity'] as num?)?.toDouble() ?? 92,
        opacity: (j['opacity'] as num?)?.toDouble() ?? 100,
        fontScale: (j['fontScale'] as num?)?.toDouble() ?? 100,
        radius: (j['radius'] as num?)?.toDouble() ?? StudioFrame.radius,
        lineWidth: (j['lineWidth'] as num?)?.toDouble() ?? StudioFrame.lineWidth,
        lineColor: (j['lineColor'] as num?)?.toInt(),
        accentColor: (j['accentColor'] as num?)?.toInt(),
      );

  /// 현재 크기 기준 반응형 상태.
  StudioSizeState get sizeState => studioStateFor(width, height);
}

/// 타임트래커 위젯 상태 (§15). 시작 시각을 영속 저장하고 현재 시각과의 차이로
/// 실시간 경과를 계산 → 재렌더/재시작에도 타이머가 초기화되지 않는다.
class TrackerState {
  const TrackerState({
    this.draft = '',
    this.running = false,
    this.startedAt,
    this.records = const [],
  });

  final String draft;
  final bool running;
  final int? startedAt; // epoch ms
  final List<TimeRecord> records;

  TrackerState copyWith({
    String? draft,
    bool? running,
    Object? startedAt = _noArg,
    List<TimeRecord>? records,
  }) =>
      TrackerState(
        draft: draft ?? this.draft,
        running: running ?? this.running,
        startedAt:
            identical(startedAt, _noArg) ? this.startedAt : startedAt as int?,
        records: records ?? this.records,
      );

  static const _noArg = Object();

  Map<String, dynamic> toJson() => {
        'draft': draft,
        'running': running,
        'startedAt': startedAt,
        'records': records.map((r) => r.toJson()).toList(),
      };

  factory TrackerState.fromJson(Map<String, dynamic> j) => TrackerState(
        draft: j['draft'] as String? ?? '',
        running: j['running'] as bool? ?? false,
        startedAt: (j['startedAt'] as num?)?.toInt(),
        records: ((j['records'] as List?) ?? const [])
            .map((e) => TimeRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 한 건의 시간 기록 — 첫 줄=제목, 나머지=작업 항목(여러 줄).
class TimeRecord {
  const TimeRecord({
    required this.startedAt,
    required this.endedAt,
    required this.title,
    required this.work,
    this.writtenAt,
  });

  final int startedAt; // epoch ms
  final int endedAt; // epoch ms
  final String title;
  final List<String> work; // '—' 불릿으로 표시될 작업 줄
  final int? writtenAt; // 작성 시각(기본 endedAt)

  int get durationMin => ((endedAt - startedAt) / 60000).round();

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt,
        'endedAt': endedAt,
        'title': title,
        'work': work,
        'writtenAt': writtenAt,
      };

  factory TimeRecord.fromJson(Map<String, dynamic> j) => TimeRecord(
        startedAt: (j['startedAt'] as num).toInt(),
        endedAt: (j['endedAt'] as num).toInt(),
        title: j['title'] as String? ?? '',
        work: ((j['work'] as List?) ?? const []).map((e) => '$e').toList(),
        writtenAt: (j['writtenAt'] as num?)?.toInt(),
      );

  /// 여러 줄 입력 → 제목+작업 분리.
  static ({String title, List<String> work}) parse(String draft) {
    final lines = draft
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return (title: '기록', work: const []);
    return (title: lines.first, work: lines.skip(1).toList());
  }
}

/// 스튜디오 전체 저장 상태 — 위젯 배치 + 전역 테마 + 캔버스 크기.
class StudioState {
  const StudioState({
    this.widgets = const [],
    this.globalTheme = 'sage',
    this.largeCanvas = false,
  });

  final List<WidgetConfig> widgets;
  final String globalTheme; // StudioTheme.key
  final bool largeCanvas; // false=390×844, true=430×932

  StudioState copyWith({
    List<WidgetConfig>? widgets,
    String? globalTheme,
    bool? largeCanvas,
  }) =>
      StudioState(
        widgets: widgets ?? this.widgets,
        globalTheme: globalTheme ?? this.globalTheme,
        largeCanvas: largeCanvas ?? this.largeCanvas,
      );

  Map<String, dynamic> toJson() => {
        'widgets': widgets.map((w) => w.toJson()).toList(),
        'globalTheme': globalTheme,
        'largeCanvas': largeCanvas,
      };

  factory StudioState.fromJson(Map<String, dynamic> j) => StudioState(
        widgets: ((j['widgets'] as List?) ?? const [])
            .map((e) => WidgetConfig.fromJson(e as Map<String, dynamic>))
            .toList(),
        globalTheme: j['globalTheme'] as String? ?? 'sage',
        largeCanvas: j['largeCanvas'] as bool? ?? false,
      );
}
