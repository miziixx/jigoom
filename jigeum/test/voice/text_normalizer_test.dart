import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/voice/pipeline/text_normalizer.dart';

void main() {
  const n = TextNormalizer();

  group('공백 정리', () {
    test('여러 공백을 단일 공백으로, 앞뒤 trim', () {
      expect(n.normalize('  내일   3시에   치과  '), '내일 3시에 치과');
    });

    test('빈 문자열은 빈 문자열', () {
      expect(n.normalize(''), '');
      expect(n.normalize('   '), '');
    });
  });

  group('문장부호 제거', () {
    test('쉼표·느낌표를 공백으로', () {
      expect(n.normalize('이거 중요하고, 급해! 보고서'), '이거 중요하고 급해 보고서');
    });

    test('말줄임표(…)와 군말 "어" 제거', () {
      // §8 안전망: 미인식 문장도 의미 토큰은 보존되어야 한다.
      expect(n.normalize('어… 그거 있잖아 뭐였지'), '그거 있잖아 뭐였지');
    });
  });

  group('군말 제거는 토큰 전체 일치만', () {
    test('앞머리 "음" 은 제거, "마시기"·"습관" 은 보존', () {
      expect(n.normalize('음 물 마시기 습관 만들어'), '물 마시기 습관 만들어');
    });

    test('"그거"·"저녁" 은 부분일치라 보존', () {
      expect(n.normalize('그거 저녁 7시'), '그거 저녁 7시');
    });
  });

  group('전각 숫자 → 반각', () {
    test('３시 → 3시', () {
      expect(n.normalize('３시에 치과'), '3시에 치과');
    });
  });

  group('의미 보존', () {
    test('조사 붙은 표현은 그대로(과잉 정리 안 함)', () {
      expect(n.normalize('오늘 목표는 보고서 끝내기'), '오늘 목표는 보고서 끝내기');
    });
  });
}
