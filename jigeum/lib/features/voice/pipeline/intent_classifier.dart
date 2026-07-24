/// 인텐트 분류기. 기획서 §3(점수제) + §3-3(충돌해소) + §2-1(시간단서 가점).
/// §5 커밋6.
///
/// 입력 = 정규화문 + 날짜·시간 파싱 결과. 출력 = 최고점 인텐트 + 점수 S + 2등격차 D.
/// **AI 없이** 사전 매칭·시간단서·충돌해소 규칙만으로 결정적으로 판정한다.
///
/// 분류는 **정규화 원문**에서 키워드를 찾는다(§ 확정 설계 결정): 파서가 "오늘"을
/// 날짜로 잘라내도 goal.today 단서가 살아있어야 하므로, 여기서는 원문을 훼손하지
/// 않고 그대로 스캔한다. 제목 분리는 SlotExtractor(커밋7) 담당.
///
/// 프레임워크 비의존(순수 Dart).
library;

import '../data/intent_lexicon.dart';
import '../models/intent_type.dart';
import '../models/time_parse_result.dart';
import '../models/voice_result.dart';
import '../voice_constants.dart';

class IntentClassifier {
  const IntentClassifier({
    this.knownHabits = const <String>{},
  });

  /// §11-2 사용자 사전 자동 편입 — 등록된 습관명. "물 마시기 했어" 를
  /// habit.check 로 정확히 끌기 위해 대조한다. 비어 있으면 habit.check 는 안 뜬다.
  final Set<String> knownHabits;

