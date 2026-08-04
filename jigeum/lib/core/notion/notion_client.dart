import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Notion REST API 얇은 래퍼.
///
/// 구글 캘린더의 [DeviceCalendarBridge] 에 대응하는 "바깥 세계와 이야기하는" 레이어.
/// 토큰이 없거나 웹(PWA, CORS 불가)이면 조용히 no-op/실패로 처리해 앱이 죽지 않게 한다.
/// 실제 동기화 판단(무엇을 밀지)은 상위 [NotionSync] 가 하고, 여기선 순수 HTTP 만.
class NotionClient {
  NotionClient(this.token, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String token;
  final http.Client _http;

  static const _base = 'https://api.notion.com/v1';
  static const _version = '2022-06-28';

  /// 브라우저에서는 Notion 이 CORS 를 허용하지 않아 호출이 막힌다 → 사용 불가.
  bool get usable => !kIsWeb && token.trim().isNotEmpty;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Notion-Version': _version,
        'Content-Type': 'application/json',
      };

  /// 토큰 검증 — 성공하면 연결된 워크스페이스/봇 정보를 돌려준다(실패 시 null).
  Future<Map<String, dynamic>?> usersMe() async {
    if (!usable) return null;
    try {
      final r = await _http.get(Uri.parse('$_base/users/me'), headers: _headers);
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
      debugPrint('notion usersMe 실패: ${r.statusCode} ${r.body}');
    } catch (e) {
      debugPrint('notion usersMe 예외: $e');
    }
    return null;
  }

  /// 부모 페이지 아래 데이터베이스 생성 → 생성된 database id(실패 시 null).
  Future<String?> createDatabase({
    required String parentPageId,
    required String title,
    required Map<String, dynamic> properties,
  }) async {
    if (!usable) return null;
    try {
      final r = await _http.post(
        Uri.parse('$_base/databases'),
        headers: _headers,
        body: jsonEncode({
          'parent': {'type': 'page_id', 'page_id': parentPageId},
          'title': [
            {
              'type': 'text',
              'text': {'content': title}
            }
          ],
          'properties': properties,
        }),
      );
      if (r.statusCode == 200) {
        return (jsonDecode(r.body) as Map<String, dynamic>)['id'] as String?;
      }
      debugPrint('notion createDatabase 실패: ${r.statusCode} ${r.body}');
    } catch (e) {
      debugPrint('notion createDatabase 예외: $e');
    }
    return null;
  }

  /// JigeumId(원본 레코드 id) 로 기존 페이지를 찾는다 → 페이지 id(없으면 null).
  /// upsert 의 "이미 있나?" 판정에 쓴다.
  Future<String?> findPageByJigeumId(String databaseId, String jigeumId) async {
    if (!usable) return null;
    try {
      final r = await _http.post(
        Uri.parse('$_base/databases/$databaseId/query'),
        headers: _headers,
        body: jsonEncode({
          'page_size': 1,
          'filter': {
            'property': 'JigeumId',
            'rich_text': {'equals': jigeumId}
          },
        }),
      );
      if (r.statusCode == 200) {
        final results =
            (jsonDecode(r.body) as Map<String, dynamic>)['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return (results.first as Map<String, dynamic>)['id'] as String?;
        }
        return null; // 없음(=신규)
      }
      debugPrint('notion query 실패: ${r.statusCode} ${r.body}');
    } catch (e) {
      debugPrint('notion query 예외: $e');
    }
    return null;
  }

  /// 새 페이지 생성 → 성공 여부.
  Future<bool> createPage({
    required String databaseId,
    required Map<String, dynamic> properties,
  }) async {
    if (!usable) return false;
    try {
      final r = await _http.post(
        Uri.parse('$_base/pages'),
        headers: _headers,
        body: jsonEncode({
          'parent': {'database_id': databaseId},
          'properties': properties,
        }),
      );
      if (r.statusCode == 200) return true;
      debugPrint('notion createPage 실패: ${r.statusCode} ${r.body}');
    } catch (e) {
      debugPrint('notion createPage 예외: $e');
    }
    return false;
  }

  /// 기존 페이지 속성 갱신 → 성공 여부.
  Future<bool> updatePage({
    required String pageId,
    required Map<String, dynamic> properties,
  }) async {
    if (!usable) return false;
    try {
      final r = await _http.patch(
        Uri.parse('$_base/pages/$pageId'),
        headers: _headers,
        body: jsonEncode({'properties': properties}),
      );
      if (r.statusCode == 200) return true;
      debugPrint('notion updatePage 실패: ${r.statusCode} ${r.body}');
    } catch (e) {
      debugPrint('notion updatePage 예외: $e');
    }
    return false;
  }

  void dispose() => _http.close();
}
