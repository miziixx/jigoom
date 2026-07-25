/// 한국어 날짜·시간 파서. 기획서 §4 전체 + §5 커밋4.
///
/// 라이브러리 없이 규칙으로 직접 구현한다. 파싱한 구간은 [TimeParseResult.matchedSpans]
/// 로 표시해 뒷단(슬롯 추출)이 원문에서 잘라내 제목을 얻게 한다.
/// (예: "내일 3시에 치과 예약" → 시간부 제거 → "치과 예약")
///
/// **프레임워크 비의존**(순수 Dart)이라 [now] 를 주입해 결정적으로 테스트한다.
library;

import '../models/time_parse_result.dart';

class KoDateTimeParser {
  const KoDateTimeParser();

  /// 오전/오후 표기가 없는 정시(H시)에서 낮 시간으로 볼 최대 시(§4-2 보정).
  /// 1~6시는 오후로(3시→15:00), 7~11시는 그대로. 설정으로 조정 가능하게 상수화.
  static const int bareHourPmMax = 6;

  /// 애매시각 기본 매핑(아침/점심/저녁/밤). "아침 루틴"처럼 시각이 아닌 낱말을
  /// 잡아먹지 않도록 **기본 비활성** — 뒤에 시(H시)가 붙은 수식어로만 쓴다(§4-2 주).
  // (활성화는 향후 설정 플래그로. 여기서는 오검출 방지가 우선.)

  /// 과거 시제 신호(§3-3 1순위, §3-2 past_markers).
  ///
  /// 사용자 말투 ⑤: 과거형이면 기록. "~ㅁ" 명사형 과거("주문넣음/퇴근찍음/결제함")도
  /// 실제 발화에서 잦아 포함한다(오검출 위험이 낮은 구체 동사형만).
  static const List<String> _pastMarkers = [
    '했어', '했다', '끝냈어', '방금', '아까', '마쳤어', '했음',
    '넣음', '찍음', '출발함', '결제함', '나감', '들어옴', '썼어',
    '왔음', '갔음', '샀음', '봤음', '먹었음', '작업했다',
    // 지출·완료 실말투(§ 지금기록) — "냈어/냄/넣었어/마셨어/돌렸어/다녀왔어/드림/결제 …"
    '냈어', '냄', '넣었어', '마셨어', '돌렸어', '다녀왔어', '나갔어', '드림',
    '결제', '씀', '왔어', '갔어', '봤어', '줬어', '샀어',
  ];

  /// 양력 고정 공휴일·기념일 → (월, 일). 음력(설날·추석)은 매년 날짜가 달라
  /// 별도 로드맵(§13)으로 미룬다.
  static const Map<String, List<int>> _solarHolidays = {
    '신정': [1, 1], '삼일절': [3, 1], '어린이날': [5, 5], '현충일': [6, 6],
    '제헌절': [7, 17], '광복절': [8, 15], '개천절': [10, 3], '한글날': [10, 9],
    '크리스마스이브': [12, 24], '크리스마스': [12, 25], '성탄절': [12, 25],
  };

  /// 순우리말 수사 → 정수(시/일 공용, 0~12 상식선). 긴 표기 우선.
  static const Map<String, int> _nativeNum = {
    '열하나': 11, '열두': 12, '열둘': 12, '열한': 11,
    '다섯': 5, '여섯': 6, '일곱': 7, '여덟': 8, '아홉': 9, '하나': 1,
    '열': 10, '두': 2, '둘': 2, '세': 3, '셋': 3, '네': 4, '넷': 4, '한': 1,
  };

  // 정규식에 쓸 순우리말 수사 대안(긴 것부터).
  static const String _nn =
      '열하나|열두|열둘|열한|다섯|여섯|일곱|여덟|아홉|하나|열|두|둘|세|셋|네|넷|한';

