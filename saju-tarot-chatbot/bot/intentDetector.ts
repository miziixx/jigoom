// 자연어 메시지에서 의도를 분류한다. 별도 Claude 호출 없이 결정론적 키워드 매칭으로 판단한다
// (extractVerbosityHint.ts와 같은 스타일). 특히 기억 저장/삭제 같은 보안 민감 동작은
// LLM의 애매한 판단이 아니라 명시적 트리거 문구로만 작동해야 안전하다.

export type DetectedIntent =
  | "sajuReading"
  | "astrologyReading"
  | "tarotReading"
  | "combinedReading"
  | "todayFlow"
  | "selfAnalysis"
  | "planning"
  | "writing"
  | "decision"
  | "memorySave"
  | "memoryDelete"
  | "memoryLookup"
  | "privacyCheck"
  | "resetContext"
  | "generalChat";

interface IntentRule {
  intent: DetectedIntent;
  patterns: RegExp[];
}

// 우선순위 순서대로 배열. 위에서부터 먼저 매치되는 규칙이 이긴다.
const RULES: IntentRule[] = [
  {
    intent: "privacyCheck",
    patterns: [/보안\s*상태/, /개인정보.*(어떻게|처리|보관)/, /프라이버시/, /로그.*(남|저장)/],
  },
  {
    intent: "resetContext",
    patterns: [/대화\s*(초기화|리셋)/, /맥락\s*(초기화|리셋)/, /처음부터\s*다시/],
  },
  {
    intent: "memoryDelete",
    patterns: [/저장하지\s*마/, /기억하지\s*마/, /방금\s*(건|거)\s*잊어/, /잊어(줘|버려)/, /기억\s*(지워|삭제)/, /저장\s*(지워|삭제)/, /최근\s*기억.*(지워|삭제)/],
  },
  {
    // 조회(질문)는 저장(명령)보다 먼저 검사한다. "기억해?", "기억하고 있어?"처럼 "기억하고 있느냐"고
    // 묻는 질문이 "기억해둬"(저장 명령)로 오인되지 않게 하기 위함이다.
    intent: "memoryLookup",
    patterns: [
      /뭐\s*기억/,
      /무슨\s*기억/,
      /기억\s*목록/,
      /저장된\s*(거|것).*보여/,
      /기억하고\s*있(어|나|니|는|는지)/,
      /기억\s*나(요)?\s*\?/,
      /기억해\s*\?/, // "기억해?" — 물음표가 붙으면 저장 명령이 아니라 조회 질문
      /기억하니\s*\??/,
      /기억\s*하고\s*있/,
    ],
  },
  {
    // 저장은 "기억해줘/둬/놔", "저장해줘"처럼 *명시적 저장 명령*일 때만. 맨 뒤 어미 없는 "기억해?"(질문)는 제외.
    intent: "memorySave",
    patterns: [
      /기억해\s*(줘|둬|놔|주세요|두세요|주라|둘래|놓|둘\b)/,
      /저장해\s*(줘|둬|놔|주세요|두세요)/,
      /메모해\s*(줘|둬|놔)/,
      /기억해\s*(두었으면|뒀으면|둰|둠)/,
      /프로젝트에\s*넣어/,
      /이\s*기준으로\s*봐줘/,
      /(잊지\s*마|잊지마)/,
    ],
  },
  {
    intent: "tarotReading",
    // "타로"는 명확하다. "카드"만으론 신용카드 등과 헷갈려, 뽑기/점/리딩 맥락이 붙을 때만 잡는다.
    patterns: [
      /타로/,
      /카드\s*(뽑|점|리딩|봐|보고|한\s*장|세\s*장|세장)/,
      /카드\s*(로|를)\s*(뽑|봐|보|점)/,
      /(뽑아|뽑아줘|뽑아주|한\s*장\s*뽑|세\s*장\s*뽑)/,
      /스프레드/,
      /아르카나/,
      /원\s*카드|쓰리\s*카드|켈틱\s*크로스|celtic/i,
    ],
  },
  {
    intent: "combinedReading",
    patterns: [
      /사주.*(점성술?|점성학|별자리|호로스코프|행성)/,
      /(점성술?|점성학|별자리|호로스코프|행성).*사주/,
      /명리.*(점성|별자리)|(점성|별자리).*명리/,
      /둘\s*다\s*(봤을|보면|봐|볼)/,
    ],
  },
  {
    intent: "astrologyReading",
    // saju 규칙보다 먼저 검사되므로, 사주와 겹치지 않는 점성술 고유 용어만 넣는다.
    // (모호한 "차트"는 사주 명식과 헷갈려 제외 — combinedReading이 사주+점성술을 먼저 잡는다.)
    patterns: [
      /별자리/,
      /점성술?|점성학/,
      /태양궁|달\s*별자리|상승궁|어센던트/,
      /트랜짓|트랜싯/,
      /호로스코프|조디악/,
      /네이탈/,
      /하우스/,
      /역행/,
      /새턴|토성\s*리턴/,
      /행성/,
      /아스펙트/,
      /수성|금성|화성|목성|토성|천왕성|해왕성|명왕성/,
      /다샤|나크샤트라|라그나|라후|케투/,
    ],
  },
  {
    intent: "sajuReading",
    patterns: [/사주/, /신강|신약/, /격국/, /지장간/, /대운/, /일주/, /오행/],
  },
  {
    intent: "todayFlow",
    patterns: [/오늘.*(어때|운|흐름|일진)/, /오늘의\s*운세/, /하루\s*운/],
  },
  {
    intent: "selfAnalysis",
    patterns: [
      /나\s*왜\s*자꾸/,
      /나\s*왜/,
      /내가\s*예민한\s*건가/,
      /하기\s*싫은\s*이유/,
      /반복되(는|지)/,
      /자꾸\s*미루/,
      /완성을?\s*못\s*하/,
    ],
  },
  {
    intent: "planning",
    patterns: [
      /기획/,
      /만들고\s*싶어/,
      /구조\s*(좀\s*)?잡아/,
      /mvp/i,
      /기능\s*넣으면/,
      /작업\s*지시서/,
      /claude\s*code.*시킬/i,
      /앱으로\s*만들면/,
    ],
  },
  {
    intent: "writing",
    patterns: [/고쳐줘/, /자연스럽게/, /ai\s*티/i, /설명문으로/, /프롬프트로\s*정리/, /글\s*(좀\s*)?다듬/, /윤문/],
  },
  {
    intent: "decision",
    patterns: [
      /뭐부터/,
      /해야\s*할까/,
      /먼저\s*할까/,
      /이\s*방향\s*맞아/,
      /지금\s*이\s*선택/,
      /버려도\s*돼/,
      /밀어붙여도\s*돼/,
      /해도\s*될까/,
    ],
  },
];

