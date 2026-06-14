import '../models/memo.dart';

/// 순수 로컬(업로드 0) 메모 검색 — 글자 n-gram 유사도.
///
/// 진짜 의미 임베딩은 아니지만 substring 매칭보다 낫고, 데이터가 폰 밖으로
/// 나가지 않는다. 한국어는 글자 2-gram이 조사/어미 변형을 어느 정도 흡수한다
/// ("운동" 질문이 "운동했다"·"운동하러"와 매칭). 동의어("운동"↔"헬스")는 못
/// 잡는다 — 그건 온디바이스 임베딩(②)이 와야 해결된다.
class LocalSearchService {
  /// [query]와 관련있는 메모를 점수 높은 순으로 반환.
  static List<Memo> search(String query, List<Memo> memos, {int limit = 15}) {
    final qGrams = _ngrams(_normalize(query));
    if (qGrams.isEmpty || memos.isEmpty) return [];

    final scored = <(double, Memo)>[];
    for (final m in memos) {
      final raw = '${m.content} '
          '${m.appendNotes.map((n) => n.content).join(' ')} '
          '${m.tags.join(' ')}';
      final docGrams = _ngrams(_normalize(raw));
      if (docGrams.isEmpty) continue;
      final score = _coverage(qGrams, docGrams);
      if (score > 0) scored.add((score, m));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return scored.take(limit).map((e) => e.$2).toList();
  }

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'https?://\S+'), ' ')
      .replaceAll(RegExp(r'[^0-9a-z가-힣\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// 토큰별 글자 2-gram 집합. 짧은 토큰(1~2자)은 그대로 사용.
  static Set<String> _ngrams(String s, {int n = 2}) {
    final grams = <String>{};
    for (final token in s.split(' ')) {
      if (token.isEmpty) continue;
      if (token.length <= n) {
        grams.add(token);
      } else {
        for (int i = 0; i <= token.length - n; i++) {
          grams.add(token.substring(i, i + n));
        }
      }
    }
    return grams;
  }

  /// 질문 n-gram 중 메모에 등장하는 비율 (0~1). 긴 메모를 불리하게 만들지 않음.
  static double _coverage(Set<String> qGrams, Set<String> docGrams) {
    var inter = 0;
    for (final g in qGrams) {
      if (docGrams.contains(g)) inter++;
    }
    return inter / qGrams.length;
  }
}