  /// 정규화문 [text] 와 시간 파싱 [tp] 로부터 인텐트를 분류한다.
  ///
  /// [userLexicon] 은 §11-1 자동학습으로 임계를 넘긴 `키워드→인텐트` 사전.
  /// 해당 키워드가 문장에 있으면 그 인텐트에 가점한다(말투 개인화).
  IntentScore classify(
    String text,
    TimeParseResult tp, {
    Map<String, IntentType> userLexicon = const <String, IntentType>{},
  }) {
    final scores = <IntentType, int>{};
    void add(IntentType i, int pts) {
      if (pts == 0) return;
      scores[i] = (scores[i] ?? 0) + pts;
    }

    // --- 1) 트리거 사전 매칭 -------------------------------------------------
    for (final intent in IntentLexicon.primary.keys) {
      // habit.check 는 완료·체크동사가 결정적이라 아래에서 특례로 처리.
      if (intent == IntentType.habitCheck) continue;

      final primaryHits =
          IntentLexicon.primary[intent]!.where(text.contains).length;

      if (IntentLexicon.commandIntents.contains(intent)) {
        // 이동·도움: 하나만 맞아도 강신호(§3-3 6). 추가 매칭은 소폭 가점.
        if (primaryHits > 0) {
          add(intent, VoiceScores.strongSignal);
          add(intent, (primaryHits - 1) * VoiceScores.keyword);
        }
        continue;
      }

      // 추가형: primary 는 각 +keyword.
      add(intent, primaryHits * VoiceScores.keyword);

      // co 트리거는 primary 가 잡힌 뒤에만(오검출 방지).
      if (primaryHits > 0) {
        final coHits =
            (IntentLexicon.co[intent] ?? const []).where(text.contains).length;
        add(intent, coHits * VoiceScores.keyword);
      }

      // weak 신호는 조건 없이 +1(애매 → A 안전망).
      final weakHits =
          (IntentLexicon.weak[intent] ?? const []).where(text.contains).length;
      add(intent, weakHits * 1);

      // future_marker 는 이미 후보로 뜬 추가형만 소폭 보강(§3-2).
      if ((scores[intent] ?? 0) > 0 &&
          IntentLexicon.futureMarkers.any(text.contains)) {
        add(intent, VoiceScores.futureMarker);
      }
    }

    // 담기·기입 동사(적어줘/추가해줘/넣어놔 …) 존재 여부(사용자 말투 ③).
    final hasAddVerb = IntentLexicon.addVerbs.any(text.contains);

    // --- 2) 시간 단서 가점(§2-1) --------------------------------------------
    final hasFutureDate = tp.date != null && !tp.isPast;
    if (hasFutureDate && tp.time != null) {
      add(IntentType.scheduleAdd, VoiceScores.futureDateTime); // 내일 3시 류
    } else if (hasFutureDate) {
      add(IntentType.scheduleAdd, VoiceScores.futureDateOnly); // 금요일 류
      add(IntentType.todoAdd, VoiceScores.futureDateTodoBonus); // 마감일 후보
      // 날짜 + 담기동사("1월 1일날 데이트 적어줘") → 확정 일정으로 끌어올린다.
      if (hasAddVerb) add(IntentType.scheduleAdd, VoiceScores.keyword);
    } else if (hasAddVerb) {
      // 날짜 없이 담기동사만("자기 전에 약 먹기 추가해줘") → 최소 A 안착(미인식 방지).
      add(IntentType.todoAdd, 1);
    }

    if (tp.durationMin != null) {
      final focusVerb = IntentLexicon.primary[IntentType.focusStart]!
          .any(text.contains); // 집중/몰입/타이머
      if (focusVerb) {
        add(IntentType.focusStart, VoiceScores.durationClue);
      } else if (tp.isPast) {
        add(IntentType.logNow, VoiceScores.durationClue); // 방금 30분 류
      } else {
        add(IntentType.focusStart, VoiceScores.durationClue); // 기본 집중 성향
      }
    }

    // --- 3) 과거 시제(§3-3 1순위) -------------------------------------------
    if (tp.isPast) {
      add(IntentType.logNow, VoiceScores.pastTense);
    }

    // --- 3-1) habit.check 특례 ---------------------------------------------
    // (a) 명시적 체크·완료동사("체크해줘/다 채웠어/성공")가 결정적. 습관 문맥이면 더.
    // (b) 완료동사 없이 과거 + 등록 습관명 일치("물 마시기 했어")도 체크로(§11-2).
    final checkVerb =
        IntentLexicon.primary[IntentType.habitCheck]!.any(text.contains);
    final habitNameHit =
        knownHabits.any((h) => h.isNotEmpty && text.contains(h));
    if (checkVerb) {
      add(IntentType.habitCheck, VoiceScores.strongSignal);
      if (text.contains('습관') || habitNameHit) {
        add(IntentType.habitCheck, VoiceScores.keyword);
      }
    } else if (tp.isPast && habitNameHit) {
      add(IntentType.habitCheck,
          VoiceScores.strongSignal + VoiceScores.keyword);
    }

    // --- 4) goal.today 특례(§3-3 5) — "오늘"+"목표" 근접 -------------------
    if (text.contains('오늘 목표')) {
      add(IntentType.goalToday, VoiceScores.strongSignal + VoiceScores.keyword);
    } else if (text.contains('오늘') && text.contains('목표')) {
      add(IntentType.goalToday, VoiceScores.strongSignal);
    }

    // --- 4-1) 개인화 사전(§11-1) — 학습된 표현이 있으면 그 인텐트에 가점 -----
    if (userLexicon.isNotEmpty) {
      userLexicon.forEach((key, intent) {
        if (key.isNotEmpty && intent != IntentType.none && text.contains(key)) {
          add(intent, VoiceScores.userLexicon);
        }
      });
    }

    // --- 5) 최고점/2등격차 산출 --------------------------------------------
    if (scores.isEmpty) return IntentScore.none;

    IntentType best = IntentType.none;
    var top = 0;
    var second = 0;
    // 결정적 tie-break: 점수 같으면 enum 선언 순서가 빠른 쪽이 이긴다.
    for (final intent in IntentType.values) {
      final s = scores[intent] ?? 0;
      if (s > top) {
        second = top;
        top = s;
        best = intent;
      } else if (s > second) {
        second = s;
      }
    }

    if (top == 0) return IntentScore.none;
    return IntentScore(intent: best, score: top, runnerUpGap: top - second);
  }
}
