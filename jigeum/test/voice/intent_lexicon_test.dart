// 커밋5 트리거 사전 정합성. 데이터만 검증(로직 없음).
import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/voice/data/intent_lexicon.dart';
import 'package:jigeum/features/voice/models/intent_type.dart';

void main() {
  group('사전 정합성', () {
    test('추가형 인텐트마다 primary 트리거가 존재(none 제외, 폴백 A 제외)', () {
      for (final i in IntentType.values) {
        if (i == IntentType.none) continue;
        if (i == IntentType.habitCheck) continue; // 등록 습관명 대조(런타임)
        expect(IntentLexicon.primary[i], isNotNull, reason: i.code);
        expect(IntentLexicon.primary[i]!.isNotEmpty, isTrue, reason: i.code);
      }
    });

    test('co 트리거는 반드시 primary 를 가진 인텐트에만 존재', () {
      for (final entry in IntentLexicon.co.entries) {
        expect(IntentLexicon.primary[entry.key], isNotNull,
            reason: '${entry.key.code} 는 co 만 있고 primary 가 없음');
      }
    });

    test('commandIntents 는 이동·도움 3종', () {
      expect(IntentLexicon.commandIntents, {
        IntentType.navMove,
        IntentType.helpStuck,
        IntentType.helpFortune,
      });
    });

    test('schedule stripWords 는 "치과/병원" 같은 장소를 지우지 않는다', () {
      final strip = IntentLexicon.stripWords[IntentType.scheduleAdd]!;
      expect(strip.contains('치과'), isFalse);
      expect(strip.contains('병원'), isFalse);
      expect(strip.contains('예약'), isTrue); // 동작어만 제거
    });
  });
}
