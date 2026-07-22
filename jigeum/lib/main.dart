import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/almanac.dart';
import 'core/constants.dart';
import 'core/journal.dart';
import 'core/settings_controller.dart';
import 'core/theme.dart';
import 'data/db.dart';
import 'data/repos/time_track_repository.dart';
import 'features/widgetkit/notification_service.dart';
import 'features/widgetkit/widget_bridge.dart';
import 'providers.dart';

/// 진단용: 릴리즈에서도 크래시 대신 에러 메시지를 화면에 표시.
final ValueNotifier<String?> gError = ValueNotifier<String?>(null);

/// Color → "#RRGGBB" (위젯 테마 전달용).
String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 프레임워크 에러 → 화면에 표시 (진단용).
    FlutterError.onError = (details) {
      gError.value = '${details.exceptionAsString()}\n\n${details.stack}';
      FlutterError.presentError(details);
    };
    ErrorWidget.builder =
        (details) => _ErrorScreen(message: details.exceptionAsString());

    try {
      await initializeDateFormatting('ko');
    } catch (e, s) {
      debugPrint('initializeDateFormatting 실패: $e\n$s');
    }

    runApp(const ProviderScope(child: GoalApp()));
  }, (error, stack) {
    // 잡히지 않은 비동기 에러 → 화면에 표시.
    gError.value = '$error\n\n$stack';
    debugPrint('zone error: $error\n$stack');
  });
}

