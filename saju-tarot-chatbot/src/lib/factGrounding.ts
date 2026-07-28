/**
 * AI 리딩 출력의 사주 "사실 주장"이 계산 근거에 실제로 있는지 점검한다 (fact grounding).
 *
 * 목적: 공부용 정확도. LLM이 계산 데이터에 없는 신살·십성·간지·격국을
 * "네 사주에 있다"고 지어내는 것(할루시네이션)을 감지한다.
 * 기존 judgmentValidation(금지 표현·도메인·톤)과 별개의 additive 레이어다.
 *
 * 원칙:
 * - 이론 설명("도화살은 매력을 뜻하는 살이야")은 건드리지 않는다. 귀속 주장
 *   ("네 사주에 도화살이 있어")만 본다 — 봇은 사주 공부 대화가 많아서
 *   일반 이론 문장을 막으면 안 된다.
 * - 차단이 아니라 감지다. 호출부가 경고 꼬리를 붙이거나 로그를 남기는 데 쓴다.
 *   (오탐 가능성이 0이 아니므로 소프트 경고가 맞다.)
 * - 근거 텍스트는 bot/evidence.ts의 buildNatalEvidence처럼 계산 결과를
 *   직렬화한 문자열이면 된다. 용어가 그 문자열에 있으면 grounded로 본다.
 */

export type GroundingCategory = "sinsal" | "tenGod" | "ganzhi" | "gyeokguk";

export interface GroundingHit {
  /** 답변에서 감지된 용어 (표시용) */
  term: string;
  category: GroundingCategory;
  /** 해당 용어가 들어 있던 문장 (앞뒤 공백 정리) */
  sentence: string;
}

/**
 * 신살 어휘. root = 답변에서 찾을 감지 토큰(가장 짧은 구별형),
 * evidenceKeys = 이 중 하나라도 근거 텍스트에 있으면 grounded (엔진 명칭·별칭 대응).
 * 엔진 명칭은 src/lib/saju.ts의 SinsalHit.name 값 기준.
 */
const SINSAL_VOCAB: Array<{ root: string; evidenceKeys: string[] }> = [
  { root: "도화", evidenceKeys: ["도화", "년살"] }, // 엔진은 년살, gloss에 "(도화)"
  { root: "역마", evidenceKeys: ["역마"] },
  { root: "화개", evidenceKeys: ["화개"] },
  { root: "백호", evidenceKeys: ["백호"] }, // 엔진은 백호대살
  { root: "괴강", evidenceKeys: ["괴강"] },
  { root: "양인", evidenceKeys: ["양인"] },
  { root: "홍염", evidenceKeys: ["홍염"] },
  { root: "원진", evidenceKeys: ["원진"] },
  { root: "귀문", evidenceKeys: ["귀문"] }, // 엔진은 귀문관살
  { root: "천을귀인", evidenceKeys: ["천을귀인"] },
  { root: "천덕", evidenceKeys: ["천덕"] },
  { root: "월덕", evidenceKeys: ["월덕"] },
  { root: "문창", evidenceKeys: ["문창"] },
  { root: "학당", evidenceKeys: ["학당"] },
  { root: "금여", evidenceKeys: ["금여"] },
  { root: "암록", evidenceKeys: ["암록"] },
  { root: "삼재", evidenceKeys: ["삼재"] },
  { root: "겁살", evidenceKeys: ["겁살"] },
  { root: "망신살", evidenceKeys: ["망신살"] },
  { root: "장성살", evidenceKeys: ["장성살"] },
  { root: "반안살", evidenceKeys: ["반안살"] },
  { root: "육해살", evidenceKeys: ["육해살"] },
  { root: "월살", evidenceKeys: ["월살"] },
  { root: "천살", evidenceKeys: ["천살"] },
  { root: "지살", evidenceKeys: ["지살"] },
  { root: "재살", evidenceKeys: ["재살"] },
  { root: "고신", evidenceKeys: ["고신"] },
  { root: "과숙", evidenceKeys: ["과숙"] },
  { root: "상문", evidenceKeys: ["상문"] },
  { root: "조객", evidenceKeys: ["조객"] },
  { root: "현침", evidenceKeys: ["현침"] },
  { root: "격각", evidenceKeys: ["격각"] },
  { root: "복성귀인", evidenceKeys: ["복성귀인"] },
  { root: "태극귀인", evidenceKeys: ["태극귀인"] },
  { root: "재고귀인", evidenceKeys: ["재고귀인"] },
];

/** 십성 10개 + 별칭(칠살=편관). "상관"은 "상관없-"류 일상어와 겹쳐 별도 제외 처리. */
const TEN_GOD_VOCAB: Array<{ root: string; evidenceKeys: string[] }> = [
  { root: "비견", evidenceKeys: ["비견"] },
  { root: "겁재", evidenceKeys: ["겁재"] },
  { root: "식신", evidenceKeys: ["식신"] },
  { root: "상관", evidenceKeys: ["상관"] },
  { root: "편재", evidenceKeys: ["편재"] },
  { root: "정재", evidenceKeys: ["정재"] },
  { root: "편관", evidenceKeys: ["편관"] },
  { root: "정관", evidenceKeys: ["정관"] },
  { root: "편인", evidenceKeys: ["편인"] },
  { root: "정인", evidenceKeys: ["정인"] },
  { root: "칠살", evidenceKeys: ["편관", "칠살"] },
];

