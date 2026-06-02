// 앱 진입점
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'flavor.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Flutter가 status bar / navigation bar 뒤까지 그리도록 설정
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await initFlavor();
  final colors = await StorageService.loadColors();
  if (colors != null) applyColors(colors.$1, colors.$2);
  final font = await StorageService.loadFont();
  if (font != null) applyFont(font.$1, font.$2);
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
