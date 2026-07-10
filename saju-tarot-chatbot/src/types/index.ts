export type ReadingType = "saju" | "tarot" | "combo" | "today" | "flow";

/** 해석 포커스: 전반 / 직업·돈 / 연애·관계 / 건강·컨디션 / 멘탈·감정 / 선택·시기 고민 */
export type ReadingFocus = "general" | "career" | "relationship" | "wellness" | "mental" | "decision";

// ── 리딩 전 개인화 질문 (입력 정제) ──────────

/** 현재 상황 단계 */
export type SituationStage = "before" | "ongoing" | "waiting" | "closing";

/** 원하는 답변 톤 */
export type AnswerTone = "realistic" | "warm" | "blunt" | "detailed" | "action";

/** 원하는 해석 깊이. 기본은 depth 미지정(undefined)으로 표현하고, 고급만 별도 값을 가진다. */
export type AnswerDepth = "advanced";

/** 출생 시간 정확도 (신뢰도 계산에 반영) */
export type BirthTimeAccuracy = "exact" | "half-hour" | "over-hour" | "unknown";

/**
 * 완전분석 모드. 표준 섹션 대신 전용 출력 구조를 쓴다.
 * 새 depth/ReadingType를 늘리지 않고 기존 saju 파이프라인 위에 얹기 위한 플래그.
 * - selfDeep: 자기 완전분석(12블록 심층 리포트).
 * - personDeep: 상대 완전분석(상대 작동방식 16항목 해부). 주체=상대(B), 나(A)는 counterpart 근거로 주입.
 * - topicDeep: 토픽 심화(재기획안 §3·§8) — 연애/재물/직업/건강/올해 중 하나만 짧게 심화한다. topic 필드로 지정.
 */
export type AnalysisMode = "selfDeep" | "personDeep" | "topicDeep";

/**
 * 토픽 심화(topicDeep) 대상 분야. JudgmentPack의 JudgmentDomain(love/money/career/health/year)과
 * 1:1로 대응한다 — 새 판단 로직 없이 이미 계산된 judgments를 분야로 골라 문장화만 한다(§3).
 */
export type TopicDeepTopic = "love" | "money" | "career" | "health" | "year";

/** 자기 완전분석용 행동 체크(선택). 전부 자유입력, 계산에는 영향 없음(해석 정확도 보조). */
export interface SelfBehaviorCheck {
  /** 최근 2주 가장 많이 한 생각 */
  recentThought?: string;
  /** 요즘 제일 미루는 일 */
  procrastinating?: string;
  /** 화날 때 바로 말하는 편인지 */
  angerStyle?: string;
  /** 서운하면 어떻게 하는지 */
  hurtStyle?: string;
  /** 돈 쓸 때 감정 */
  moneyFeeling?: string;
  /** 지치면 사람을 만나는지 숨는지 */
  tiredStyle?: string;
}

/** 상대 완전분석용 행동 체크(선택). 전부 자유입력, 계산에는 영향 없음(해석 정확도·말행동 대조 보조). */
export interface PartnerBehaviorCheck {
  /** 연락은 주로 누가 먼저 하는지 */
  whoContacts?: string;
  /** 직접 만날 때 vs 카톡·문자일 때 태도 차이 */
  onlineOfflineGap?: string;
  /** 약속을 먼저 잡는 편인지 */
  makesPlans?: string;
  /** 말과 행동이 일치하는 편인지 */
  wordsMatchActions?: string;
  /** 관계를 주변에 공개하는지 */
  publicness?: string;
  /** 알게 된 기간 */
  knownDuration?: string;
  /** 최근 분위기 */
  recentMood?: string;
}

export interface ReadingContext {
  situation?: SituationStage;
  tone?: AnswerTone;
  depth?: AnswerDepth;
  timeAccuracy?: BirthTimeAccuracy;
  /** 상담형 판단 입력: 현재 고민 분야 */
  concernArea?: string;
  /** 상담형 판단 입력: 사용자가 실제로 고민 중인 선택지 */
  optionsText?: string;
  /** 상담형 판단 입력: 최근 1~3개월 사이 실제로 있었던 일 */
  recentContext?: string;
  /** 상담형 판단 입력: 사용자가 가장 두려워하는 결과 */
  fearPoint?: string;
  /** 지난 리딩 피드백에서 뽑은 스타일 조정 요청 (사용자가 반영에 동의했을 때만 채워짐) */
  styleHint?: string;
  /** 과거 검증 입력: 실제로 있었던 과거 사건들 (해석 신뢰도 보정용) */
  pastEvents?: PastEvent[];
  /** 완전분석 모드 (표준 섹션 대신 전용 출력 구조 사용) */
  analysisMode?: AnalysisMode;
  /** analysisMode가 "topicDeep"일 때만 사용: 심화할 토픽 하나 */
  topic?: TopicDeepTopic;
  /** 자기 완전분석용 행동 체크 (선택, 계산 불변) */
  selfCheck?: SelfBehaviorCheck;
  /** 상대 완전분석용 행동 체크 (선택, 계산 불변) */
  partnerCheck?: PartnerBehaviorCheck;
  /**
   * 상대 완전분석(personDeep) 전용: 나(A) 원국을 상대(B) 리딩에 부가 근거로 넣기 위해
   * 클라이언트(CompatibilityPage)에서 미리 조립한 근거 블록. buildPersonDeepEvidence 결과 문자열.
   */
  counterpart?: string;
}

// ── 과거 검증 (실제 과거 사건 → 계산 흐름 부합도 → 해석 신뢰도 보정) ──────────

/** 사용자가 입력한 과거 사건 하나 */
export interface PastEvent {
  /** 사건이 있었던 연도 (양력) */
  year: number;
  /** 사건 분야 (사건화 엔진과 동일한 분야 키) */
  domain: LifeDomain;
  /** 사용자가 적은 짧은 설명 (선택) */
  note?: string;
}