const GAN = ["갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"];
const ZHI = ["자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해"];
/** 60갑자 한글 토큰 */
const SIXTY_GANZHI: string[] = (() => {
  const out: string[] = [];
  for (let i = 0; i < 60; i++) out.push(GAN[i % 10] + ZHI[i % 12]);
  return out;
})();

/** 간지 주장으로 보려면 같은 문장에 이 중 하나가 있어야 한다 (일상어 충돌 방지: 갑자기·임신·정사 등). */
const PILLAR_CONTEXT = /(일주|월주|연주|년주|시주|일간|월간|연간|년간|시간지|대운|세운|월운|일진|원국|사주팔자)/;

/** 귀속 주장 판정: 이 사람 차트에 있다고 말하는 문장인가. */
const CHART_WORD = /(사주|원국|명식|팔자|차트)/;
const PRESENCE_VERB = /(있|보이|보여|나타|깔려|들어|박혀|강하|왕하|자리)/;
/** 조건문·정의문·예시는 이론 설명으로 보고 제외한다. */
const THEORY_EXCLUSION = /(있으면|있다면|있는 사람|이라면|라면|경우|뜻|의미|말하|라고 (해|불러|부르)|이란|이라는|예를 들|예시|가령|만약)/;

function splitSentences(text: string): string[] {
  return text
    .split(/[\n.!?…]+/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

/** 이 문장이 "사용자 차트에 존재한다"는 귀속 주장인가. */
function isAttributedClaim(sentence: string): boolean {
  if (THEORY_EXCLUSION.test(sentence)) return false;
  return CHART_WORD.test(sentence) && PRESENCE_VERB.test(sentence);
}

/**
 * 답변에서 계산 근거에 없는 사주 사실 주장을 찾는다.
 * @param reply LLM이 생성한 답변 전문
 * @param evidenceText 계산 근거 직렬화 문자열 (buildNatalEvidence 출력 등)
 */
export function detectUngroundedSajuClaims(reply: string, evidenceText: string): GroundingHit[] {
  const hits: GroundingHit[] = [];
  const seen = new Set<string>();
  const push = (term: string, category: GroundingCategory, sentence: string) => {
    const key = `${category}:${term}`;
    if (seen.has(key)) return;
    seen.add(key);
    hits.push({ term, category, sentence });
  };

  for (const sentence of splitSentences(reply)) {
    // 신살·십성: 귀속 주장 문장에서만 본다.
    if (isAttributedClaim(sentence)) {
      for (const { root, evidenceKeys } of SINSAL_VOCAB) {
        if (!sentence.includes(root)) continue;
        if (evidenceKeys.some((k) => evidenceText.includes(k))) continue;
        push(root, "sinsal", sentence);
      }
      for (const { root, evidenceKeys } of TEN_GOD_VOCAB) {
        if (!sentence.includes(root)) continue;
        // "상관없-"류 일상어 오탐 방지
        if (root === "상관" && /상관\s*없/.test(sentence)) continue;
        if (evidenceKeys.some((k) => evidenceText.includes(k))) continue;
        push(root, "tenGod", sentence);
      }
      // 격국: "OO격" 패턴. 엔진이 계산한 격 이름이 근거에 없으면 주장 불가.
      // (한국어는 조사가 바로 붙으므로 "종살격으로"처럼 뒤에 글자가 이어져도 매치해야 한다.)
      const gyeokMatches = sentence.match(/[가-힣]{2,3}격/g) ?? [];
      for (const g of gyeokMatches) {
        if (evidenceText.includes(g)) continue;
        // "파격/성격/합격/자격/본격" 등 일상어 제외
        if (/^(파|성|합|자|본|골|품|규|엄|가)격$/.test(g) || /(파격|성격|합격|자격|본격|골격|품격|규격|엄격|가격)$/.test(g)) continue;
        push(g, "gyeokguk", sentence);
      }
    }

    // 간지: 기둥/운 문맥이 있는 문장에서만 본다 (갑자기·임신 등 일상어 충돌 방지).
    if (PILLAR_CONTEXT.test(sentence) && !THEORY_EXCLUSION.test(sentence)) {
      for (const gz of SIXTY_GANZHI) {
        const idx = sentence.indexOf(gz);
        if (idx === -1) continue;
        // "갑자기"의 갑자처럼 뒤에 글자가 붙어 다른 단어가 되는 경우 제외
        if (gz === "갑자" && sentence[idx + 2] === "기") continue;
        if (evidenceText.includes(gz)) continue;
        push(gz, "ganzhi", sentence);
      }
    }
  }

  return hits;
}

/** 감지 결과를 사용자에게 보여줄 경고 꼬리로 만든다. 감지가 없으면 null. */
export function formatGroundingWarning(hits: GroundingHit[]): string | null {
  if (hits.length === 0) return null;
  const terms = [...new Set(hits.map((h) => `"${h.term}"`))].slice(0, 5).join(", ");
  return `⚠️ 자동 근거 점검: 위 답변의 ${terms} 언급이 계산된 원국 데이터에서 확인되지 않아요. 공부용으로 보실 때는 이 부분을 만세력·원국 데이터와 대조해서 확인해 주세요.`;
}