/** 자연어 텍스트에서 의도를 분류한다. 매치되는 규칙이 없으면 generalChat. */
export function detectIntent(text: string): DetectedIntent {
  const t = text.trim();
  if (!t) return "generalChat";
  for (const rule of RULES) {
    for (const pattern of rule.patterns) {
      if (pattern.test(t)) return rule.intent;
    }
  }
  return "generalChat";
}

/** 새 비서 모드(기획/글쓰기/판단/자기분석) 대상인지 판별 */
export function isSecretaryIntent(intent: DetectedIntent): intent is "planning" | "writing" | "decision" | "selfAnalysis" {
  return intent === "planning" || intent === "writing" || intent === "decision" || intent === "selfAnalysis";
}

/** 결정론적으로 즉시 처리해야 하는(별도 Claude 호출 불필요할 수 있는) 의도인지 */
export function isDeterministicIntent(
  intent: DetectedIntent,
): intent is "memorySave" | "memoryDelete" | "memoryLookup" | "privacyCheck" | "resetContext" {
  return (
    intent === "memorySave" ||
    intent === "memoryDelete" ||
    intent === "memoryLookup" ||
    intent === "privacyCheck" ||
    intent === "resetContext"
  );
}

/** 사람이 읽는 의도 고지 문구 (Step 9: 응답 첫 줄에 감지된 의도 짧게 고지) */
export const INTENT_LABEL: Record<DetectedIntent, string> = {
  sajuReading: "사주 질문",
  astrologyReading: "점성술 질문",
  tarotReading: "타로 리딩",
  combinedReading: "사주+점성술 통합 질문",
  todayFlow: "오늘 흐름 질문",
  selfAnalysis: "자기분석 질문",
  planning: "기획 질문",
  writing: "글쓰기 요청",
  decision: "판단/결정 질문",
  memorySave: "기억 저장 요청",
  memoryDelete: "기억 삭제 요청",
  memoryLookup: "기억 조회 요청",
  privacyCheck: "보안 정책 확인",
  resetContext: "대화 초기화",
  generalChat: "일반 대화",
};
