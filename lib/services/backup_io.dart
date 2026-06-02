// Native (Android/desktop) implementation
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Share via system sheet (email, Drive, etc.)
Future<void> platformDownload(String content, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/json')],
    subject: filename,
  );
}

// Save directly to phone using system file picker
Future<bool> platformSaveToPhone(String content, String filename) async {
  try {
    final bytes = utf8.encode(content);
    final result = await FilePicker.platform.saveFile(
      dialogTitle: '백업 저장 위치 선택',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    return result != null;
  } catch (_) {
    // Fallback: save to app external storage
    final dir = await getExternalStorageDirectory();
    if (dir != null) {
      final file = File('${dir.path}/$filename');
      await file.writeAsString(content, flush: true);
      return true;
    }
    return false;
  }
}

Future<String?> platformPickFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final f = result.files.first;
  if (f.bytes != null) return utf8.decode(f.bytes!);
  if (f.path != null) return File(f.path!).readAsString();
  return null;
}
