/// 음성 라우팅 인텐트 타입과 라우팅 대상 지점.
///
/// 기획서 §3-1(인텐트 목록)과 §2(세 갈래 라우팅)에 대응한다. 이 파일은
/// 커밋1(뼈대) 단계로 **로직 없이 타입 정의만** 담는다. 실제 점수 계산은
/// 커밋6(IntentClassifier), 라우팅 실행은 커밋8(VoiceRouter)에서 붙는다.
library;

/// 규칙 엔진이 분류하는 인텐트. AI 없이 §3-2 사전 + §3-3 충돌해소로 판정한다.
///
/// [none] 은 아무 단서도 못 잡은 상태(S==0) — 라우터가 원문을 보류함에 넣는다.
enum IntentType {
  /// 일정추가 → C 일정. 날짜·시각·제목.
  scheduleAdd('schedule.add'),

  /// 할일추가 → A 빠른담기. 제목·(마감날짜).
  todoAdd('todo.add'),

  /// 매트릭스 → B. 제목·중요·긴급.
  todoMatrix('todo.matrix'),

  /// 지금기록 → D. 현재 30분 블록 내용.
  logNow('log.now'),

  /// 습관추가 → E. 이름.
  habitAdd('habit.add'),

  /// 습관틱(체크) → E. 대상 습관명.
  habitCheck('habit.check'),

  /// 루틴추가 → F. 그룹명·스텝.
  routineAdd('routine.add'),

  /// 목표추가 → G. 제목.
  goalAdd('goal.add'),

  /// 오늘의목표 → I. 텍스트.
  goalToday('goal.today'),

  /// 포커스 시작 → J. 분.
  focusStart('focus.start'),

  /// 화면 이동. 목적지.
  navMove('nav.move'),

  /// 막힘 도움 시트.
  helpStuck('help.stuck'),

  /// 운세(드로어 02).
  helpFortune('help.fortune'),

  /// 미인식(S==0). 원문 그대로 보류함으로.
  none('none');

  const IntentType(this.code);

  /// 기획서 표기 코드(예: `schedule.add`). 로그·사용자사전 키로 쓴다.
  final String code;

  /// 사용자 개입 없이 새 엔티티를 만드는 "추가형" 인텐트인지. (§3-1 계열)
  bool get isAdditive => switch (this) {
        IntentType.scheduleAdd ||
        IntentType.todoAdd ||
        IntentType.todoMatrix ||
        IntentType.logNow ||
        IntentType.habitAdd ||
        IntentType.habitCheck ||
        IntentType.routineAdd ||
        IntentType.goalAdd ||
        IntentType.goalToday ||
        IntentType.focusStart =>
          true,
        _ => false,
      };
}

/// 인텐트가 최종 착지하는 입력 지점(A~J) 또는 특수 목적지.
///
/// 기획서는 A~J 를 쓰되 H 는 비어있다. [inbox]/[quickCapture] 는 §2 세 갈래 중
/// 안전망(보류함·빠른담기)에 해당한다.
enum RoutePoint {
  /// A 빠른담기. (todo.add + "애매" 폴백 목적지)
  quickCapture('A', '빠른담기'),

  /// B 매트릭스.
  matrix('B', '매트릭스'),

  /// C 일정.
  schedule('C', '일정'),

  /// D 지금기록.
  logNow('D', '지금기록'),

  /// E 습관.
  habit('E', '습관'),

  /// F 루틴.
  routine('F', '루틴'),

  /// G 목표.
  goal('G', '목표'),

  /// I 오늘의목표.
  goalToday('I', '오늘의목표'),

  /// J 포커스.
  focus('J', '포커스'),

  /// 화면 전환(달력·습관 등).
  nav('-', '이동'),

  /// 막힘 시트.
  helpStuck('-', '막힘'),

  /// 운세 드로어.
  helpFortune('-', '운세'),

  /// 보류함(미인식 안전망).
  inbox('-', '보류함');

  const RoutePoint(this.letter, this.label);

  /// 입력지점 문자(A~J) 또는 특수 목적지는 `-`.
  final String letter;

  /// 사용자에게 보이는 한글 라벨(확정 스낵바 "○○에 담았어요"에 사용).
  final String label;
}

/// 인텐트의 기본 라우팅 지점(§3-1 표). [IntentType.none] 은 보류함.
///
/// "애매" 폴백(빠른담기)은 라우터가 점수로 판단하므로 여기 매핑과 무관하다.
RoutePoint defaultRoutePointOf(IntentType intent) => switch (intent) {
      IntentType.scheduleAdd => RoutePoint.schedule,
      IntentType.todoAdd => RoutePoint.quickCapture,
      IntentType.todoMatrix => RoutePoint.matrix,
      IntentType.logNow => RoutePoint.logNow,
      IntentType.habitAdd => RoutePoint.habit,
      IntentType.habitCheck => RoutePoint.habit,
      IntentType.routineAdd => RoutePoint.routine,
      IntentType.goalAdd => RoutePoint.goal,
      IntentType.goalToday => RoutePoint.goalToday,
      IntentType.focusStart => RoutePoint.focus,
      IntentType.navMove => RoutePoint.nav,
      IntentType.helpStuck => RoutePoint.helpStuck,
      IntentType.helpFortune => RoutePoint.helpFortune,
      IntentType.none => RoutePoint.inbox,
    };
