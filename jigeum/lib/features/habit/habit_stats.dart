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

/// 습관 여정 마일스톤의 성격.
enum HabitMilestoneKind { start, reached, current, upcoming }

/// 습관 여정 타임라인 한 노드.
class HabitMilestone {
  const HabitMilestone(this.label, this.kind, {this.date, this.streak = 0});
  final String label;
  final HabitMilestoneKind kind;
  final DateTime? date; // upcoming(예정)이면 null
  final int streak; // 임계값 또는 현재 연속
}

/// 연속 임계값(의미 있는 마일스톤만 — 매일의 모든 체크를 노드로 만들지 않는다).
const List<int> kHabitStreakMilestones = [3, 7, 14, 30, 60, 100];

/// 틱에서 습관 여정 마일스톤을 파생한다(순수·테스트 가능, 새 테이블 불필요).
///
/// [start]=습관 생성일, [today]=오늘. 반환: 시작 → 달성한 연속 임계값(최초
/// 도달일 순) → 현재 연속(진행 중) → 다음 목표(예정). 시간대 안전을 위해 모두
/// 로컬 '날짜' 단위(dateOnly)로 비교한다고 가정한다.
List<HabitMilestone> habitMilestones(
    Set<DateTime> ticks, DateTime start, DateTime today) {
  final out = <HabitMilestone>[
    HabitMilestone('습관 시작', HabitMilestoneKind.start, date: start),
  ];

  // 각 임계값을 '처음' 도달한 날짜를 스캔.
  final reachedOn = <int, DateTime>{};
  var run = 0;
  var d = start;
  while (!d.isAfter(today)) {
    if (ticks.contains(d)) {
      run++;
      for (final m in kHabitStreakMilestones) {
        if (run == m && !reachedOn.containsKey(m)) reachedOn[m] = d;
      }
    } else {
      run = 0;
    }
    d = d.add(const Duration(days: 1));
  }
  final reached = reachedOn.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  for (final e in reached) {
    out.add(HabitMilestone('${e.key}일 연속 달성', HabitMilestoneKind.reached,
        date: e.value, streak: e.key));
  }

  final cur = currentStreak(ticks, today);
  if (cur > 0) {
    out.add(HabitMilestone('현재 $cur일 연속', HabitMilestoneKind.current,
        date: today, streak: cur));
  }

  // 다음 목표 = 현재 연속보다 큰 가장 작은 임계값.
  final next = kHabitStreakMilestones.where((m) => m > cur).cast<int?>().firstWhere(
        (m) => true,
        orElse: () => null,
      );
  if (next != null) {
    out.add(HabitMilestone('$next일 연속', HabitMilestoneKind.upcoming, streak: next));
  }
  return out;
}