/** 과거 사건 하나에 대한 계산 데이터 (saju.ts에서 lunar로 계산, 순수 값) */
export interface PastEventCalibrationInput {
  year: number;
  domain: LifeDomain;
  note?: string;
  /** 그 해 세운 간지 (입춘 기준) */
  yearGanZhi: string;
  /** 그 시기 대운 간지 (없으면 null) */
  daYunGanZhi: string | null;
  /** 그 해 세운·대운이 원국과 맺는 합충형파해 (사람이 읽는 문자열) */
  interactions: string[];
}

/** 과거 사건 한 건의 부합도 판정 결과 */
export interface PastEventMatch {
  year: number;
  domain: LifeDomain;
  domainLabel: string;
  note?: string;
  /** strong=계산 흐름과 잘 맞음, partial=일부 맞음, weak=계산상 뚜렷한 신호 없음 */
  level: "strong" | "partial" | "weak";
  /** 쉬운 말 설명 */
  summary: string;
  /** 전문가 근거 (세운/대운 십성·상호작용) */
  evidence: string[];
}

/** 과거 검증 종합 결과 */
export interface PastValidationReport {
  matches: PastEventMatch[];
  /** 전체 부합 경향 한 줄 */
  headline: string;
  /** 잘 맞은 분야 키 (이 축은 해석에서 더 신뢰) */
  reliableDomains: LifeDomain[];
}

// ── 소름 엔진 (C-1, 재기획안 §7 — pastValidation의 반대 방향) ──────────

/** 특정 분야 없이, 연도 하나의 세운·대운 간지와 원국 상호작용만 계산한 순수 값 (saju.ts 산출) */
export interface PastYearRawSignal {
  year: number;
  yearGanZhi: string;
  daYunGanZhi: string | null;
  interactions: string[];
}

/** 소름 엔진이 사용자 확인 전에 먼저 제시하는 과거 추정 하나 */
export interface GoosebumpGuess {
  year: number;
  domain: LifeDomain;
  domainLabel: string;
  /** "2023년 무렵, 일·거처에 큰 변화의 흐름 — 맞나요?" 형태의 쉬운 말 문장 */
  prompt: string;
  /** 근거 강도(정렬용, 사용자에게는 노출하지 않음) */
  strength: number;
  /** 전문가 근거 (세운/대운 십성·상호작용) */
  evidence: string[];
}

/** 소름 엔진 종합 결과 — 확신 없는 해는 아예 포함하지 않는다(§7: "빗나감 1개가 적중 3개를 지운다") */
export interface GoosebumpReport {
  guesses: GoosebumpGuess[];
}

export type GoosebumpAnswer = "yes" | "no" | "unsure";

/** 사용자가 하나의 소름 추정에 응답한 기록 (로컬 저장, caseValidation 축적용) */
export interface GoosebumpConfirmation {
  guess: GoosebumpGuess;
  answer: GoosebumpAnswer;
  answeredAt: string;
}

// ── 사주·자미두수 교차검증 ──────────

export type CrossValidationLevel = "강일치" | "부분일치" | "불일치";

export interface CrossValidationMatch {
  domain: string;
  label: string;
  level: CrossValidationLevel;
  /** 사주 쪽 판정 (좋음/보통/주의) */
  sajuTone: string;
  /** 자미두수 쪽 판정 (좋음/보통/주의) */
  ziweiTone: string;
  /** 쉬운 말 요지 */
  summary: string;
  /** 전문가 근거 (사주 흐름 + 자미두수 궁·별) */
  evidence: string[];
}

export interface CrossValidationReport {
  /** 전체 일치 경향 한 줄 */
  headline: string;
  /** 강일치 비율 0-100 (두 방식이 같은 방향인 정도) */
  agreementScore: number;
  matches: CrossValidationMatch[];
  /**
   * 운한 대조 축 (엔진 업그레이드 Z-4): 사주 종합 흐름(대운·세운 반영) ↔ 자미두수 올해(유년) 흐름의
   * 분야별 방향 대조. 자미 운한이 계산됐을 때만. 기존 matches(원식 대조)와 별도 필드로 둔다.
   */
  luckMatches?: CrossValidationMatch[];
  /** 운한 대조 한 줄 요지 (luckMatches가 있을 때만) */
  luckHeadline?: string;
}

// ── 리딩 후 피드백 ──────────

export type FeedbackRating = "accurate" | "partial" | "unsure" | "inaccurate";

export interface ReadingFeedback {
  rating: FeedbackRating;
  /** 세부 태그: too-abstract / want-specific / good-advice / hard-to-understand */
  tags?: string[];
  createdAt: string;
}

export type CalendarType = "solar" | "lunar";

export type Gender = "female" | "male";

/** 야자시(23:00~24:00) 처리 방식: 당일 일주 유지(야자시) vs 다음날 일주(조자시) */
export type LateNightZiMode = "late" | "early";

export interface BirthInfo {
  /** 선택 입력: 결과지와 저장 파일에 표시할 이름 */
  displayName?: string;
  calendarType: CalendarType;
  year: number;
  month: number;
  day: number;
  /** 0-23, 시간을 모르면 null */
  hour: number | null;
  /** 0-59, 생략 시 0 */
  minute?: number;
  /** 음력 윤달 여부 (calendarType === "lunar"일 때만 의미 있음) */
  isLeapMonth?: boolean;
  /** 23~24시 출생 시 자시 처리 방식. 기본 "late"(야자시=당일 일주 유지) */
  lateNightZi?: LateNightZiMode;
  /** 출생지 키 (진태양시 보정용). "none"이면 보정 안 함 */
  birthPlace?: string;
  gender: Gender;
}

