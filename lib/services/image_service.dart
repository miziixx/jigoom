import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class PickedImagesResult {
  final List<String> paths;
  final int rejectedCount;

  const PickedImagesResult({required this.paths, this.rejectedCount = 0});
}

class ImageService {
  static const maxImagesPerMemo = 10;
  static const maxPickCount = 5;
  static const _maxBytes = 10 * 1024 * 1024; // compressed copy guard
  static const _channel = MethodChannel('app/images');
  static final _picker = ImagePicker();

  static Future<String?> pick(ImageSource source) async {
    if (kIsWeb) return null;
    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2560,
        maxHeight: 2560,
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

  static Future<PickedImagesResult> pickManyFromGallery({
    int remainingSlots = maxImagesPerMemo,
  }) async {
    if (kIsWeb || remainingSlots <= 0) {
      return const PickedImagesResult(paths: []);
    }
    final limit = remainingSlots.clamp(0, maxPickCount);
    try {
      final files = await _picker.pickMultiImage(
        limit: limit,
        imageQuality: 88,
        maxWidth: 2560,
        maxHeight: 2560,
      );
      final saved = <String>[];
      var rejected = 0;
      for (final xfile in files.take(limit)) {
        final file = File(xfile.path);
        if (await file.length() > _maxBytes) {
          rejected++;
          continue;
        }
        saved.add(await _copyToAppDir(xfile.path));
      }
      return PickedImagesResult(paths: saved, rejectedCount: rejected);
    } catch (_) {
      return const PickedImagesResult(paths: []);
    }
  }

  static Future<bool> saveToGallery(String path) async {
    if (kIsWeb) return false;
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      final ok = await _channel.invokeMethod<bool>('saveImageToGallery', {
        'path': path,
      });
      return ok ?? false;
    } catch (_) {
      return false;
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
