import 'dart:convert';
import 'dart:io';
import '../models/memo.dart';

class WikiCaptureService {
  static const models = {
    'claude-haiku-4-5-20251001': 'Haiku 4.5 (빠름·저렴)',
    'claude-sonnet-4-6': 'Sonnet 4.6 (균형)',
    'claude-opus-4-8': 'Opus 4.8 (최고품질)',
  };

  // OG 태그만으로 메타데이터 추출 (API 키 불필요)
  static Future<String?> fetchMetadata(String url) async {
    final pageText = await _fetchPage(url);
    if (pageText == null) return null;
    final lines = pageText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final title = lines.isNotEmpty ? lines.first.trim() : url;
    final desc = lines.length > 1 ? lines.skip(1).take(3).join(' ').trim() : '';
    final buf = StringBuffer();
    buf.writeln('**제목**: $title');
    if (desc.isNotEmpty) buf.writeln('\n**요약**: $desc');
    buf.write('\n**출처**: $url');
    return buf.toString();
  }

  static Future<String?> summarize(String url, String apiKey, {String? model}) async {
    final pageText = await _fetchPage(url);
    if (pageText == null) return null;

    final prompt = '''다음 웹페이지 내용을 한국어로 요약해줘.

URL: $url

페이지 내용:
$pageText

아래 형식으로 답해줘:
**제목**: (페이지 제목)

**요약**: (3-5문장으로 핵심 내용)

**키워드**: #키워드1 #키워드2 #키워드3''';

    return await _callClaude(prompt, apiKey, model: model);
  }

  static Future<String?> _fetchPage(String url) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'Mozilla/5.0');
      req.headers.set('Accept-Language', 'ko,en');
      final res = await req.close();
      final bytes = await res.fold<List<int>>([], (a, b) => a..addAll(b));
      client.close();

      final html = utf8.decode(bytes, allowMalformed: true);

      // OG tags + body text 추출
      final og = _extractOg(html);
      final body = _extractText(html);
      final combined = [og, body].where((s) => s.isNotEmpty).join('\n\n');

      return combined.isEmpty ? null : combined.substring(
        0, combined.length.clamp(0, 4000),
      );
    } catch (_) {
      return null;
    }
  }

  static String _extractOg(String html) {
    final result = <String>[];
    final patterns = {
      'title': RegExp(r'<meta[^>]+(?:og:title|name="title")[^>]+content="([^"]+)"', caseSensitive: false),
      'desc': RegExp(r'<meta[^>]+(?:og:description|name="description")[^>]+content="([^"]+)"', caseSensitive: false),
    };
    for (final e in patterns.entries) {
      final m = e.value.firstMatch(html) ??
          RegExp(r'content="([^"]+)"[^>]+(?:og:' + e.key + r'|name="' + e.key + r'")', caseSensitive: false).firstMatch(html);
      if (m != null) result.add(m.group(1)!.trim());
    }
    // <title> fallback
    final titleM = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(html);
    if (titleM != null) result.insert(0, titleM.group(1)!.trim());
    return result.join('\n');
  }

  static String _extractText(String html) {
    var text = html
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&[a-z]+;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.substring(0, text.length.clamp(0, 3000));
  }

  // ── 연결: 새 메모와 관련된 기존 메모 찾기 ───────────────────
  static Future<List<String>> findConnections(
    String newSummary,
    List<Memo> allMemos,
    String apiKey, {
    String? model,
  }) async {
    if (allMemos.isEmpty) return [];

    // 기존 메모 목록 (최대 30개, 요약 있는 것 우선)
    final candidates = allMemos
        .where((m) => m.appendNotes.isNotEmpty || m.content.length > 20)
        .take(30)
        .toList();

    if (candidates.isEmpty) return [];

    final memoList = candidates.asMap().entries.map((e) {
      final m = e.value;
      final text = m.appendNotes.isNotEmpty
          ? m.appendNotes.last.content
          : m.content;
      return '[${e.key}] ${text.substring(0, text.length.clamp(0, 150))}';
    }).join('\n');

    final prompt = '''새 메모:
$newSummary

기존 메모 목록:
$memoList

위 기존 메모 중 새 메모와 관련있는 것의 번호만 쉼표로 나열해. 없으면 "없음". 예: 0,3,7''';

    final result = await _callClaude(prompt, apiKey, model: model);
    if (result == null || result.contains('없음')) return [];

    final indices = RegExp(r'\d+')
        .allMatches(result)
        .map((m) => int.tryParse(m.group(0)!))
        .whereType<int>()
        .where((i) => i < candidates.length)
        .toList();

    return indices.map((i) => candidates[i].id).toList();
  }

  // ── 정리: 관련 메모들로 주제 종합 ───────────────────────────
  static Future<String?> synthesize(
    String topic,
    List<Memo> memos,
    String apiKey, {
    String? model,
  }) async {
    if (memos.isEmpty) return '관련 메모가 없어요. 먼저 링크를 공유해서 저장해보세요!';

    final memoTexts = memos.map((m) {
      final summary = m.appendNotes.isNotEmpty
          ? m.appendNotes.last.content
          : m.content;
      final src = m.sourceUrl != null ? '\n출처: ${m.sourceUrl}' : '';
      return '---\n$summary$src';
    }).join('\n');

    final prompt = '''다음은 내가 저장한 메모들이야:

$memoTexts

이 메모들을 바탕으로 "$topic"에 대해 한국어로 종합 정리해줘.

형식:
# $topic 정리

## 핵심 인사이트
(내 메모에서 발견한 중요한 점 3-5개)

## 종합
(메모들을 연결해서 설명)

## 더 알아볼 것
(메모에서 언급됐지만 답이 없는 궁금증)

내 메모에 없는 내용은 추가하지 마.''';

    return await _callClaude(prompt, apiKey, maxTokens: 1024, model: model);
  }

  // ── 채팅 ─────────────────────────────────────────────
  static Future<String?> chatWithMemos({
    required String question,
    required List<Map<String, String>> history,
    required String systemPrompt,
    required String apiKey,
    String? model,
  }) async {
    try {
      final client = HttpClient();
      final req = await client.postUrl(
        Uri.parse('https://api.anthropic.com/v1/messages'),
      );
      req.headers.set('x-api-key', apiKey);
      req.headers.set('anthropic-version', '2023-06-01');
      req.headers.contentType = ContentType.json;

      final messages = [
        ...history,
        {'role': 'user', 'content': question},
      ];

      req.write(jsonEncode({
        'model': model ?? 'claude-haiku-4-5-20251001',
        'max_tokens': 1024,
        'system': systemPrompt,
        'messages': messages,
      }));

      final res = await req.close();
      final raw = await res.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final content = (json['content'] as List?)?.first;
      return content?['text'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _callClaude(
    String prompt,
    String apiKey, {
    int maxTokens = 512,
    String? model,
  }) async {
    try {
      final client = HttpClient();
      final req = await client.postUrl(
        Uri.parse('https://api.anthropic.com/v1/messages'),
      );
      req.headers.set('x-api-key', apiKey);
      req.headers.set('anthropic-version', '2023-06-01');
      req.headers.contentType = ContentType.json;

      final body = jsonEncode({
        'model': model ?? 'claude-haiku-4-5-20251001',
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      });
      req.write(body);

      final res = await req.close();
      final raw = await res.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final content = (json['content'] as List?)?.first;
      return content?['text'] as String?;
    } catch (_) {
      return null;
    }
  }
}
