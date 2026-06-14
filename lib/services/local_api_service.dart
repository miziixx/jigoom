import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import '../models/memo.dart';
import 'storage_service.dart';

class LocalApiService {
  static const int _port = 8765;
  static HttpServer? _server;

  static Future<void> start() async {
    if (_server != null) return;
    try {

    final router = Router();

    router.post('/memos', (Request req) async {
      try {
        final body = await req.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;

        final content = json['content'] as String? ?? '';
        final sourceUrl = json['sourceUrl'] as String?;
        final tags = json['tags'] as String? ?? '';

        if (content.isEmpty && sourceUrl == null) {
          return Response(400, body: '{"error":"content required"}');
        }

        final fullContent = tags.isNotEmpty ? '$content $tags'.trim() : content;

        final memo = Memo(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: fullContent,
          createdAt: DateTime.now(),
          sourceUrl: sourceUrl,
        );

        final memos = await StorageService.loadMemos();
        memos.insert(0, memo);
        await StorageService.saveMemos(memos);

        return Response.ok(
          '{"id":"${memo.id}"}',
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response(500, body: '{"error":"$e"}');
      }
    });

    router.get('/health', (Request req) {
      return Response.ok('{"status":"ok"}');
    });

    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addHandler(router.call);

    _server = await io.serve(handler, InternetAddress.loopbackIPv4, _port);
    } catch (_) {
      // 포트 충돌 등 에러 시 앱 실행에 영향 없이 무시
    }
  }

  static Middleware _corsMiddleware() {
    return (Handler inner) {
      return (Request req) async {
        final res = await inner(req);
        return res.change(headers: {
          'access-control-allow-origin': 'http://localhost',
          ...res.headers,
        });
      };
    };
  }

  static Future<void> stop() async {
    await _server?.close();
    _server = null;
  }
}
