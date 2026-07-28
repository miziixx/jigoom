/// 개인화 자동학습. 기획서 §11-1 + §5 커밋11.
///
/// **AI 아님 — 순수 빈도 카운터.** 되돌리기·재분류(또는 "다르게 담기" 칩)가
/// 일어날 때 `(정규화 키워드 → 최종 착지 인텐트)` 를 센다. 같은 표현이 임계
/// 횟수(기본 3회) 같은 곳으로 교정되면 사용자 사전에 자동 등록되어, 다음부터
/// 분류기가 그 인텐트에 가점(+`VoiceScores.userLexicon`)한다.
///
/// 예) "장보기" 를 세 번 A(할일)로 옮기면 4번째부터 "장보기" 는 A로 확정.
/// 말투에 앱이 맞춰간다.
///
/// 프레임워크 비의존(순수 Dart).
library;

import '../models/intent_type.dart';

/// 사용자 사전 한 항목(§11-1). `{key, intent, count, lastUsed}`.
class UserLexiconEntry {
  const UserLexiconEntry({
    required this.key,
    required this.intent,
    required this.count,
    required this.lastUsed,
  });

  final String key;
  final IntentType intent;
  final int count;
  final DateTime lastUsed;

  Map<String, dynamic> toJson() => {
        'key': key,
        'intent': intent.code,
        'count': count,
        'lastUsed': lastUsed.toIso8601String(),
      };

  factory UserLexiconEntry.fromJson(Map<String, dynamic> json) =>
      UserLexiconEntry(
        key: json['key'] as String,
        intent: IntentType.values
            .firstWhere((i) => i.code == json['intent'], orElse: () => IntentType.none),
        count: json['count'] as int,
        lastUsed: DateTime.parse(json['lastUsed'] as String),
      );
}

/// 교정 빈도를 세어 사용자 사전을 만든다.
class UserLexicon {
  UserLexicon({this.threshold = 3});

  /// 자동 등록에 필요한 반복 횟수(기본 3, §11-1).
  final int threshold;

  // key → (intent → count)
  final Map<String, Map<IntentType, int>> _counts = {};
  final Map<String, DateTime> _lastUsed = {};

  /// 교정 1건을 센다. [key] 는 정규화된 표현(보통 제목/내용).
  void record(String key, IntentType intent, {DateTime? at}) {
    final k = key.trim();
    if (k.isEmpty || intent == IntentType.none) return;
    final m = _counts.putIfAbsent(k, () => <IntentType, int>{});
    m[intent] = (m[intent] ?? 0) + 1;
    _lastUsed[k] = at ?? DateTime.now();
  }

  /// [key] 가 임계에 도달했으면 그 인텐트(최다), 아니면 null.
  IntentType? learnedIntentFor(String key) {
    final m = _counts[key.trim()];
    if (m == null) return null;
    IntentType? best;
    var bestCount = 0;
    m.forEach((intent, c) {
      if (c > bestCount) {
        bestCount = c;
        best = intent;
      }
    });
    return bestCount >= threshold ? best : null;
  }

  /// 분류기에 넘길, 임계를 넘긴 활성 항목들(key → intent).
  Map<String, IntentType> activeEntries() {
    final out = <String, IntentType>{};
    for (final key in _counts.keys) {
      final intent = learnedIntentFor(key);
      if (intent != null) out[key] = intent;
    }
    return out;
  }

  /// 영속화용 전체 스냅샷.
  List<UserLexiconEntry> entries() {
    final out = <UserLexiconEntry>[];
    _counts.forEach((key, m) {
      m.forEach((intent, count) {
        out.add(UserLexiconEntry(
          key: key,
          intent: intent,
          count: count,
          lastUsed: _lastUsed[key] ?? DateTime.fromMillisecondsSinceEpoch(0),
        ));
      });
    });
    return out;
  }

  /// 저장본에서 복원.
  void loadEntries(Iterable<UserLexiconEntry> saved) {
    for (final e in saved) {
      final m = _counts.putIfAbsent(e.key, () => <IntentType, int>{});
      m[e.intent] = e.count;
      final prev = _lastUsed[e.key];
      if (prev == null || e.lastUsed.isAfter(prev)) _lastUsed[e.key] = e.lastUsed;
    }
  }
}