export interface TimeCorrection {
  /** 적용된 보정 설명 (예: "서울 경도 보정 -32분, 서머타임 -60분") */
  applied: string[];
  /** 보정 후 시각 (예: "1988-07-15 13:28") */
  correctedDateTime: string;
  /** 시주 경계(홀수시) 근처 출생 경고 */
  boundaryWarning: string | null;
}

export interface CalculationBasis {
  /** 23시대 출생의 일주 처리 기준 */
  lateNightZi?: LateNightZiMode;
  /** 입력한 시간이 23:00~23:59에 해당하는지 */
  isLateNightZiHour: boolean;
  /** 사용자 입력 시각 라벨 */
  inputTimeLabel: string | null;
}

export interface FiveElementBalance {
  wood: number;
  fire: number;
  earth: number;
  metal: number;
  water: number;
}

export interface SajuPillar {
  gan: string;
  zhi: string;
  ganZhi: string;
}

export interface StrengthAssessment {
  /** 일간을 돕는 세력 점수 (비겁+인성) */
  supportScore: number;
  /** 전체 점수 */
  totalScore: number;
  label: "신강" | "중화" | "신약";
  /** 득령(월지가 일간을 돕는지) 여부 등 판정 근거 */
  detail: string;
}

export interface YongshinCandidates {
  /** 용신/희신 후보 오행 (supportive = 용신+희신 합친 목록, 하위호환) */
  supportive: string[];
  /** 기신 후보 오행 */
  unfavorable: string[];
  /** 판정 방법과 한계 설명 */
  note: string;
  /** 1차 용신 후보 오행 */
  yongshin?: string[];
  /** 2차 희신 후보 오행 (용신을 돕는 오행) */
  heesin?: string[];
  /** 조후용신 (계절 조화: 겨울생→화, 여름생→수 등). 없으면 null */
  climatic?: { element: string; note: string } | null;
  /** 궁통보감(窮通寶鑑) 일간×월지 조후 정밀 판정. 없으면 null */
  climaticClassic?: ClimaticClassicInfo | null;
  /** 통관용신 (강하게 대립하는 두 오행 사이를 잇는 오행). 없으면 null */
  mediating?: { element: string; note: string } | null;
  /** 적용한 관법 요약 (예: "억부 중심 + 조후 보정") */
  method?: string;
}

/** 궁통보감(窮通寶鑑) 조후용신: 일간×월지별 우선순위 조후 천간 판정 */
export interface ClimaticClassicInfo {
  /** 우선순위 순서의 조후용신 천간 (예: ["계","정","경"] = 계수 우선 → 정화 → 경금) */
  priorityStems: string[];
  /** priorityStems를 오행으로 환산한 목록 (중복 제거, 우선순위 유지) */
  priorityElements: string[];
  /** 원국(천간+지장간)에 실제로 있는 우선 천간 */
  presentStems: string[];
  /** 원국에 없어 보완이 필요한 우선 천간 */
  missingStems: string[];
  /** 1순위 조후용신의 오행 */
  primaryElement: string;
  /** 1순위 조후용신(또는 그 오행)이 원국에 갖춰졌는지 */
  satisfied: boolean;
  /** 쉬운 말 설명 */
  note: string;
  /** 근거 고전 */
  source: "궁통보감";
}

/** 천간 하나의 통근(通根) 판정 — 그 천간 오행이 지지 지장간에 뿌리를 두는지 */
export interface RootednessHit {
  /** 천간 */
  gan: string;
  /** 천간 위치 (예: "일간") */
  position: string;
  /** 통근한 지지들 */
  roots: Array<{
    /** 지지 (예: "인") */
    zhi: string;
    /** 지지 위치 (예: "월지") */
    zhiPosition: string;
    /** 뿌리가 된 지장간 글자 */
    via: string;
    /** 지장간 내 위치 강도 */
    strength: "정기" | "중기" | "여기";
  }>;
  /** 뿌리가 하나라도 있는지 */
  rooted: boolean;
  /** 쉬운 말 설명 */
  note: string;
}

/** 투출(投出) 판정 — 월지 지장간이 천간에 드러났는지 (격국의 뚜렷함 판정) */
export interface TransparencyInfo {
  /** 월지 */
  monthZhi: string;
  /** 월지 지장간 전체 */
  hidden: string[];
  /** 천간에 드러난 지장간들 */
  revealed: Array<{ stem: string; atPosition: string; tenGod: string }>;
  /** 쉬운 말 설명 */
  note: string;
}

export interface StorageOpening {
  /** 창고 지지 (진·술·축·미) */
  zhi: string;
  /** 창고 지지 위치 (예: "일지") */
  position: string;
  /** 창고 오행 (예: "수" — 진은 수의 창고) */
  element: string;
  /** 창고 안에 갈무리된 대표 지장간(중기) */
  storedStem: string;
  /** 그 갈무리 기운의 십성 (일간 기준) */
  tenGod: string;
  /** 무엇이 열었는지 (예: "진술충", "축술미 삼형") */
  trigger: string;
  /** 쉬운 말 설명 */
  note: string;
}

/** 지지 하나의 지장간 기반 십성 분해 (여기/중기/정기 위상별) */
export interface HiddenTenGodBreakdown {
  /** 지지 위치 (예: "월지") */
  position: string;
  /** 지지 (예: "인") */
  zhi: string;
  /** 지장간별 십성과 위상 가중치 */
  stems: Array<{
    stem: string;
    phase: "여기" | "중기" | "정기";
    tenGod: string;
    weight: number;
  }>;
}

/** 신살 한 개 (이름 + 해당 위치 + 쉬운 뜻) */
export interface SinsalHit {
  name: string;
  /** 해당된 위치 (예: "일지 술", "일주") */
  position: string;
  /** 쉬운 말 뜻풀이 */
  gloss: string;
}

