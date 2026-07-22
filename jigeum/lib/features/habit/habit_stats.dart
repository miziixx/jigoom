/// 습관 분석의 순수 계산 함수들 (Flutter 비의존 → 유닛테스트 가능).
///
/// 스트릭 계열(현재/최장 연속)은 "실패"를 벌하는 성격이 있어, ADHD 사용자에게
/// 부담이 될 수 있다. 그래서 [returnCount]("끊겨도 다시 온 횟수")를 병행 지표로
/// 두어, 완벽한 연속이 아니어도 다시 돌아온 것을 긍정적으로 세도록 한다.
library;

/// 오늘부터 거꾸로 연속 완료 일수.
int currentStreak(Set<DateTime> ticks, DateTime today) {
  var s = 0;
  var d = today;
  while (ticks.contains(d)) {
    s++;
    d = d.subtract(const Duration(days: 1));
  }
  return s;
}

/// start~today 중 최장 연속.
int longestStreak(Set<DateTime> ticks, DateTime start, DateTime today) {
  var best = 0, run = 0;
  var d = start;
  while (!d.isAfter(today)) {
    if (ticks.contains(d)) {
      run++;
      if (run > best) best = run;
    } else {
      run = 0;
    }
    d = d.add(const Duration(days: 1));
  }
  return best;
}

/// 복귀 점수: 끊긴 뒤(공백) 다시 시작한 횟수. 첫 시작은 복귀가 아니라 제외.
/// = 실행 구간(run)의 시작 개수 - 1 (구간이 하나도 없으면 0).
int returnCount(Set<DateTime> ticks, DateTime start, DateTime today) {
  var starts = 0;
  var d = start;
  while (!d.isAfter(today)) {
    if (ticks.contains(d) &&
        !ticks.contains(d.subtract(const Duration(days: 1)))) {
      starts++;
    }
    d = d.add(const Duration(days: 1));
  }
  return starts > 0 ? starts - 1 : 0;
}

/// 최근 [window]일 중 실행한 날 수 (오늘 포함).
int recentActiveDays(Set<DateTime> ticks, DateTime today, {int window = 7}) {
  var c = 0;
  for (var i = 0; i < window; i++) {
    if (ticks.contains(today.subtract(Duration(days: i)))) c++;
  }
  return c;
}
