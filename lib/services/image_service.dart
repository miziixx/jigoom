import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  static const _maxBytes = 5 * 1024 * 1024; // 5 MB
  static final _picker = ImagePicker();

  static Future<String?> pick(ImageSource source) async {
    if (kIsWeb) return null;
    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (xfile == null) return null;

      final file = File(xfile.path);
      final size = await file.length();
      if (size > _maxBytes) return '__TOO_LARGE__';

      return _copyToAppDir(xfile.path);
    } catch (_) {
      return null;
    }
  }

  static Future<String> _copyToAppDir(String sourcePath) async {
    final dir = await _imagesDir();
    final dot = sourcePath.lastIndexOf('.');
    final ext = dot != -1 ? sourcePath.substring(dot) : '.jpg';
    final dest = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(sourcePath).copy(dest);
    return dest;
  }

  static Future<Directory> _imagesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/memo_images');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<void> deleteImages(List<String> paths) async {
    for (final path in paths) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}
