/// 음성 라우팅 규칙 엔진의 튜닝 상수.
///
/// 기획서 §2(세 갈래 임계값)·§2-1(시간단서 가점)·§3-3(충돌해소 가점)의
/// 숫자를 **한 곳에 모아** 코드 수정 없이 조정할 수 있게 한다. 초기값은 기획서와
/// 동일하다. (부록 튜닝 노트 참조)
library;

/// 라우팅 결정 임계값(§2).
class VoiceThresholds {
  const VoiceThresholds._();

  /// 확정 라우팅 최소 점수 S. 이 미만이면 빠른담기(A)로 폴백. (기획서 CONFIRM=3)
  static const int confirm = 3;

  /// 확정에 필요한 1·2등 최소 격차 D. (기획서 D>=1)
  static const int minGap = 1;
}

/// 규칙 가점표. 단서가 맞을 때마다 해당 인텐트 점수에 더한다.
class VoiceScores {
  const VoiceScores._();

  // --- §2-1 시간 단서 가점 -------------------------------------------------

  /// 미래 날짜 + 시각(예: 내일 3시) → schedule.add.
  static const int futureDateTime = 3;

  /// 미래 날짜만(예: 금요일) → schedule.add.
  static const int futureDateOnly = 2;

  /// 미래 날짜만 → todo.add 에도 마감일 후보로 소폭 가점.
  static const int futureDateTodoBonus = 1;

  /// 기간만(예: 25분) → focus.start / log.now (동사에 따라 갈림).
  static const int durationClue = 2;

  /// 과거 시제(예: 방금/했어) → log.now.
  static const int pastTense = 3;

  // --- §3-3 키워드/충돌해소 가점 -------------------------------------------

  /// 인텐트 트리거 사전 키워드 1건 매칭.
  static const int keyword = 2;

  /// 강신호(중요·긴급 형용사, 시간+시각 조합 등) 충돌해소 가점.
  static const int strongSignal = 3;

  /// 미래 의도 어미(할래/하자/넣어줘 등) 약가점 — 추가형 전반.
  static const int futureMarker = 1;

  /// §11-1 개인화 사전(반복 교정으로 학습된 표현) 매칭 가점.
  static const int userLexicon = 2;
}