/** 월률분야(月律分野) / 사령(司令): 절입 경과일로 월지 지장간 중 어느 것이 그 시점을 주관하는지 */
export interface MonthCommand {
  /** 월지 */
  monthZhi: string;
  /** 사령한 지장간 글자 */
  stem: string;
  /** 지장간 내 위치 (여기/중기/정기) */
  phase: "여기" | "중기" | "정기";
  /** 사령 지장간이 일간에게 갖는 십성 */
  tenGod: string;
  /** 절입(節入)부터 지난 일수 */
  daysSinceTerm: number;
  /** 직전 절(節) 이름 (예: "대설") */
  termName?: string;
  /** 쉬운 말 설명 */
  note: string;
}

/** 격국 판정 (월지 사령/투출 십성 기준 + 종격 후보) */
export interface GyeokgukInfo {
  /** 격국 이름 (예: "편관격", "종재격 후보") */
  name: string;
  /** 판정 근거 */
  basis: string;
  /** 쉬운 말 설명 */
  gloss: string;
  /** 격을 잡은 근거가 된 월지 지장간 글자 */
  basisStem?: string;
  /** 격을 잡은 방식: 사령 투출 / 정기 투출 / 지장간 투출 / 사령 잠복(정기) */
  basisKind?: "사령 투출" | "정기 투출" | "지장간 투출" | "사령(잠복)";
  /** 성패 경향: 격이 뚜렷한지(성격)·흔들리는지(파격)·불명확한지 */
  status?: "성격 경향" | "파격 경향" | "불명확";
  /** 성패 판단 근거 (투출·충 등) */
  statusReason?: string;
  /** 자평진전(子平眞詮) 심화: 상신·성격/파격·종격 판정 */
  classic?: GyeokgukClassicInfo;
}

/** 자평진전(子平眞詮) 격국 심화 판정: 상신(相神)·성격/파격·종격 */
export interface GyeokgukClassicInfo {
  /** 상신(相神): 격을 완성시키는 핵심 십성/오행 */
  sangshin?: { tenGod: string; element: string; role: string; present: boolean };
  /** 성격 패턴 이름 (예: "살인상생", "식신생재") */
  pattern?: string;
  /** 패턴 쉬운 말 설명 */
  patternGloss?: string;
  /** 파격 요인 목록 (상관견관·재다신약 등) */
  failures: Array<{ name: string; reason: string }>;
  /** 종격 유형 (종재격·종살격·종왕격 등). 일반격이면 null */
  jonggyeok?: { name: string; reason: string } | null;
  /** 최종 성패 판정 */
  established: "성격" | "파격" | "미형성";
  /** 종합 쉬운 말 설명 */
  note: string;
}

export interface SajuChart {
  year: SajuPillar;
  month: SajuPillar;
  day: SajuPillar;
  /** 출생 시간을 모르면 null */
  hour: SajuPillar | null;
  fiveElements: FiveElementBalance;
  tenGods: string[];
  dayMasterGan: string;
  /** 이하 심화 계산 (구버전 저장 데이터에는 없을 수 있음) */
  yinYang?: { yang: number; yin: number };
  /** 기둥별 지장간 (예: "월지 자: 임·계") */
  hiddenStems?: string[];
  /** 지지 십성 (지장간 정기 기준) */
  branchTenGods?: string[];
  /** 지지별 지장간(여기/중기/정기) 기반 십성 분해 */
  hiddenTenGods?: HiddenTenGodBreakdown[];
  /** 십성 세기 분포 (천간 + 지장간 가중 합산) */
  tenGodDistribution?: Record<string, number>;
  /** 합충형파해 목록 (예: "월지-연지 자오충") */
  interactions?: string[];
  strength?: StrengthAssessment;
  yongshin?: YongshinCandidates;
  /** 통근(通根): 각 천간이 지지 지장간에 뿌리를 두는지 */
  rootedness?: RootednessHit[];
  /** 투출(投出): 월지 지장간이 천간에 드러났는지 */
  transparency?: TransparencyInfo;
  /** 개고(開庫): 창고 지지(진술축미)가 충/형으로 열려 안의 기운이 쓸 수 있게 드러났는지 */
  storageOpenings?: StorageOpening[];
  /** 월률분야(사령): 절입 경과일 기준 월지 지장간 중 주관하는 기운 */
  monthCommand?: MonthCommand;
  /** 12운성 (일간 기준 기둥별) */
  twelveStages?: string[];
  /** 공망 (일주 순중공망 지지 2개) */
  gongmang?: string;
  /** 조후(계절) 관점 노트 */
  seasonNote?: string;
  /** 신살 목록 (십이신살 전체 + 천을·천덕·월덕·문창·학당·금여·암록·양인·홍염·백호·괴강·원진·귀문·고신·과숙 등) */
  sinsal?: SinsalHit[];
  /** 60갑자 일주 성향 */
  iljuTrait?: string;
  /** 격국 판정 */
  gyeokguk?: GyeokgukInfo;
  /** 진태양시/서머타임 보정 내역 */
  timeCorrection?: TimeCorrection;
  /** 사용자에게 안내할 계산 기준 */
  calculationBasis?: CalculationBasis;
}

export interface DaYunInfo {
  startAge: number;
  endAge: number;
  startYear: number;
  endYear: number;
  ganZhi: string;
  current: boolean;
  /** 대운 천간이 일간과 맺는 십성 */
  tenGod?: string;
  /** 대운 지지의 12운성 (일간 기준) */
  twelveStage?: string;
  /** 대운 지지의 십이신살 (일지 삼합국 기준) */
  sibiSinsal?: string;
  /** 대운 지지가 일주 공망에 해당하는지 */
  gongmang?: boolean;
  /** 이 대운 구간이 삼재에 걸리는지 (걸리는 해가 있으면 표기) */
  samjae?: string;
  /**
   * 이 대운 간지가 용신/기신 방향인지 (boost=보완, drain=부담, neutral=중립).
   * 엔진 업그레이드 S-4. yong/avoid 오행이 없으면 undefined.
   */
  favor?: LuckFavor;
  /** 이 대운 지지·천간이 원국과 새로 맺는 합충형파해. 엔진 업그레이드 S-4. */
  interactions?: string[];
}