  static final RegExp _reDurHour = RegExp(
      '($_nn|\\d+)\\s*시간(?:\\s*(반)|\\s*(\\d+)\\s*분)?\\s*(?:만|정도|쯤)?');
  static final RegExp _reClock = RegExp(
      '(?:(오전|새벽|아침|오후|점심|저녁|밤|낮)\\s*)?($_nn|\\d+)\\s*시(?!간)'
      '(?:\\s*(\\d+)\\s*분|\\s*(반))?(?:에서|에|쯤|경)?');
  static final RegExp _reDurMin = RegExp(r'(\d+)\s*분(?:만|정도|쯤)?');
  static final RegExp _reDaysLater =
      RegExp('($_nn|\\d+)\\s*일\\s*(?:뒤|후)(?:에)?');
  // 연도(사용자 말투: "29년/30년/내년"). 2자리는 2000년대로 본다.
  static final RegExp _reYear = RegExp(r'(내년|올해|작년)|(\d{2,4})\s*년');
  // "다음달/담달/이번달" 월 오프셋(뒤에 N일 이 올 때).
  static final RegExp _reMonthOffset = RegExp(r'(다음|담|낼)\s*달|이번\s*달');
  static final RegExp _reMonthDay = RegExp(r'(\d+)\s*월\s*(\d+)\s*일(?:날|에)?');
  static final RegExp _reWeekday = RegExp(
      r'(?:(이번|다음|담)\s*주\s*)?([월화수목금토일])요일(?:날|에)?');
  static final RegExp _reRelDay =
      RegExp(r'(낼모레|오늘|내일|모레|글피|어제|낼)(?:날|에)?');
  static final RegExp _reDayOfMonth =
      RegExp(r'(\d+)\s*일(?!\s*(?:뒤|후))(?:날|에)?');

  static const Map<String, int> _weekdayNum = {
    '월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7,
  };
  static const Set<String> _amWords = {'오전', '새벽', '아침'};

  TimeParseResult parse(String text, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final spans = <SpanRange>[];

    int? durationMin;
    ParsedTime? time;
    DateTime? date;
    var isPast = false;

    // --- 1) 기간(N시간) — 시계(N시)보다 먼저 소비 -------------------------
    for (final m in _reDurHour.allMatches(text)) {
      if (_overlaps(spans, m.start, m.end)) continue;
      final h = _num(m.group(1));
      if (h == null) continue;
      var mins = h * 60;
      if (m.group(2) != null) mins += 30; // 반
      if (m.group(3) != null) mins += int.parse(m.group(3)!);
      durationMin = mins;
      spans.add(SpanRange(m.start, m.end));
      break;
    }

    // --- 2) 시각(H시 [M분|반]) ------------------------------------------
    for (final m in _reClock.allMatches(text)) {
      if (_overlaps(spans, m.start, m.end)) continue;
      final h = _num(m.group(2));
      if (h == null) continue;
      final meridiem = m.group(1);
      final minute = m.group(3) != null
          ? int.parse(m.group(3)!)
          : (m.group(4) != null ? 30 : 0);
      time = ParsedTime(_to24(h, meridiem), minute);
      spans.add(SpanRange(m.start, m.end));
      break;
    }

    // --- 3) 기간(N분) — 시계 분이 아닌 것만 ------------------------------
    if (durationMin == null) {
      for (final m in _reDurMin.allMatches(text)) {
        if (_overlaps(spans, m.start, m.end)) continue;
        durationMin = int.parse(m.group(1)!);
        spans.add(SpanRange(m.start, m.end));
        break;
      }
    }

    // --- 3-5) 연도·월오프셋·공휴일 사전 처리 ------------------------------
    int? explicitYear; // 명시 연도(29년/내년 …). 있으면 롤오버 안 함.
    for (final m in _reYear.allMatches(text)) {
      if (_overlaps(spans, m.start, m.end)) continue;
      if (m.group(1) != null) {
        explicitYear = switch (m.group(1)) {
          '내년' => ref.year + 1,
          '작년' => ref.year - 1,
          _ => ref.year, // 올해
        };
      } else {
        final y = int.parse(m.group(2)!);
        explicitYear = y < 100 ? 2000 + y : y; // "29년" → 2029
      }
      spans.add(SpanRange(m.start, m.end));
      break;
    }

    int? monthOffset; // 0=이번달, 1=다음달 (뒤에 N일 이 올 때만 의미).
    for (final m in _reMonthOffset.allMatches(text)) {
      if (_overlaps(spans, m.start, m.end)) continue;
      monthOffset = m.group(1) != null ? 1 : 0; // (다음|담|낼)달 → +1, 이번달 → 0
      spans.add(SpanRange(m.start, m.end));
      break;
    }

    // 양력 공휴일명("광복절날") — 다른 날짜 규칙보다 우선.
    for (final entry in _solarHolidays.entries) {
      final i = text.indexOf(entry.key);
      if (i < 0) continue;
      var end = i + entry.key.length;
      if (end < text.length && text[end] == '날') end += 1; // "광복절날"
      if (_overlaps(spans, i, end)) continue;
      final y = explicitYear ?? ref.year;
      var cand = _safeDate(y, entry.value[0], entry.value[1]);
      if (cand != null && explicitYear == null && cand.isBefore(today)) {
        cand = _safeDate(y + 1, entry.value[0], entry.value[1]);
      }
      if (cand == null) continue;
      date = cand;
      spans.add(SpanRange(i, end));
      break;
    }

    // --- 4) 날짜 — 앞선 규칙이 이기고, 하나만 채운다 ---------------------
    for (final rule in <MapEntry<RegExp, DateTime? Function(RegExpMatch)>>[
      MapEntry(_reDaysLater, (m) {
        final n = _num(m.group(1));
        return n == null ? null : today.add(Duration(days: n));
      }),
      MapEntry(_reMonthDay, (m) {
        final mo = int.parse(m.group(1)!);
        final d = int.parse(m.group(2)!);
        final y = explicitYear ?? ref.year;
        var cand = _safeDate(y, mo, d);
        if (cand != null && explicitYear == null && cand.isBefore(today)) {
          cand = _safeDate(y + 1, mo, d);
        }
        return cand;
      }),
      MapEntry(_reWeekday, (m) {
        final target = _weekdayNum[m.group(2)]!;
        var ahead = ((target - today.weekday) % 7 + 7) % 7;
        if (m.group(1) != null) ahead += 7; // 다음주/담주
        return today.add(Duration(days: ahead));
      }),
      MapEntry(_reRelDay, (m) {
        return switch (m.group(1)) {
          '오늘' => today,
          '내일' || '낼' => today.add(const Duration(days: 1)),
          '모레' || '낼모레' => today.add(const Duration(days: 2)),
          '글피' => today.add(const Duration(days: 3)),
          '어제' => today.subtract(const Duration(days: 1)),
          _ => null,
        };
      }),
      MapEntry(_reDayOfMonth, (m) {
        final d = int.parse(m.group(1)!);
        final y = explicitYear ?? ref.year;
        final mo = ref.month + (monthOffset ?? 0);
        var cand = _safeDate(y, mo, d);
        if (cand != null &&
            explicitYear == null &&
            monthOffset == null &&
            cand.isBefore(today)) {
          cand = _safeDate(y, mo + 1, d);
        }
        return cand;
      }),
    ]) {
      if (date != null) break;
      for (final m in rule.key.allMatches(text)) {
        if (_overlaps(spans, m.start, m.end)) continue;
        final d = rule.value(m);
        if (d == null) continue;
        date = d;
        spans.add(SpanRange(m.start, m.end));
        break;
      }
    }

    // --- 5) 과거 시제 --------------------------------------------------
    if (_pastMarkers.any(text.contains)) isPast = true;
    if (date != null && date.isBefore(today)) isPast = true;
    // 과거 마커도 제목에서 걷어낸다(슬롯 정리용).
    for (final marker in _pastMarkers) {
      var from = 0;
      while (true) {
        final i = text.indexOf(marker, from);
        if (i < 0) break;
        if (!_overlaps(spans, i, i + marker.length)) {
          spans.add(SpanRange(i, i + marker.length));
        }
        from = i + marker.length;
      }
    }

    return TimeParseResult(
      date: date,
      time: time,
      durationMin: durationMin,
      isPast: isPast,
      matchedSpans: spans,
    );
  }

