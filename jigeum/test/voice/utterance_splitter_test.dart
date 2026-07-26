import 'package:flutter_test/flutter_test.dart';
import 'package:jigeum/features/voice/pipeline/utterance_splitter.dart';

void main() {
  const splitter = UtteranceSplitter();

  test('해야 되고/그리고/넣고 말투를 여러 조각으로 나눈다', () {
    final parts = splitter.split(
      '보고서 정리 해야 되고 장보기 넣고 그리고 아침 루틴에 스트레칭 추가',
    );

    expect(parts.map((p) => p.text), [
      '보고서 정리',
      '장보기',
      '아침 루틴에 스트레칭 추가',
    ]);
    expect(parts.where((p) => p.skipped), isEmpty);
  });

  test('빼고/말고 앞 조각은 담지 않을 조각으로 표시한다', () {
    final parts = splitter.split('치과 예약 빼고 장보기 넣고 운동 루틴 만들어');

    expect(parts.map((p) => p.text), [
      '치과 예약',
      '장보기',
      '운동 루틴 만들어',
    ]);
    expect(parts.first.skipped, isTrue);
    expect(parts.skip(1).every((p) => !p.skipped), isTrue);
  });

  test('이거/저거처럼 대상 없는 조각은 만들지 않는다', () {
    final parts = splitter.split('이거 빼고 저거 너고');

    expect(parts, isEmpty);
  });
}
