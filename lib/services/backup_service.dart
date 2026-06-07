import 'dart:convert';
import '../models/memo.dart';
import '../models/folder.dart';
import '../models/quick_tab.dart';
import 'backup_io.dart' if (dart.library.html) 'backup_web.dart';
import 'txt_import_service.dart';

class BackupService {
  static Map<String, dynamic> _buildData({
    required List<Memo> memos,
    required List<Folder> folders,
    required List<QuickTab> tabs,
    required Map<String, dynamic> settings,
  }) => {
    'version': 1,
    'memos': memos.map((m) => m.toJson()).toList(),
    'folders': folders.map((f) => f.toJson()).toList(),
    'tabs': tabs.map((t) => t.toJson()).toList(),
    'settings': settings,
  };

  static String _filename() {
    final now = DateTime.now();
    final d =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final t =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'nemo_backup_${d}_$t.json';
  }

  // Share via system sheet (email, Drive, etc.)
  static Future<void> export({
    required List<Memo> memos,
    required List<Folder> folders,
    required List<QuickTab> tabs,
    required Map<String, dynamic> settings,
  }) async {
    final json = const JsonEncoder.withIndent('  ').convert(
      _buildData(
        memos: memos,
        folders: folders,
        tabs: tabs,
        settings: settings,
      ),
    );
    await platformDownload(json, _filename());
  }

  // Save directly to phone storage
  static Future<bool> exportToPhone({
    required List<Memo> memos,
    required List<Folder> folders,
    required List<QuickTab> tabs,
    required Map<String, dynamic> settings,
  }) async {
    final json = const JsonEncoder.withIndent('  ').convert(
      _buildData(
        memos: memos,
        folders: folders,
        tabs: tabs,
        settings: settings,
      ),
    );
    return platformSaveToPhone(json, _filename());
  }

  static Future<Map<String, dynamic>?> import() async {
    final content = await platformPickFile();
    if (content == null) return null;
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // TXT 파일을 선택하고 블록 단위로 파싱합니다.
  static Future<List<String>?> importTxt() async {
    final content = await platformPickTxtFile();
    if (content == null) return null;
    final blocks = parseTxtBlocks(content);
    return blocks.isEmpty ? null : blocks;
  }
}
