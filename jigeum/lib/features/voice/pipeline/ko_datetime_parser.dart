/// 한국어 날짜·시간 파서. 기획서 §4 전체 + §5 커밋4.
///
/// **커밋4 전 스텁** — 8장 코퍼스 테스트를 먼저 고정(red)하기 위한 골격이다.
/// 실제 파싱 규칙은 커밋4에서 채운다. (§4-1 날짜 / §4-2 시각 / §4-3 기간 /
/// §4-5 한글 수사)
library;

import '../models/time_parse_result.dart';

class KoDateTimeParser {
  const KoDateTimeParser();

  /// [text](정규화된 문장)에서 날짜·시각·기간을 뽑는다. [now] 는 상대일 기준(테스트
  /// 결정성). 미구현 스텁은 빈 결과를 돌려주므로 코퍼스 파싱 단정은 아직 실패한다.
  TimeParseResult parse(String text, {DateTime? now}) => TimeParseResult.empty;
}