/** 올해 특정 달의 월운 흐름 (연간 12개월 흐름 계산용) */
export interface MonthFlowInfo {
  /** 1~12 (양력 달, 월주는 그 달 중순 절기 기준) */
  month: number;
  ganZhi: string;
  /** 이 달의 월운이 원국과 새로 맺는 합충형파해 */
  interactions: string[];
}

/** 특정 해의 세운 흐름 (다년 세운 타임라인용) */
export interface YearFlowInfo {
  /** 연도 (입춘 기준) */
  year: number;
  /** 그 해 만 나이 (근사) */
  age: number;
  ganZhi: string;
  /** 이 해 세운이 원국과 새로 맺는 합충형파해 */
  interactions: string[];
  /** 현재 해 여부 */
  current: boolean;
  /** 세운 천간이 일간과 맺는 십성 */
  tenGod?: string;
  /** 세운 지지의 12운성 (일간 기준) */
  twelveStage?: string;
  /** 이 해 삼재 여부 (들삼재/눌삼재/날삼재), 아니면 undefined */
  samjae?: string;
  /**
   * 이 해 세운 지지가 원국 년지 기준으로 드는 신살 (상문살·조객살).
   * 원국 위치판정(SajuChart.sinsal)과 별개로, "그 해 세운이 발동시키는" 신살이다.
   * 엔진 업그레이드 S-3 (docs/engine-upgrade-2026-07.md). 없으면 undefined.
   */
  sinsalHits?: string[];
}

export interface LuckCycles {
  daYun: DaYunInfo[];
  /** 현재 대운 간지 (아직 대운 시작 전이면 null) */
  currentDaYun: string | null;
  /** 올해 세운 간지 */
  yearGanZhi: string;
  /** 이번 달 월운 간지 (절기 기준 월주) */
  monthGanZhi: string;
  /** 오늘 일진 간지 */
  dayGanZhi?: string;
  year: number;
  month: number;
  /** 현재 대운/세운/월운/일진이 원국과 맺는 합충형파해 */
  luckInteractions?: string[];
  /** 올해 1~12월 월운 흐름 (월간/연간 흐름 리딩에서만 계산) */
  monthlyFlow?: MonthFlowInfo[];
  /** 올해부터 10년치 세운 흐름 */
  yearlyFlow?: YearFlowInfo[];
  /** 대운·세운 중첩 판정 (큰 흐름과 올해 흐름이 서로 겹치는 방식) */
  daYunYearOverlap?: LuckOverlap;
  /** 삼재 정보 (년지 삼합국 기준) */
  samjae?: SamjaeInfo;
  /** 대운 진행 방향 (순행/역행). 양남음녀=순행, 음남양녀=역행. 엔진 업그레이드 S-4. */
  daYunDirection?: "forward" | "reverse";
}

/** 삼재(三災) 정보 — 년지 삼합국 기준 3년 주기 */
export interface SamjaeInfo {
  /** 삼재에 해당하는 지지 3개 (들·눌·날 순) */
  branches: string[];
  /** 삼재가 드는 해(입춘 기준) 목록 (지금부터 앞으로 12년 내) */
  years: Array<{ year: number; phase: string; ganZhi: string }>;
  /** 올해가 삼재인지 (들삼재/눌삼재/날삼재), 아니면 null */
  currentPhase: string | null;
  note: string;
}

/** 운의 용신/기신 방향 정렬 */
export type LuckFavor = "boost" | "drain" | "neutral";

/** 대운·세운 중첩 판정 결과 */
export interface LuckOverlap {
  daYunGanZhi: string;
  yearGanZhi: string;
  /** 대운 간지와 세운 간지 사이의 직접 합충형파해 */
  interactions: string[];
  /** 대운이 보완 기운(용신) 방향인지 부담 기운(기신) 방향인지 */
  daYunFavor: LuckFavor;
  /** 세운이 보완 기운 방향인지 부담 기운 방향인지 */
  yearFavor: LuckFavor;
  /** 종합: 좋은 흐름 겹침/부담 겹침/엇갈림/조용함 */
  combo: "amplify-good" | "amplify-bad" | "mixed" | "quiet";
  /** 쉬운 말 한 줄 */
  headline: string;
  /** 전문가 근거 */
  evidence: string[];
}

export type CompatibilityRelationType =
  | "romantic"
  | "parentChild"
  | "siblings"
  | "family"
  | "bossEmployee"
  | "coworker"
  | "friend"
  | "rival";

