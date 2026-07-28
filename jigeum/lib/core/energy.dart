/// 에너지 사이클 — 완료·집중 시각의 분포에서 "집중 피크" 시간대를 추정.
/// 사주의 運氣(때가 있다)를 실제 행동 데이터로 근사한다. 규칙·판단 없음, 힌트만.

/// 시(hour) 표본들에서 가장 활동적인 연속 2시간 창.
/// 표본이 [minSamples] 미만이면 성급한 추정을 피해 null.
({int startHour, int endHour, int count})? peakWindow(
  List<int> hours, {
  int minSamples = 8,
}) {
  if (hours.length < minSamples) return null;
  final bins = List<int>.filled(24, 0);
  for (final h in hours) {
    if (h >= 0 && h < 24) bins[h]++;
  }
  var best = -1;
  var bestStart = 9;
  for (var h = 0; h < 24; h++) {
    final sum = bins[h] + bins[(h + 1) % 24];
    if (sum > best) {
      best = sum;
      bestStart = h;
    }
  }
  // 피크가 실질적으로 없으면(전부 0에 가깝게 평평) null 취급.
  if (best <= 1) return null;
  return (startHour: bestStart, endHour: (bestStart + 2) % 24, count: best);
}

/// 시(0~23) → '오전/오후 h시' 한글 라벨.
String hourLabel(int h) {
  final ampm = h < 12 ? '오전' : '오후';
  var hh = h % 12;
  if (hh == 0) hh = 12;
  return '$ampm $hh시';
}

/// 피크 창을 한 줄로: "오후 2시–4시".
String peakLabel(int startHour, int endHour) =>
    '${hourLabel(startHour)}–${hourLabel(endHour)}';

/// 시간대 이름(코치 문구·컨텍스트 알림용).
String partOfDay(int hour) {
  if (hour < 5) return '새벽';
  if (hour < 11) return '아침';
  if (hour < 14) return '낮';
  if (hour < 18) return '오후';
  if (hour < 22) return '저녁';
  return '밤';
}
