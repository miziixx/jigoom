import '../models/memo.dart';

/// 순수 로컬(업로드 0) 메모 검색 — 글자 n-gram + 동의어 확장.
///
/// 진짜 신경망 임베딩은 아니지만 substring 매칭보다 낫고, 데이터가 폰 밖으로
/// 나가지 않는다. 한국어는 글자 2-gram이 조사/어미 변형을 흡수한다
/// ("운동" 질문이 "운동했다"·"운동하러"와 매칭). 동의어("운동"↔"헬스")는
/// 아래 [_synonyms] 사전으로 질의어를 확장해 어느 정도 잡는다.
class LocalSearchService {
  /// 동의어/유의어 그룹. 한 그룹 안의 단어는 서로 검색에 매칭된다.
  /// 질의에 그룹의 한 단어가 들어오면 같은 그룹의 나머지 단어도 함께 검색한다.
  static const List<List<String>> _synonymGroups = [
    ['운동', '헬스', '워크아웃', '트레이닝', '피트니스'],
    ['공부', '학습', '스터디', '복습', '예습'],
    ['일', '업무', '작업', '태스크', '일거리'],
    ['회의', '미팅', '컨퍼런스'],
    ['돈', '비용', '지출', '결제', '금액', '가격'],
    ['수입', '소득', '월급', '급여'],
    ['아이디어', '생각', '발상', '구상'],
    ['목표', '계획', '플랜'],
    ['건강', '컨디션', '몸상태'],
    ['음식', '밥', '식사', '먹거리', '끼니'],
    ['책', '도서', '서적', '독서'],
    ['영화', '무비', '영상'],
    ['음악', '노래', '뮤직'],
    ['여행', '트립', '나들이', '여정'],
    ['친구', '지인', '동료'],
    ['감정', '기분', '느낌', '마음'],
    ['문제', '이슈', '버그', '오류', '에러'],
    ['해결', '수정', '고침', '픽스'],
    ['프로젝트', '과제', '플젝'],
    ['약속', '일정', '스케줄'],
  ];

  static Map<String, List<String>>? _synonymsCache;
  static Map<String, List<String>> get _synonyms {
    final cached = _synonymsCache;
    if (cached != null) return cached;
    final map = <String, List<String>>{};
    for (final group in _synonymGroups) {
      for (final word in group) {
        map[word] = group.where((w) => w != word).toList();
      }
    }
    return _synonymsCache = map;
  }

  /// [query]와 관련있는 메모를 점수 높은 순으로 반환.
  static List<Memo> search(String query, List<Memo> memos, {int limit = 15}) {
    final expanded = _expandSynonyms(_normalize(query));
    final qGrams = _ngrams(expanded);
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

  /// 정규화된 질의에 동의어를 덧붙여 확장한다.
  static String _expandSynonyms(String normalized) {
    final tokens = normalized.split(' ');
    final extra = <String>[];
    for (final t in tokens) {
      final syns = _synonyms[t];
      if (syns != null) extra.addAll(syns);
    }
    if (extra.isEmpty) return normalized;
    return '$normalized ${extra.join(' ')}';
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
