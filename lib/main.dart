// 앱 진입점
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'flavor.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/widget_service.dart';
import 'services/local_api_service.dart';
import 'utils/logroom_entries.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Flutter가 status bar / navigation bar 뒤까지 그리도록 설정
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await initFlavor();
  // Colors first, then theme mode — so DOS/preset overrides saved colors correctly
  final colors = await StorageService.loadColors();
  if (isLogroomUi) {
    // Warm Paper is the default look; saved custom colors still win.
    if (colors != null) {
      applyColorsAuto(colors.$1, colors.$2);
    } else {
      applyPaperDefaults();
    }
  } else if (colors != null) {
    applyColors(colors.$1, colors.$2);
  }
  // Theme mode after — DOS/preset overrides saved colors when active
  applyAppThemeMode(await StorageService.loadAppThemeMode());
  final font = await StorageService.loadFont();
  if (font != null) applyFont(font.$1, font.$2);
  final spacing = await StorageService.loadSpacing();
  if (spacing != null) applySpacing(spacing);
  applyEntryDisplayMode(await StorageService.loadEntryDisplayMode());
  await NotificationService.init();
  await WidgetService.init();
  if (isNemo2Test) {
    LocalApiService.start().ignore();
    NotificationService.scheduleWeeklyBrief().ignore();
  }
  // Sync system UI overlay with current theme (also synced on every applyColors call)
  syncSystemUiOverlay();
  runApp(const MemoApp());
}

class MemoApp extends StatelessWidget {
  const MemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) => MaterialApp(
        title: 'MEMO',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
