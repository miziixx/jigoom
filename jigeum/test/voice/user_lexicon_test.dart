// 커밋11 자동학습(§11-1) — 빈도 카운터 + 분류기 가점 + 되돌리기 기록.
import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/voice/learning/user_lexicon.dart';
import 'package:jigeum/features/voice/models/intent_type.dart';
import 'package:jigeum/features/voice/voice_router.dart';

void main() {
  final base = DateTime(2026, 7, 24);

  group('UserLexicon 카운터', () {
    test('임계(3) 도달 전엔 학습 안 됨, 도달하면 활성', () {
      final lex = UserLexicon();
      lex.record('장보기', IntentType.todoAdd);
      lex.record('장보기', IntentType.todoAdd);
      expect(lex.learnedIntentFor('장보기'), isNull); // 2회
      lex.record('장보기', IntentType.todoAdd);
      expect(lex.learnedIntentFor('장보기'), IntentType.todoAdd); // 3회
      expect(lex.activeEntries(), {'장보기': IntentType.todoAdd});
    });

    test('최다 인텐트가 이긴다', () {
      final lex = UserLexicon(threshold: 2);
      lex.record('회식', IntentType.scheduleAdd);
      lex.record('회식', IntentType.scheduleAdd);
      lex.record('회식', IntentType.todoAdd);
      expect(lex.learnedIntentFor('회식'), IntentType.scheduleAdd);
    });

    test('none·빈 키는 무시', () {
      final lex = UserLexicon(threshold: 1);
      lex.record('', IntentType.todoAdd);
      lex.record('x', IntentType.none);
      expect(lex.activeEntries(), isEmpty);
    });

    test('entries 왕복(저장/복원)', () {
      final lex = UserLexicon(threshold: 2);
      lex.record('장보기', IntentType.todoAdd);
      lex.record('장보기', IntentType.todoAdd);
      final saved = lex.entries().map((e) => e.toJson()).toList();
      final restored = UserLexicon(threshold: 2)
        ..loadEntries(saved.map(UserLexiconEntry.fromJson));
      expect(restored.learnedIntentFor('장보기'), IntentType.todoAdd);
    });
  });

  group('라우터 연동', () {
    test('3회 학습되면 보류함을 탈출해 A로 안착', () {
      final router = VoiceRouter();
      // 학습 전엔 '행동형 어미'도 없는 모호한 말이라 보류함. (행동형 명사구
      // "왈츠 배우기"는 이제 폴백으로 바로 A 이므로 학습 예시는 모호한 말로.)
      final r0 = router.analyze('왈츠 그거', now: base);
      expect(r0.intent, IntentType.none, reason: '학습 전엔 미인식');
      expect(r0.routedTo, RoutePoint.inbox);

      for (var i = 0; i < 3; i++) {
        router.learning.record('왈츠 그거', IntentType.todoAdd);
      }
      final r1 = router.analyze('왈츠 그거', now: base);
      expect(r1.intent, IntentType.todoAdd);
      expect(r1.routedTo, RoutePoint.quickCapture);
    });

    test('임계 미달(2회)은 아직 미학습', () {
      final router = VoiceRouter();
      router.learning.record('왈츠 그거', IntentType.todoAdd);
      router.learning.record('왈츠 그거', IntentType.todoAdd);
      expect(router.analyze('왈츠 그거', now: base).intent, IntentType.none);
    });

    test('recordCorrection 은 제목을 키로 학습해 재분류를 반영', () {
      final router = VoiceRouter();
      final res = router.analyze('파란색 그거 처리', now: base);
      expect(res.intent, IntentType.todoAdd); // 기본은 약신호로 A

      for (var i = 0; i < 3; i++) {
        router.recordCorrection(res, IntentType.todoMatrix);
      }
      final after = router.analyze('파란색 그거 처리', now: base);
      expect(after.intent, IntentType.todoMatrix, reason: '학습된 매트릭스로 전환');
    });
  });
}
