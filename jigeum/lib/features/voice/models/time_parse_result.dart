/// 한국어 날짜·시간 파서(KoDateTimeParser, 커밋4)의 출력 규격. 기획서 §4-4.
///
/// **프레임워크 비의존**(Flutter import 없음)이라 순수 Dart 단위 테스트로
/// 빠르게 검증된다. 시각은 material 의 `TimeOfDay` 대신 경량 [ParsedTime] 을 쓴다.
library;

/// 파서가 원문에서 잘라낼 구간(문자 인덱스 반열림 구간 [start, end)).
///
/// 이름을 `TextSpan`/`TextRange` 로 두면 Flutter 위젯 계열과 충돌하므로
/// 프레임워크 비의존을 지키려고 [SpanRange] 로 둔다.
class SpanRange {
  const SpanRange(this.start, this.end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is SpanRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'SpanRange($start, $end)';
}

/// 시:분 값(24시간제). material `TimeOfDay` 의 경량 대체.
class ParsedTime {
  const ParsedTime(this.hour, this.minute);

  final int hour; // 0~23
  final int minute; // 0~59

  @override
  bool operator ==(Object other) =>
      other is ParsedTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// 날짜·시간 파싱 결과(§4-4).
class TimeParseResult {
  const TimeParseResult({
    this.date,
    this.time,
    this.durationMin,
    this.isPast = false,
    this.matchedSpans = const <SpanRange>[],
  });

  /// 아무 시간 단서도 없는 빈 결과.
  static const TimeParseResult empty = TimeParseResult();

  /// 날짜(자정 기준). 없으면 null.
  final DateTime? date;

  /// 시각. 없으면 null.
  final ParsedTime? time;

  /// 기간(분). 없으면 null.
  final int? durationMin;

  /// 과거 시제/과거 날짜 여부 — 인텐트 분류(§3-3 1순위)로 전달.
  final bool isPast;

  /// 원문에서 잘라낼 구간들(제목 추출용).
  final List<SpanRange> matchedSpans;

  /// 시간 단서가 하나라도 잡혔는지.
  bool get hasAny => date != null || time != null || durationMin != null;

  /// [original] 에서 [matchedSpans] 를 제거하고 공백을 정리한 남은 텍스트.
  /// (예: "내일 3시에 치과 예약" → "치과 예약")
  String stripFrom(String original) {
    if (matchedSpans.isEmpty) return original.trim();
    final spans = [...matchedSpans]..sort((a, b) => a.start.compareTo(b.start));
    final buf = StringBuffer();
    var cursor = 0;
    for (final s in spans) {
      final start = s.start.clamp(0, original.length);
      final end = s.end.clamp(0, original.length);
      if (start > cursor) buf.write(original.substring(cursor, start));
      if (end > cursor) cursor = end;
    }
    if (cursor < original.length) buf.write(original.substring(cursor));
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  String toString() => 'TimeParseResult(date: $date, time: $time, '
      'durationMin: $durationMin, isPast: $isPast)';
}
