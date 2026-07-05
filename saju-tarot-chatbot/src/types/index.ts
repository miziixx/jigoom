export type ReadingType = "saju" | "tarot" | "combo" | "today" | "flow";

/** 해석 포커스: 전반 / 직업·돈 / 연애·관계 / 건강·컨디션 / 멘탈·감정 / 선택·시기 고민 */
export type ReadingFocus = "general" | "career" | "relationship" | "wellness" | "mental" | "decision";

// ── 리딩 전 개인화 질문 (입력 정제) ──────────

/** 현재 상황 단계 */
export type SituationStage = "before" | "ongoing" | "waiting" | "closing";

/** 원하는 답변 톤 */
export type AnswerTone = "realistic" | "warm" | "blunt" | "detailed" | "action";

/** 원하는 해석 깊이 */
export type AnswerDepth = "light" | "basic" | "advanced" | "expert";

/** 출생 시간 정확도 (신뢰도 계산에 반영) */
export type BirthTimeAccuracy = "exact" | "half-hour" | "over-hour" | "unknown";

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
}

/** 신살 한 개 (이름 + 해당 위치 + 쉬운 뜻) */
export interface SinsalHit {
  name: string;
  /** 해당된 위치 (예: "일지 술", "일주") */
  position: string;
  /** 쉬운 말 뜻풀이 */
  gloss: string;
}

/** 격국 판정 (월지 정기 십성 기준 + 종격 후보) */
export interface GyeokgukInfo {
  /** 격국 이름 (예: "편관격", "종재격 후보") */
  name: string;
  /** 판정 근거 */
  basis: string;
  /** 쉬운 말 설명 */
  gloss: string;
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
