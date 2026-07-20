import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/theme.dart';
import 'data/db.dart';
import 'data/repos/node_repository.dart';
import 'features/widgetkit/notification_service.dart';
import 'features/widgetkit/widget_bridge.dart';
import 'providers.dart';

/// 홈위젯 체크 버튼 background 콜백 (top-level 필수).
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  if (uri.host == 'complete') {
    final id = uri.queryParameters['id'];
    if (id == null || id.isEmpty) return;
    final db = AppDatabase();
    final repo = NodeRepository(db);
    await repo.complete(id);
    final focus = await repo.selectFocus();
    await WidgetBridge.updateFocus(focus);
    await db.close();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');

  if (!kIsWeb) {
    await NotificationService.instance.init();
    await WidgetBridge.registerBackgroundCallback(widgetBackgroundCallback);
  }

  runApp(const ProviderScope(child: GoalApp()));
}

class GoalApp extends ConsumerStatefulWidget {
  const GoalApp({super.key});

  @override
  ConsumerState<GoalApp> createState() => _GoalAppState();
}

class _GoalAppState extends ConsumerState<GoalApp> {
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    // resume 시점에도 날짜 비교 후 이월/승격 실행 (오후 첫 오픈 누락 방지).
    _lifecycle = AppLifecycleListener(
      onResume: () => _runDailyRoutine(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  /// 앱 오픈 시점(콜드 스타트 + resume)의 하루 1회 루틴.
  /// 이월 → 승격 순서. 둘 다 lastDate != today 로 가드되어 idempotent.
  Future<void> _runDailyRoutine() async {
    final repo = ref.read(nodeRepoProvider);
    await repo.runCarryOver(); // 규칙 2 (조용히)
    await repo.promoteQ2(); // 규칙 5 — 날짜 비교 기반, 언제 열어도 하루 1회 보장

    // 포커스/승리 재계산 후 위젯·상주 알림 동기화.
    ref.invalidate(focusProvider);
    final focus = await repo.selectFocus();
    await WidgetBridge.updateFocus(focus);
    if (!kIsWeb) {
      await NotificationService.instance.showOngoingFocus(focus?.title);
    }
  }

  /// 콜드 스타트: 하루 루틴 + 알림 권한/브리핑 예약 (1회성).
  Future<void> _startup() async {
    await _runDailyRoutine();
    if (!kIsWeb) {
      await NotificationService.instance.requestPermission();
      final q2 = await ref.read(nodeRepoProvider).selectFocus();
      await NotificationService.instance.scheduleMorning(q2?.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '지금',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}
