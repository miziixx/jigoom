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

  // ── Markdown export (이식성: 옵시디언 등으로 가져갈 수 있게) ──

  static final _idLinkRe = RegExp(r'\[\[id:([^|\]]+)\|([^\]]+)\]\]');

  static String _mdFilename() {
    final now = DateTime.now();
    final d =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return 'nemo_export_$d.md';
  }

  /// 모든 메모를 하나의 마크다운 문서로 변환.
  /// `[[id:x|제목]]` 링크는 옵시디언 호환 `[[제목]]`으로 변환된다.
  static String buildMarkdown({
    required List<Memo> memos,
    required List<Folder> folders,
  }) {
    final folderName = {for (final f in folders) f.id: f.name};
    final buf = StringBuffer();
    final sorted = [...memos]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final m in sorted) {
      final title = m.content.split('\n').first.trim();
      buf.writeln('## ${title.isEmpty ? '(제목 없음)' : title}');
      buf.writeln();
      // 메타데이터 (YAML 비슷한 인라인)
      final meta = <String>[];
      meta.add('created: ${m.createdAt.toIso8601String()}');
      if (m.folderId != null && folderName[m.folderId] != null) {
        meta.add('folder: ${folderName[m.folderId]}');
      }
      if (m.tags.isNotEmpty) {
        meta.add('tags: ${m.tags.map((t) => '#$t').join(' ')}');
      }
      if (m.scheduledAt != null) {
        meta.add('scheduled: ${m.scheduledAt!.toIso8601String()}');
      }
      buf.writeln('> ${meta.join(' · ')}');
      buf.writeln();
      buf.writeln(_convertLinks(m.content));
      buf.writeln();
      for (final note in m.appendNotes) {
        buf.writeln('- ${_convertLinks(note.content).replaceAll('\n', '\n  ')}');
      }
      if (m.appendNotes.isNotEmpty) buf.writeln();
      buf.writeln('---');
      buf.writeln();
    }
    return buf.toString();
  }

  static String _convertLinks(String text) =>
      text.replaceAllMapped(_idLinkRe, (m) => '[[${m.group(2)}]]');

  /// 마크다운을 시스템 공유 시트로 내보낸다.
  static Future<void> exportMarkdown({
    required List<Memo> memos,
    required List<Folder> folders,
  }) async {
    final md = buildMarkdown(memos: memos, folders: folders);
    await platformExportText(md, _mdFilename(), 'text/markdown');
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
