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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
  }

  /// 앱 시작 시: 자동 이월 → Q2 승격 → 포커스/알림/위젯 동기화.
  Future<void> _startup() async {
    final repo = ref.read(nodeRepoProvider);
    await repo.runCarryOver(); // 규칙 2 (조용히)
    await repo.promoteQ2(); // 규칙 5

    // 포커스/승리 재계산 후 위젯·알림 동기화.
    final _ = ref.refresh(focusProvider);
    final focus = await repo.selectFocus();
    await WidgetBridge.updateFocus(focus);

    if (!kIsWeb) {
      await NotificationService.instance.requestPermission();
      await NotificationService.instance.showOngoingFocus(focus?.title);
      // 아침/저녁 브리핑 예약.
      final q2 = await repo.selectFocus(); // Q2 우선 포함
      await NotificationService.instance.scheduleMorning(q2?.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '목표달성',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}
