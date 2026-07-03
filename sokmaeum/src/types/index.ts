export type ReadingType = "saju" | "tarot" | "combo" | "today" | "flow" | "mystic";

/** 해석 포커스: 전반 / 직업·돈 / 연애·관계 / 건강·컨디션 / 멘탈·감정 / 선택·시기 고민 */
export type ReadingFocus = "general" | "career" | "relationship" | "wellness" | "mental" | "decision";

// ── 리딩 전 개인화 질문 (입력 정제) ──────────

/** 현재 상황 단계 */
export type SituationStage = "before" | "ongoing" | "waiting" | "closing";

/** 원하는 답변 톤 */
export type AnswerTone = "realistic" | "warm" | "blunt" | "detailed";

/** 원하는 해석 깊이 */
export type AnswerDepth = "light" | "basic" | "advanced" | "expert";

/** 출생 시간 정확도 (신뢰도 계산에 반영) */
export type BirthTimeAccuracy = "exact" | "half-hour" | "over-hour" | "unknown";

export interface ReadingContext {
  situation?: SituationStage;
  tone?: AnswerTone;
  depth?: AnswerDepth;
  timeAccuracy?: BirthTimeAccuracy;
  /** 지난 리딩 피드백에서 뽑은 스타일 조정 요청 (사용자가 반영에 동의했을 때만 채워짐) */
  styleHint?: string;
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

export interface BirthInfo {
  calendarType: CalendarType;
  year: number;
  month: number;
  day: number;
  /** 0-23, 시간을 모르면 null */
  hour: number | null;
  /** 0-59, 생략 시 0 */
  minute?: number;
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
  /** 용신/희신 후보 오행 */
  supportive: string[];
  /** 기신 후보 오행 */
  unfavorable: string[];
  /** 판정 방법과 한계 설명 */
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
  /** 합충형파해 목록 (예: "월지-연지 자오충") */
  interactions?: string[];
  strength?: StrengthAssessment;
  yongshin?: YongshinCandidates;
  /** 12운성 (일간 기준 기둥별) */
  twelveStages?: string[];
  /** 공망 (일주 순중공망 지지 2개) */
  gongmang?: string;
  /** 조후(계절) 관점 노트 */
  seasonNote?: string;
  /** 진태양시/서머타임 보정 내역 */
  timeCorrection?: TimeCorrection;
}

export interface DaYunInfo {
  startAge: number;
  endAge: number;
  startYear: number;
  endYear: number;
  ganZhi: string;
  current: boolean;
}

/** 올해 특정 달의 월운 흐름 (연간 12개월 흐름 계산용) */
export interface MonthFlowInfo {
  /** 1~12 (양력 달, 월주는 그 달 중순 절기 기준) */
  month: number;
  ganZhi: string;
  /** 이 달의 월운이 원국과 새로 맺는 합충형파해 */
  interactions: string[];
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
}

export type TarotArcana = "major" | "minor";

export interface TarotCardDefinition {
  id: number;
  name: string;
  arcana: TarotArcana;
  uprightMeaning: string;
  reversedMeaning: string;
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
  /** 속마음 심리 리딩 결과 (type === "mystic"일 때) */
  mysticResult?: MysticReadingResult;
}

// ── 속마음 심리 리딩 (전체사주 + 오늘의 운세 근거 → 심리 언어 번역) ──────────

export type ReadingIntensity = "low" | "medium" | "high";

export type ConcernCategory =
  | "work"
  | "money"
  | "relationship"
  | "health"
  | "emotion"
  | "future"
  | "selfWorth";

/** 리딩 관심사 (입력 화면에서 선택 → 리딩 생성에 반영) */
export type ReadingInterest =
  | "work"
  | "money"
  | "love"
  | "marriage"
  | "relationship"
  | "family"
  | "health"
  | "future"
  | "selfWorth"
  | "all";

export interface MysticReadingResult {
  openingOracle: {
    title: string;
    sentence: string;
    intensity: ReadingIntensity;
    evidence: string[];
  };
  currentState: {
    summary: string;
    bodySignal: string;
    emotionalSignal: string;
    energyLeak: string;
    advice: string;
    evidence: string[];
  };
  hiddenConcerns: Array<{
    category: ConcernCategory;
    title: string;
    description: string;
    whyItAppears: string;
    confidence: number;
  }>;
  outerInnerSelf: {
    outerSelf: string;
    innerSelf: string;
    defensePattern: string;
    hiddenDesire: string;
    collapsePoint: string;
    evidence: string[];
  };
  repeatedPatterns: Array<{
    area: "relationship" | "work" | "money" | "emotion";
    pattern: string;
    reason: string;
    howToBreak: string;
  }>;
  workAndMoney: {
    moneyAttractionPattern: string;
    moneyLeakPattern: string;
    suitableWorkEnvironment: string;
    unsuitableWorkEnvironment: string;
    currentAdvice: string;
  };
  relationshipReading: {
    expectationPattern: string;
    hurtPattern: string;
    closingHeartMoment: string;
    misunderstandingPattern: string;
    advice: string;
  };
  /** 상대방 생년월일을 입력한 경우에만 채워지는 관계 리딩 (단정 금지) */
  partnerReading?: {
    outerImpression: string;
    realPace: string;
    howTheySeeYou: string;
    powerDynamic: string;
    ambiguityReason: string;
    transitionTiming: string;
    advice: string;
    evidence: string[];
  };
  yearlyTurningPoints: Array<{
    period: string;
    keyword: string;
    opportunity: string;
    caution: string;
    advice: string;
  }>;
  avoidNow: Array<{
    title: string;
    reason: string;
    saferAlternative: string;
  }>;
  doNow: Array<{
    title: string;
    action: string;
    reason: string;
  }>;
  closingOracle: {
    sentence: string;
    theme: string;
  };
}

/** 결정론적 엔진이 산출하는 속마음 리딩 근거 묶음 (LLM은 이걸 문장화만 한다) */
export interface MysticEvidence {
  interest: ReadingInterest;
  hasHour: boolean;
  dayMaster: string;
  dayMasterElement: string;
  monthBranch: string;
  strength: string;
  /** 강한 오행 상위 2~3개 (한글) */
  strongElements: string[];
  /** 부족한 오행 (한글) */
  weakElements: string[];
  /** 십성 그룹 분포 (비겁/식상/재성/관성/인성 → 개수) */
  tenGodGroups: Record<string, number>;
  /** 우세한 십성 그룹 (한글) */
  dominantTenGods: string[];
  yongshin: string[];
  gishin: string[];
  /** 원국 합충형파해 요약 */
  natalInteractions: string[];
  /** 신살/공망 요약 */
  sinsal: string[];
  /** 현재 대운/세운/월운 간지 */
  currentDaYun: string | null;
  yearGanZhi: string;
  monthGanZhi: string;
  /** 현재 운이 원국과 맺는 합충형파해 */
  luckInteractions: string[];
  /** 올해 월별 흐름 (period/keyword 후보) */
  monthlyFlow: Array<{ month: number; ganZhi: string; interactions: string[] }>;
  /** 사람이 읽는 근거 문자열 (예: "목 기운 부족", "재성 강함") */
  notes: string[];
  /** 상대방 생년월일을 입력한 경우의 관계 비교 근거 */
  partner?: PartnerEvidence;
  /** 지난 피드백에서 뽑은 스타일 조정 힌트 (개인화) */
  styleHint?: string;
}

/** 상대방과의 관계 비교 근거 (두 사주 원국 대조) */
export interface PartnerEvidence {
  dayMaster: string;
  dayMasterElement: string;
  /** 내 일간이 상대 일간을 보는 십성 (내가 상대를 대하는 축) */
  myTenGodToPartner: string;
  /** 상대 일간이 나를 보는 십성 (상대가 나를 대하는 축) */
  partnerTenGodToMe: string;
  /** 오행 관계: 상대가 나를 "생/극/비화" 중 무엇으로 만나는지 */
  elementRelation: "생함" | "생받음" | "극함" | "극받음" | "비화";
  /** 두 원국 지지 사이의 합/충 등 관계 요약 */
  branchHits: string[];
  notes: string[];
}

/** 섹션별 피드백 (추후 개인화용, 로컬 저장) */
export interface SectionFeedback {
  readingId: string;
  sectionKey: string;
  feedback: "accurate" | "partial" | "unsure" | "wrong";
  createdAt: string;
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

/** LLM(또는 폴백)이 생성하는 오늘의 운세 문장 묶음 */
export interface FortuneContent {
  summary: string;
  keywords: string[];
  good_areas: string[];
  caution_points: string[];
  do_actions: string[];
  avoid_actions: string[];
  categories: {
    love: string;
    work: string;
    money: string;
    relationship: string;
    condition: string;
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
