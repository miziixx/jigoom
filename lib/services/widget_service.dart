import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/memo.dart';
import '../models/folder.dart';

class WidgetService {
  static const _androidProvider = 'com.example.memo_app.MemoWidgetProvider';
  static const _listProvider = 'com.example.memo_app.MemoListWidgetProvider';
  static const _calendarProvider =
      'com.example.memo_app.CalendarWidgetProvider';

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.setAppGroupId('com.example.memo_app');
    } catch (_) {}
  }

  /// Notify list & calendar widgets to refresh their data.
  static Future<void> notifyDataChanged() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.updateWidget(qualifiedAndroidName: _listProvider);
      await HomeWidget.updateWidget(qualifiedAndroidName: _calendarProvider);
    } catch (_) {}
  }

  /// Push current theme colors to widget SharedPreferences and refresh.
  static Future<void> syncColors({
    required int bg,
    required int text,
    required int dim,
    required int border,
    required int teal,
    required int mint,
  }) async {
    if (kIsWeb) return;
    try {
      await HomeWidget.saveWidgetData<int>('widget_bg', bg);
      await HomeWidget.saveWidgetData<int>('widget_text', text);
      await HomeWidget.saveWidgetData<int>('widget_dim', dim);
      await HomeWidget.saveWidgetData<int>('widget_border', border);
      await HomeWidget.saveWidgetData<int>('widget_teal', teal);
      await HomeWidget.saveWidgetData<int>('widget_mint', mint);
      await HomeWidget.updateWidget(qualifiedAndroidName: _androidProvider);
      await HomeWidget.updateWidget(qualifiedAndroidName: _listProvider);
      await HomeWidget.updateWidget(qualifiedAndroidName: _calendarProvider);
    } catch (_) {}
  }

  /// Push folder list to widget SharedPreferences so MemoInputActivity can show folder picker.
  static Future<void> syncFolders(List<Folder> folders) async {
    if (kIsWeb) return;
    try {
      final json = jsonEncode(
        folders.map((f) => {'id': f.id, 'name': f.name}).toList(),
      );
      await HomeWidget.saveWidgetData<String>('widget_folders', json);
    } catch (_) {}
  }

  /// Read memos saved from the home-screen widget Activity.
  /// Returns new Memo objects. Clears the pending queue on success.
  static Future<List<Memo>> collectPending() async {
    if (kIsWeb) return [];
    try {
      final raw = await HomeWidget.getWidgetData<String>('pending_memos');
      if (raw == null || raw == '[]' || raw.isEmpty) return [];

      final arr = jsonDecode(raw) as List<dynamic>;
      final memos = <Memo>[];

      for (final item in arr) {
        final data = item as Map<String, dynamic>;
        final content = (data['content'] as String?)?.trim() ?? '';
        if (content.isEmpty) continue;

        final isChecklist = data['isChecklist'] as bool? ?? false;
        final reminderMs = data['reminderAt'] as int?;
        final createdMs = data['createdAt'] as int?;
        final createdIso = data['createdAtIso'] as String?;

        DateTime createdAt;
        if (createdIso != null && createdIso.isNotEmpty) {
          createdAt = DateTime.tryParse(createdIso) ?? DateTime.now();
        } else if (createdMs != null) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(createdMs);
        } else {
          createdAt = DateTime.now();
        }

        final folderId = data['folderId'] as String?;

        memos.add(
          Memo(
            id: (createdMs ?? DateTime.now().millisecondsSinceEpoch).toString(),
            content: content,
            createdAt: createdAt,
            isChecklist: isChecklist,
            folderId: folderId,
            reminderAt: reminderMs != null
                ? DateTime.fromMillisecondsSinceEpoch(reminderMs)
                : null,
          ),
        );
      }

      // Clear queue
      await HomeWidget.saveWidgetData<String>('pending_memos', '[]');
      return memos;
    } catch (_) {
      return [];
    }
  }
}