  // --------------------------------------------------------------- helpers

  int? _num(String? token) {
    if (token == null) return null;
    return int.tryParse(token) ?? _nativeNum[token];
  }

  /// 12시간제 → 24시간제 변환(§4-2).
  int _to24(int h, String? meridiem) {
    if (meridiem != null) {
      final am = _amWords.contains(meridiem);
      if (am) return h == 12 ? 0 : h % 12;
      return h == 12 ? 12 : (h % 12) + 12; // 오후/저녁/밤/낮/점심
    }
    // 표기 없음: 1~6시는 오후로 본다(3시→15:00).
    if (h == 0 || h == 12) return h;
    if (h >= 1 && h <= bareHourPmMax) return h + 12;
    return h;
  }

  DateTime? _safeDate(int y, int mo, int d) {
    var year = y;
    var month = mo;
    if (month > 12) {
      year += (month - 1) ~/ 12;
      month = (month - 1) % 12 + 1;
    }
    final result = DateTime(year, month, d);
    // 롤오버로 일자가 틀어지면(예: 2월 30일) 무효.
    if (result.month != month || result.day != d) return null;
    return result;
  }

  bool _overlaps(List<SpanRange> spans, int start, int end) {
    for (final s in spans) {
      if (start < s.end && s.start < end) return true;
    }
    return false;
  }
}
