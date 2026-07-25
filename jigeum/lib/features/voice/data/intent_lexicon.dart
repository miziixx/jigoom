/// 트리거 사전. 기획서 §3-2(키워드·패턴 사전) + §5 커밋5.
///
/// 규칙 엔진의 "연료"를 **코드가 아닌 데이터**로 분리한다. 사전만 늘리면(부록
/// 튜닝 노트) 분류기 코드 수정 없이 정확도가 오른다. 지금은 Dart 상수로 두되,
/// 이후 `assets/voice/lexicon.yaml` 로드로 바꿔도 분류기는 그대로다.
///
/// 프레임워크 비의존(순수 Dart) — 빠른 단위 테스트를 위해 유지한다.
library;

import '../models/intent_type.dart';

/// 트리거의 강도. 분류기가 가점량을 정할 때 참고한다(§3 점수제).
///
///  - [primary] : 그 인텐트를 대표하는 핵심 신호. 매칭 시 정상 가점(keyword).
///  - [co]      : 보조 신호. **primary 가 하나라도 잡힌 뒤에만** 가점(오검출 방지).
///                예) "추가/만들어" 는 홀로는 의미가 약해 primary 를 보강만 한다.
///  - [weak]    : 아주 약한 신호(+1). 확정은 못 시키지만 S>0 이 되어
///                "미인식(보류함)" 이 아니라 "애매(빠른담기 A)" 로 떨어지게 한다.
enum TriggerStrength { primary, co, weak }

/// §3-2 사전을 담는 순수 데이터 컨테이너.
class IntentLexicon {
  const IntentLexicon();

  /// 시제 신호 — 과거(§3-3 1순위). 파서도 참조하지만 사전 원본은 여기 둔다.
  static const List<String> pastMarkers = [
    '했어', '했다', '끝냈어', '방금', '아까', '마쳤어', '했음',
    // 지출·완료 말투(§ 지금기록) — "썼어/냈어/냄/넣었어/드림/결제/완료 …"
    '썼어', '씀', '냈어', '냄', '넣었어', '마셨어', '돌렸어', '다녀왔어',
    '나갔어', '드림', '결제', '왔어', '갔어', '봤어', '줬어', '샀어',
  ];

  /// 행동형 명사구 꼬리 — 트리거가 없어도 이런 어미로 끝나면 '할일'로 보고
  /// 빠른담기(A)에 안착("베란다 정리/사진 백업/운동화 세탁"). 명사형 어미 '~기'
  /// 는 분류기에서 별도 처리한다.
  static const List<String> actionEndings = [
    '정리', '청소', '백업', '주문', '반납', '충전', '교체', '세탁', '수선',
    '확인', '점검', '준비', '세차', '분갈이', '빨래', '접수', '정돈', '수거', '환기',
  ];

  /// 'someday(언젠가·나중에)' 신호. 이게 있으면 트리거 없는 명사구라도
  /// 빠른담기 폴백을 태우지 않고 보류함(언젠가함)에 그대로 둔다.
  static const List<String> somedayMarkers = [
    '언젠가', '나중', '여유되면', '시간되면',
  ];

  /// 의도 어미 — 미래/추가형(§3-2 future_markers). 이미 잡힌 추가형 인텐트를
  /// 소폭 보강한다(단독으로 인텐트를 만들지는 않음).
  static const List<String> futureMarkers = [
    '할래', '하자', '해야', '예정', '잡아', '넣어줘', '만들어',
  ];

  /// 담기·기입 동사(사용자 말투 ③ "~줘/~놔/~바"). "적어줘/추가해줘/넣어놔" 처럼
  /// 무언가를 **등록**하려는 신호. 단독이면 할일(A)로 약하게, 날짜와 함께면
  /// 일정(C)으로 강하게 끈다(분류기에서 처리). 제목에서는 걷어낸다.
  static const List<String> addVerbs = [
    '적어줘', '적어놔', '적어주고', '써줘', '써놔',
    '추가해줘', '추가하고', '추가', '넣어줘', '넣어놔', '넣어놓', '넣고', '넣어',
    '메모해줘', '메모', '기록해줘', '걸어줘', '띄워줘', '등록',
  ];

  /// "이동·도움" 계열(§3-3 6번) — 추가형과 겹치지 않는 독립 명령. 트리거가
  /// 하나만 맞아도 강신호로 본다.
  static const Set<IntentType> commandIntents = {
    IntentType.navMove,
    IntentType.helpStuck,
    IntentType.helpFortune,
  };