/** 두 사람 사주 궁합 계산 결과 */
export interface CompatibilityResult {
  /** 선택한 관계 유형 */
  relationType?: CompatibilityRelationType;
  /** 관계 유형 라벨 */
  relationLabel?: string;
  /** 종합 점수 0~100 */
  score: number;
  /** 일간 관계 설명 (합/충/생/극) */
  dayMasterRelation: string;
  /** 두 사람 지지 사이 합충 목록 */
  branchRelations: string[];
  /** 오행 상호 보완 설명 */
  elementComplement: string;
  /** 종합 한 줄 코멘트 */
  summary: string;
  /** 사용자가 궁금한 점을 적었을 때, 그 질문 의도에 맞춘 관계 해석 */
  questionInsight?: {
    question: string;
    intent: string;
    answer: string;
    signals: string[];
    actions: string[];
  };
  /** 나·상대·질문·관계 유형을 합쳐 만든 실행 중심 맞춤 솔루션 */
  solutionPlan?: {
    title: string;
    problem: string;
    personalContext: string;
    relationshipContext: string;
    priority: string;
    stopDoing: string[];
    todayActions: string[];
    weekActions: string[];
    scripts: string[];
    checkSignals: string[];
  };
  /** 세부 항목별 점수 */
  breakdown: { label: string; score: number; note: string; detail?: string; signal?: string; actions?: string[] }[];
  /** 화면에서 바로 보여줄 관계 운영 포인트 */
  highlights?: { title: string; body: string; action: string }[];
  /** 관계에서 주의할 반복 패턴 */
  cautionPoints?: string[];
  /** 현실적인 관계 운영법 */
  actionPlan?: string[];
  /** 선택한 관계 유형에 맞춘 개선 방향 */
  improvementTips?: string[];
  /** 점수가 낮거나 조율이 필요한 관계를 위한 단계형 보완 리포트 */
  repairReport?: {
    level: "smooth" | "needsCare" | "repairFirst";
    headline: string;
    intro: string;
    whyItHappens: string[];
    conflictCycle: Array<{
      step: string;
      body: string;
      repair: string;
    }>;
    byPerson: {
      me: string[];
      partner: string[];
      together: string[];
    };
    scripts: string[];
    avoid: string[];
  };
  /** 일지(배우자궁/관계 자리) 중심 해석 */
  partnerPalace?: {
    title: string;
    body: string;
    evidence: string;
  };
  /** 서로에게 어떤 역할로 느껴지는지 */
  roleChemistry?: Array<{
    title: string;
    body: string;
    evidence: string;
  }>;
  /** 관계 목적별 적합도 */
  purposeFits?: Array<{
    label: string;
    score: number;
    comment: string;
    detail?: string;
    signal?: string;
    actions?: string[];
  }>;
  /** 가까운 시기 흐름 */
  timing?: Array<{
    label: string;
    body: string;
    evidence: string;
  }>;
  /**
   * 두 사람 운 흐름 교차 타이밍 상세 (엔진 업그레이드 C-1). 점수·기존 `timing` 불변, 새 optional 필드만 채운다.
   * 표면 문장(plain/body/headline/tone)은 사주 용어를 쓰지 않고, 근거(evidence·kind)에만 남긴다.
   */
  timingDetail?: {
    /** 한 사람의 올해 세운 지지가 상대 원국 일지·월지와 새로 맺는 신호 */
    crossHits: Array<{
      /** 이 신호를 움직이는 사람(올해 흐름 주인)의 역할 라벨 */
      mover: string;
      /** 그 사람의 올해 세운 간지 */
      moverGanZhi: string;
      /** 신호를 받는 상대의 역할 라벨 */
      target: string;
      /** 상대 원국에서 신호가 닿는 자리(일지/월지) 설명 */
      targetSpot: string;
      /** 관계 유형(합/충/형/파/해) — 근거 전용 */
      kind: string;
      /** 쉬운 말 설명(사주 용어 없음) */
      plain: string;
      valence: "good" | "bad";
    }>;
    /** 향후 3년 관계 전망 (두 사람 세운 신호 + 교차 신호 종합) */
    outlook: Array<{
      year: number;
      tone: "순한 편" | "무난한 편" | "조율이 필요한 편";
      body: string;
      evidence: string;
    }>;
    /** 두 사람 현재 대운 방향(용신/기신)의 동조·엇갈림 (S-4 favor 재사용) */
    dayunPhase: {
      aGanZhi: string | null;
      bGanZhi: string | null;
      aFavor?: LuckFavor;
      bFavor?: LuckFavor;
      sync: "aligned-good" | "aligned-hard" | "diverging" | "neutral";
      headline: string;
      evidence: string;
    };
  };
  /**
   * 고전 보완 서술 (엔진 업그레이드 C-2). 통관용신·궁통보감 조후를 **점수 변경 없이** 서술로만 반영한다.
   * 표면(headline/plain/together)은 사주 용어를 쓰지 않고, 근거(evidence)에만 남긴다. 보완 신호가 없으면 undefined.
   */
  classicComplement?: {
    /** 쉬운 말 한 줄 요약 */
    headline: string;
    /** 계절적 치우침(궁통보감 조후)을 상대가 채워주는 서술. 해당 없으면 null */
    johu: { plain: string; evidence: string } | null;
    /** 대립하는 두 기운 사이를 상대가 이어주는(통관) 서술. 해당 없으면 null */
    mediating: { plain: string; evidence: string } | null;
    /** 둘이 같이 해보면 좋은 것 (서술 톤, 사주 용어 없음) */
    together: string[];
    /** 근거(고전·오행) */
    evidence: string[];
  };
  /** 전문가 근거 */
  expertEvidence?: string[];
  /** 두 사람 원국 요약 */
  people?: Array<{
    label: string;
    pillars: { year: string; month: string; day: string; hour: string | null };
    dayMaster: string;
    strongestElement: string;
    weakestElement: string;
  }>;
}

// ── 사건화 엔진 (계산값 → 분야별 현실 사건 시나리오, 무 API·결정론) ──────────

/** 사건화 분야 */
export type LifeDomain =
  | "career"
  | "money"
  | "love"
  | "health"
  | "family"
  | "move"
  | "startup";

/** 사건 신호의 무게 (지금 시기 얼마나 활성화됐는지) */
export type EventActivation = "high" | "mid" | "low";

/** 분야별 3축 점수 (0~100, 절대 진단 아님·상대 경향) */
export interface EventScores {
  /** 지금 이 분야가 얼마나 움직이는가 */
  activation: number;
  /** 그 움직임이 이득(기회) 방향인 정도 */
  benefit: number;
  /** 그 움직임이 부담(위험) 방향인 정도 */
  risk: number;
  /** benefit - risk 로 본 성격: 기회형/주의형/혼조형/평이 */
  balance: "opportunity" | "caution" | "mixed" | "calm";
}