/// 크래시 대신 보여줄 에러 화면.
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFF111417),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('시작 중 오류',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              SelectableText(
                message,
                style: const TextStyle(
                    color: Color(0xFFFFB0B0), fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GoalApp extends ConsumerStatefulWidget {
  const GoalApp({super.key});

  @override
  ConsumerState<GoalApp> createState() => _GoalAppState();
}

class _GoalAppState extends ConsumerState<GoalApp> {
  AppLifecycleListener? _lifecycle;
  StreamSubscription<dynamic>? _nodesSub;
  Timer? _syncDebounce;

  @override
  void initState() {
    super.initState();
    // resume 시점에도 날짜 비교 후 이월/승격 + 위젯 진입 액션 확인.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _runDailyRoutine();
        _checkLaunchAction();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    _nodesSub?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  /// 위젯 탭으로 열렸는지 확인 → 퀵캡처/타임트래커 입력 트리거.
  Future<void> _checkLaunchAction() async {
    final action = await WidgetBridge.consumeLaunchAction();
    if (action == 'quick_capture') {
      quickCaptureFocusRequest.value++;
    } else if (action == 'time_track') {
      timeTrackLaunchRequest.value++;
    } else if (action == 'open_calendar') {
      calendarLaunchRequest.value++;
    }
  }

  /// 홈/잠금 위젯 데이터 동기화 (포커스 + 매트릭스 + 서랍 개수).
  Future<void> _syncWidgets() async {
    try {
      final repo = ref.read(nodeRepoProvider);
      final focus = await repo.selectFocus();
      String join(List<Node> ns) => ns.map((n) => '· ${n.title}').join('\n');
      final q1 = await repo.quadrantTop(important: true, urgent: true);
      final q2 = await repo.quadrantTop(important: true, urgent: false);
      final q3 = await repo.quadrantTop(important: false, urgent: true);
      final q4 = await repo.drawerCount();
      // 현재 테마 6토큰을 위젯에 전달 (앱과 톤 일치).
      final settings = ref.read(settingsProvider);
      final tk = tokensForKey(settings.themeKey);
      // 캘린더 위젯 하단: 음력은 항상, 일진(사주)·별자리(점성학)는 설정 토글.
      final today = todayDate();
      final calFoot = <String>[
        lunarLabel(today),
        if (settings.calSaju) iljinLabel(today),
        if (settings.calAstro) byeoljariLabel(today),
      ].join(' · ');
      await WidgetBridge.updateWidgets(
        focusTitle: focus?.title ?? '오늘 할 일을 정해볼까요',
        q1: join(q1),
        q2: join(q2),
        q3: join(q3),
        q4Count: q4,
        calFoot: calFoot,
        theme: {
          'paper': _hex(tk.paper),
          'ink': _hex(tk.ink),
          'inkSoft': _hex(tk.inkSoft),
          'line': _hex(tk.line),
          'mark': _hex(tk.mark),
        },
      );
      if (!kIsWeb) {
        await NotificationService.instance.showOngoingFocus(focus?.title);
      }

      // 타임트래커 위젯: 지금 블록 라벨 + 현재 기록.
      final ttRepo = ref.read(timeTrackRepoProvider);
      final nowBlock = TimeTrackRepository.blockOfNow();
      final cur = await ttRepo.getBlock(todayDate(), nowBlock);
      await WidgetBridge.updateTimeTrack(
        '지금 ${blockLabel(nowBlock)}',
        cur?.content ?? '탭해서 기록',
      );
    } catch (e, s) {
      debugPrint('widget sync 실패(무시): $e\n$s');
    }
  }

  /// 앱 오픈 시점(콜드 스타트 + resume)의 하루 1회 루틴.
  /// 이월 → 승격 순서. 둘 다 lastDate != today 로 가드되어 idempotent.
  /// 어떤 단계가 실패해도 앱이 죽지 않도록 전체를 try/catch 로 감쌈.
  Future<void> _runDailyRoutine() async {
    try {
      final repo = ref.read(nodeRepoProvider);
      await repo.runCarryOver(); // 규칙 2 (조용히)
      await repo.promoteQ2(); // 규칙 5 — 날짜 비교 기반, 언제 열어도 하루 1회 보장
      await ref.read(scheduleRepoProvider).generateTodayRoutines(); // 루틴→오늘 일정
      ref.invalidate(focusProvider);
      await _syncWidgets();

      // 즉시 보상 배선: 저녁 "오늘의 승리 N개" 예약 (N=0이면 발송 안 함).
      if (!kIsWeb) {
        final wins = await repo.winsCountForDate(todayDate());
        await NotificationService.instance.scheduleEvening(wins);
      }
    } catch (e, s) {
      debugPrint('daily routine 실패(무시): $e\n$s');
    }
  }

  /// 콜드 스타트: 네이티브 초기화 → 하루 루틴 → 권한/브리핑 예약.
  /// 각 단계 독립 try/catch — 플러그인 하나가 실패해도 나머지·UI 는 정상.
  Future<void> _startup() async {
    if (!kIsWeb) {
      try {
        await NotificationService.instance.init();
      } catch (e, s) {
        debugPrint('알림 init 실패(무시): $e\n$s');
      }
    }

    await _runDailyRoutine();
    await _checkLaunchAction();

    // 노드가 바뀔 때마다 위젯도 갱신 (0.5초 디바운스).
    _nodesSub = ref.read(nodeRepoProvider).watchAll().listen((_) {
      _syncDebounce?.cancel();
      _syncDebounce = Timer(const Duration(milliseconds: 500), _syncWidgets);
    });

    if (!kIsWeb) {
      try {
        await NotificationService.instance.requestPermission();
        final q2 = await ref.read(nodeRepoProvider).selectFocus();
        await NotificationService.instance.scheduleMorning(q2?.title);
      } catch (e, s) {
        debugPrint('알림 권한/예약 실패(무시): $e\n$s');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    // 테마가 바뀌면 위젯도 즉시 새 톤으로 갱신.
    ref.listen(settingsProvider.select((s) => s.themeKey), (_, __) {
      _syncWidgets();
    });
    final themeData = AppTheme.fromKey(settings.themeKey,
        weightDelta: settings.weightDelta, systemFont: settings.systemFont);
    return MaterialApp(
      title: '지금',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      darkTheme: themeData,
      themeMode: ThemeMode.light,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          // 폰트 크기: 시스템 배율에 앱 설정 배율을 곱함.
          data: mq.copyWith(
            textScaler: TextScaler.linear(settings.fontScale),
          ),
          child: ValueListenableBuilder<String?>(
            valueListenable: gError,
            builder: (context, err, _) {
              if (err != null) return _ErrorScreen(message: err);
              return child ?? const SizedBox.shrink();
            },
          ),
        );
      },
      home: const AppShell(),
    );
  }
}
