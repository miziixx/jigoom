// 앱 진입점
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'flavor.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/widget_service.dart';
import 'utils/logroom_entries.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Flutter가 status bar / navigation bar 뒤까지 그리도록 설정
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await initFlavor();
  // Theme mode first — so saved colors applied after can override DOS/Minimal defaults
  applyAppThemeMode(await StorageService.loadAppThemeMode());
  final colors = await StorageService.loadColors();
  final savedAccent = await StorageService.loadAccent();
  if (isLogroomUi) {
    final bg = colors?.$1 ?? const Color(0xFF0C0B09);
    final text = colors?.$2 ?? const Color(0xFFEDE8DF);
    final ac = savedAccent ?? const Color(0xFFB8882A);
    applyColorsV3(bg, text, ac);
  } else if (colors != null) {
    applyColors(colors.$1, colors.$2);
  }
  final font = await StorageService.loadFont();
  if (font != null) applyFont(font.$1, font.$2);
  final spacing = await StorageService.loadSpacing();
  if (spacing != null) applySpacing(spacing);
  applyEntryDisplayMode(await StorageService.loadEntryDisplayMode());
  await NotificationService.init();
  await WidgetService.init();
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