/** 한 분야의 사건 시나리오 */
export interface EventScenario {
  domain: LifeDomain;
  /** 사용자용 분야 라벨 (예: "직업·일") */
  label: string;
  /** 지금 대운·세운·월운이 이 분야를 건드리는 정도 */
  activation: EventActivation;
  /** 활성·이득·위험 3축 점수 */
  scores: EventScores;
  /** 활성 정도를 쉬운 말로 한 줄 (예: "올해 이 분야가 크게 움직이는 흐름") */
  activationNote: string;
  /** 이 사주에서 이 분야에 나타나기 쉬운 사건 유형 (원국 기반, 쉬운 말) */
  patterns: string[];
  /** 지금 시기(대운·세운·월운)와 연결된 사건 신호. 활성이 낮으면 비어 있을 수 있음 */
  timingSignals: string[];
  /** 이 분야에서 조심할 신호 */
  cautions: string[];
  /** 전문가 근거 (십성·궁위·충합형파해 등 계산 근거) */
  evidence: string[];
}

/** 계산값에서 도출한 분야별 사건 예보 */
export interface EventForecast {
  domains: EventScenario[];
  /** 지금 활성도가 높은 분야 키 (우선 노출용, activation 높은 순) */
  activeDomains: LifeDomain[];
  /** 전체를 관통하는 한 줄 요약 (가장 활성화된 분야 중심) */
  headline: string;
}

export type TarotArcana = "major" | "minor";

export interface TarotCardDefinition {
  id: number;
  name: string;
  arcana: TarotArcana;
  uprightMeaning: string;
  reversedMeaning: string;
  /** 카드별 고유 상징 키워드. 없으면 카드 번호/슈트/코트로 자동 보강한다. */
  symbols?: string[];
  /** 그림 속 단서나 원형적 장면. 없으면 자동 상징 해석기를 사용한다. */
  imagery?: string;
  /** 저작권 확인이 끝난 카드 이미지 경로. 없으면 앱 내 미니 카드 비주얼을 보여준다. */
  imageUrl?: string;
  /** 관계 질문에서 특히 어떻게 나타나는지. 없으면 슈트/번호 기반으로 자동 보강한다. */
  relationshipSymbolism?: string;
}

export interface DrawnTarotCard {
  card: TarotCardDefinition;
  reversed: boolean;
  position: number;
  /** 스프레드에서 이 자리의 의미 (예: "과거/원인", "장애물") */
  positionLabel?: string;
}

export interface ChatMessage {
  role: "user" | "assistant";
  content: string;
}

export interface ReadingSession {
  id: string;
  type: ReadingType;
  createdAt: string;
  question: string;
  favorite?: boolean;
  focus?: ReadingFocus;
  context?: ReadingContext;
  feedback?: ReadingFeedback;
  birthInfo?: BirthInfo;
  sajuChart?: SajuChart;
  luckCycles?: LuckCycles;
  tarotCards?: DrawnTarotCard[];
  messages: ChatMessage[];
}

// ── 점성술 어스펙트/트랜짓 (봇 비서용 추가 계산) ──────────
// 기본 점성술 타입(ZodiacSign/AstrologyPlacement/AstrologyProfile 등)은 아래쪽
// "속마음 점성술 엔진 이식" 블록에 정의돼 있다. 여기는 봇 비서에서만 쓰는 두 타입만 추가한다.

/** 행성 두 개 사이의 주요 각도(어스펙트) 관계 */
export interface AstrologyAspect {
  bodyA: string;
  bodyB: string;
  aspect: "합" | "육십분" | "사각" | "삼분" | "충";
  angle: number;
  orb: number;
}

/** 오늘 하늘(트랜짓)이 원국의 어느 지점을 건드리는지 요약한 한 줄 테마 */
export interface AstrologyTransitTheme {
  date: string;
  sunTransitHouse?: number;
  moonTransitHouse?: number;
  theme: string;
}

// ── 오늘의 운세 (결정론적 근거 데이터 + LLM 문장) ──────────

/** 십성 5분류 (비겁/식상/재성/관성/인성) */
export type TenGodGroup = "비겁" | "식상" | "재성" | "관성" | "인성";

/** 지지 관계 종류 */
export type BranchRelationKind =
  | "육합"
  | "삼합"
  | "방합"
  | "충"
  | "형"
  | "파"
  | "해"
  | "원진";

/** 내 지지 한 자리가 오늘 지지와 맺는 관계 */
export interface BranchRelationHit {
  /** 내 지지의 자리 (연지/월지/일지/시지) */
  position: string;
  /** 내 지지 글자 */
  myBranch: string;
  /** 오늘 일진 지지 글자 */
  todayBranch: string;
  /** 성립한 관계들 (없으면 빈 배열) */
  relations: BranchRelationKind[];
  /** 자리 가중치 (일지가 가장 큼) */
  weight: number;
  /** 대략적 길흉 방향: 합=순(+), 충/형/원진=변동(-), 없음=0 */
  direction: number;
  /** 사람이 읽는 설명 */
  detail: string;
}

/** 카테고리별 점수 (0~100) */
export interface FortuneCategoryScores {
  /** 총운 */
  overall: number;
  /** 재물 */
  money: number;
  /** 애정 */
  love: number;
  /** 직장·학업 */
  career: number;
  /** 건강 */
  health: number;
  /** 대인관계 */
  relationship: number;
}