  /// 인텐트별 핵심 트리거(§3-2). 매칭되면 정상 가점.
  static const Map<IntentType, List<String>> primary = {
    IntentType.scheduleAdd: ['예약', '미팅', '약속', '회의', '모임', '병원', '치과'],
    // todo.add 는 §3-2 에 별도 목록이 없다(A 는 폴백 지점). "할 일로 담아줘" 류의
    // 명시적 담기 표현만 primary 로 둔다.
    IntentType.todoAdd: ['할일', '할 일', '투두', '담아', '담아줘', '리스트', '목록'],
    IntentType.todoMatrix: [
      '중요', '급해', '급함', '급하', '긴급', '당장', '오늘까지', '오늘 안',
      '빨리', '임박', '필수', '필요', '코앞', '연체', '마지막날', '얼마 안남',
      '지금 바로'
    ],
    IntentType.logNow: ['기록'],
    IntentType.habitAdd: ['습관', '매일', '매주', '매달', '격일', '꾸준히'],
    // habit.check — 명시적 체크·완료 동사(§11-2 등록 습관명 대조는 분류기가 별도로).
    IntentType.habitCheck: [
      '체크', '틱', '채웠어', '채워줘', '채워', '다했어', '성공'
    ],
    IntentType.routineAdd: ['루틴', '아침루틴', '저녁루틴'],
    IntentType.goalAdd: ['목표'],
    // goal.today 의 "오늘 목표" 근접은 분류기가 특례로 처리(§3-3 5). 여기엔
    // 단독으로 쓰는 표현만.
    IntentType.goalToday: ['오늘은'],
    IntentType.focusStart: ['집중', '몰입', '타이머'],
    IntentType.navMove: ['보여줘', '열어줘', '가자', '이동', '화면', '달력'],
    IntentType.helpStuck: ['막혔어', '못하겠어', '안돼', '하기싫어', '미루고싶어'],
    IntentType.helpFortune: ['운세', '사주', '오늘 운', '별자리'],
  };

  /// 보조 트리거 — 해당 인텐트의 primary 가 먼저 잡혀야 가점(§3-2 "+만들어/추가").
  static const Map<IntentType, List<String>> co = {
    IntentType.habitAdd: ['만들어', '추가', '만들기'],
    IntentType.routineAdd: ['스텝', '추가'],
    IntentType.goalAdd: ['세울래', '세우자', '하고싶어', '이루고싶어'],
    IntentType.todoAdd: ['넣어줘', '담아줘'],
  };

  /// 약신호 — 홀로는 확정 못 하지만 S>0 을 만들어 **빠른담기(A)** 로 안착시킨다.
  /// (§8 "파란색 그거 처리" → 미인식(보류함)이 아니라 애매(A) 여야 함)
  static const Map<IntentType, List<String>> weak = {
    IntentType.todoAdd: ['처리', '해줘', '해결', '정리'],
    // 미래 예정 지출/이체(§ 일정) — "다음달 5일 통신비 빠져/빠지는거/자동이체".
    // 과거 지출("빠져나감")은 pastMarkers(나감)로 logNow 가 이기므로 안전.
    IntentType.scheduleAdd: ['빠져', '빠지는거', '나가는거', '들어가는거', '자동이체'],
  };

  /// 제목/내용에서 걷어낼 구조어(인텐트별). 파서가 시간부를 잘라낸 **뒤**,
  /// 슬롯 추출기가 이 목록으로 남은 구조어를 제거해 순수 제목만 남긴다.
  ///
  /// 주의: primary 전체를 지우면 안 된다(예: schedule 의 "치과" 는 제목이다).
  /// 실제로 잘라낼 "동작어"만 최소로 둔다.
  static const Map<IntentType, List<String>> stripWords = {
    IntentType.scheduleAdd: ['예약', '잡아줘', '잡아'],
    IntentType.todoAdd: ['할 일로', '할일로', '할 일', '할일', '넣어줘', '넣어', '담아줘', '담아', '투두', '리스트', '목록'],
    IntentType.todoMatrix: ['중요', '급해', '긴급', '당장', '오늘까지', '빨리', '이거', '이것', '그거', '그것'],
    IntentType.logNow: ['기록', '했어', '방금', '아까'],
    IntentType.habitAdd: ['습관', '매일', '꾸준히', '만들어', '만들기', '추가'],
    IntentType.habitCheck: ['습관에', '습관', '체크해줘', '체크', '틱', '채웠어', '다했어', '성공', '해줘'],
    IntentType.routineAdd: ['루틴에', '루틴', '스텝', '추가'],
    IntentType.goalAdd: ['목표', '세울래', '세우자', '하고싶어', '이루고싶어'],
    IntentType.goalToday: ['오늘은', '오늘', '목표는', '목표'],
    IntentType.focusStart: ['집중', '몰입', '타이머', '할래'],
  };
}
