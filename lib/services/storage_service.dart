import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memo.dart';
import '../models/folder.dart';
import '../models/quick_tab.dart';
import 'widget_service.dart';

class StorageService {
  static const _memosKey = 'memos_v1';
  static const _foldersKey = 'folders_v1';
  static const _tabsKey      = 'tabs_v1';
  static const _bgKey        = 'color_bg';
  static const _textKey      = 'color_text';
  static const _fontFamilyKey = 'font_family';
  static const _fontSizeKey   = 'font_size';
  static const _tabLockedKey  = 'tab_locked';
  static const _firstOpenKey     = 'first_open_date';
  static const _habitActivatedKey = 'habit_activated';
  static const _goalActivatedKey  = 'goal_activated';

  // ── Memos ──────────────────────────────────────────

  static Future<void> saveMemos(List<Memo> memos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _memosKey,
      jsonEncode(memos.map((m) => m.toJson()).toList()),
    );
    if (!kIsWeb) unawaited(WidgetService.notifyDataChanged());
  }

  static Future<List<Memo>> loadMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_memosKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Memo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Folders ────────────────────────────────────────

  static Future<void> saveFolders(List<Folder> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _foldersKey,
      jsonEncode(folders.map((f) => f.toJson()).toList()),
    );
    if (!kIsWeb) unawaited(WidgetService.syncFolders(folders));
  }

  static Future<List<Folder>> loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_foldersKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Folder.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Tabs ───────────────────────────────────────────

  static Future<void> saveTabs(List<QuickTab> tabs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _tabsKey,
      jsonEncode(tabs.map((t) => t.toJson()).toList()),
    );
  }

  static Future<List<QuickTab>> loadTabs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tabsKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => QuickTab.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Font ──────────────────────────────────────────

  static Future<void> saveFont(String family, double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontFamilyKey, family);
    await prefs.setDouble(_fontSizeKey, size);
  }

  static Future<(String, double)?> loadFont() async {
    final prefs = await SharedPreferences.getInstance();
    final family = prefs.getString(_fontFamilyKey);
    final size   = prefs.getDouble(_fontSizeKey);
    if (family == null || size == null) return null;
    return (family, size);
  }

  // ── Tab lock ───────────────────────────────────────

  static Future<void> saveTabLocked(bool locked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tabLockedKey, locked);
  }

  static Future<bool> loadTabLocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tabLockedKey) ?? false;
  }

  // ── Colors ─────────────────────────────────────────

  static Future<void> saveColors(Color bg, Color text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bgKey, _toInt(bg));
    await prefs.setInt(_textKey, _toInt(text));

    // Sync to home-screen widget
    if (!kIsWeb) {
      final dim    = Color.lerp(text, bg, 0.25)!;
      final border = Color.lerp(bg, text, 0.35)!;
      final teal   = Color.lerp(text, Colors.black, 0.15)!;
      final mint   = text;
      unawaited(WidgetService.syncColors(
        bg: _toInt(bg),
        text: _toInt(text),
        dim: _toInt(dim),
        border: _toInt(border),
        teal: _toInt(teal),
        mint: _toInt(mint),
      ));
    }
  }

  static Future<(Color, Color)?> loadColors() async {
    final prefs = await SharedPreferences.getInstance();
    final bgInt = prefs.getInt(_bgKey);
    final textInt = prefs.getInt(_textKey);
    if (bgInt == null || textInt == null) return null;
    return (Color(bgInt), Color(textInt));
  }

  static int _toInt(Color c) {
    int ch(double v) => (v * 255.0).round().clamp(0, 255);
    return (0xFF << 24) | (ch(c.r) << 16) | (ch(c.g) << 8) | ch(c.b);
  }

  // ── Palette slots ─────────────────────────────────

  static const int paletteSlotCount = 5;
  static String _paletteKey(int i) => 'palette_slot_$i';

  static Future<List<(Color, Color)?>> loadPalettes() async {
    final prefs = await SharedPreferences.getInstance();
    return List.generate(paletteSlotCount, (i) {
      final raw = prefs.getString(_paletteKey(i));
      if (raw == null) return null;
      final parts = raw.split(',');
      if (parts.length != 2) return null;
      final bg   = int.tryParse(parts[0]);
      final text = int.tryParse(parts[1]);
      if (bg == null || text == null) return null;
      return (Color(bg), Color(text));
    });
  }

  static Future<void> savePaletteSlot(int i, Color bg, Color text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paletteKey(i), '${_toInt(bg)},${_toInt(text)}');
  }

  static Future<void> clearPaletteSlot(int i) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_paletteKey(i));
  }

  // ── System folder state ────────────────────────────

  static Future<int> getDayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_firstOpenKey);
    if (raw == null) {
      await prefs.setString(_firstOpenKey, DateTime.now().toIso8601String());
      return 1;
    }
    final first = DateTime.parse(raw);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = DateTime(first.year, first.month, first.day);
    return today.difference(firstDay).inDays + 1;
  }

  static Future<bool> getHabitActivated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_habitActivatedKey) ?? false;
  }

  static Future<void> setHabitActivated(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_habitActivatedKey, value);
  }

  static Future<bool> getGoalActivated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_goalActivatedKey) ?? false;
  }

  static Future<void> setGoalActivated(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_goalActivatedKey, value);
  }

  // ── Clear all ──────────────────────────────────────

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