/** 오늘의 운세 근거 데이터 (룰 기반 엔진이 산출, LLM은 계산하지 않고 문장화만 함) */
export interface FortuneEvidence {
  /** 계산 기준 날짜 (Asia/Seoul, YYYY-MM-DD) */
  date: string;
  /** 요일 (한글) */
  weekday: string;
  /** 오늘 간지 (일진/월운/세운) */
  ganzhi: {
    day: string;
    dayGan: string;
    dayZhi: string;
    month: string;
    year: string;
  };
  /** 내 원국 요약 */
  natal: {
    dayMaster: string;
    dayMasterElement: string;
    pillars: { year: string; month: string; day: string; hour: string | null };
    strength: StrengthAssessment["label"];
    fiveElements: FiveElementBalance;
    /** 용신/희신 후보 오행 (한글) */
    yongshin: string[];
    /** 기신 후보 오행 (한글) */
    gishin: string[];
    hasHour: boolean;
  };
  /** 십성: 내 일간 vs 오늘 일진 천간 */
  tenGod: {
    name: string;
    group: TenGodGroup;
    /** "오늘 어떤 종류의 일이 들어오는가"의 축 설명 */
    axis: string;
  };
  /** 지지 관계: 내 4개 지지 각각 vs 오늘 지지 */
  branchRelations: BranchRelationHit[];
  /** 오행 조력도 (-100~+100) */
  elementSupport: {
    /** 오늘 간지의 오행 (천간·지지, 한글) */
    todayElements: string[];
    score: number;
    helpsYongshin: boolean;
    strengthensGishin: boolean;
    detail: string;
  };
  /** 12운성 (오늘 지지 기준 내 일간의 단계) */
  twelveStage: {
    stage: string;
    /** 에너지 레벨 0~100 */
    energyLevel: number;
    detail: string;
  };
  /** 신살 (오늘이 내 기준 해당하는지) */
  sinsal: {
    cheoneulgwiin: boolean;
    yeongma: boolean;
    dohwa: boolean;
    hwagae: boolean;
    gongmang: boolean;
    /** 해당하는 신살의 사람이 읽는 이름 목록 */
    hits: string[];
  };
  /** 카테고리별 점수 (0~100) */
  categories: FortuneCategoryScores;
  /** 행운 아이템 */
  luckyItems: {
    /** 오늘 길한 오행 (한글) */
    element: string;
    colors: string[];
    direction: string;
    numbers: number[];
    /** 합이 되는 시지 → 시간대 */
    timeSlot: { zhi: string; range: string };
  };
}

/** 분야별 카드 한 개 (점수는 FortuneEvidence.categories에서, 문장은 여기서) */
export interface FortuneCategoryContent {
  /** 한 줄 요약 */
  comment: string;
  /** 이 분야에서 잘 풀리는 점 */
  good?: string;
  /** 이 분야에서 주의할 점 */
  caution?: string;
}

/** LLM(또는 폴백)이 생성하는 오늘의 운세 문장 묶음 */
export interface FortuneContent {
  /** 한 줄 히어로 배지 */
  summary: string;
  /** 전체 운세 2~3문장 (총운 카드용) */
  overall: string;
  keywords: string[];
  do_actions: string[];
  avoid_actions: string[];
  categories: {
    money: FortuneCategoryContent;
    love: FortuneCategoryContent;
    career: FortuneCategoryContent;
    health: FortuneCategoryContent;
    relationship: FortuneCategoryContent;
  };
  share_text: string;
}

/** 화면·캐시에서 다루는 오늘의 운세 결과 (근거 + 문장 + 메타) */
export interface FortuneResult {
  evidence: FortuneEvidence;
  content: FortuneContent;
  /** LLM 생성인지 룰 기반 폴백인지 */
  source: "llm" | "fallback";
  /** 생성 시각 (ISO) */
  createdAt: string;
}

// ── 점성술(속마음 엔진 공용) 타입 ──────────────────────
export type ZodiacSign =
  | "양자리"
  | "황소자리"
  | "쌍둥이자리"
  | "게자리"
  | "사자자리"
  | "처녀자리"
  | "천칭자리"
  | "전갈자리"
  | "사수자리"
  | "염소자리"
  | "물병자리"
  | "물고기자리";

export interface AstrologyPlacement {
  body: string;
  sign: ZodiacSign;
  degree: number;
  absoluteLongitude: number;
  house?: number;
  keyword: string;
}

export interface ClassicalPlacement extends AstrologyPlacement {
  dignity: "도미사일" | "엑잘테이션" | "디트리먼트" | "폴" | "페레그린";
  ruler: string;
}

export interface VedicPlacement {
  body: string;
  sign: ZodiacSign;
  degree: number;
  absoluteLongitude: number;
  nakshatra?: string;
  pada?: number;
  keyword: string;
}

export interface VedicDashaInfo {
  system: "Vimshottari";
  currentMahaDasha: string;
  currentMahaDashaStart: string;
  currentMahaDashaEnd: string;
  birthNakshatraLord: string;
  balanceAtBirthYears: number;
  note: string;
}

export interface AstrologyProfile {
  calculatedAt: string;
  locationLabel: string;
  timeKnown: boolean;
  accuracyNote: string;
  modern: {
    sun: AstrologyPlacement;
    moon: AstrologyPlacement;
    ascendant?: AstrologyPlacement;
    venus: AstrologyPlacement;
    mars: AstrologyPlacement;
    /** 세대 행성: 천왕성·해왕성·명왕성 (별자리는 세대, 하우스·각도는 개인 차트에 유의미) */
    outer: AstrologyPlacement[];
    summary: string[];
  };
  classical: {
    sect: "day" | "night" | "unknown";
    ascendant?: AstrologyPlacement;
    placements: ClassicalPlacement[];
    summary: string[];
  };
  vedic: {
    ayanamsa: string;
    lagna?: VedicPlacement;
    moon: VedicPlacement;
    sun: VedicPlacement;
    rahu: VedicPlacement;
    ketu: VedicPlacement;
    dasha: VedicDashaInfo;
    summary: string[];
  };
  notes: string[];
}
