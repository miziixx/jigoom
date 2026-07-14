// 사주 학습모드 — 완전 규칙 기반(LLM 호출 0회) 21장 커리큘럼.
//
// 설계 원칙:
// · 토큰 비용 0: 강의·출제·채점·해설 전부 코드. Claude API를 전혀 부르지 않는다.
// · 교재 사주 고정: 누구의 사주도 아닌 임의 원국 "임진년 기묘월 갑술일 경오시"(일간 갑).
//   적용 문제의 정답은 하드코딩이 아니라 엔진(computeChartFromPillars)이 실시간 계산 → 이론과 엔진이 항상 일치.
// · 빡센 진행: 장마다 압축 강의 → 퀴즈(오답노트 복습 포함) → 80% 통과제. 미달이면 같은 장 재시험.
// · 영구 기억: 진도·오답노트·통계는 StudyState로 스토어에 저장(대화 history TTL과 무관).
//
// 이 파일의 이론 상수(합충형파해 표 등)는 명리학의 보편 상수라 엔진(src/lib/saju.ts)과 값이 같다.
// 엔진 내부 상수를 export로 노출하지 않기 위해 학습용으로만 여기 중복 정의한다(변하지 않는 값).
import { computeChartFromPillars, tenGodOf, twelveStageOf, gongmangOf, sibiSinsalOf } from "../src/lib/saju.js";
import type { SajuChart } from "../src/types/index.js";

// ── 상태 ──────────────────────────────────────────────

export interface StudyQuestion {
  /** 출제 장 번호 (오답노트 복습 문제는 원래 장 번호 유지) */
  chapter: number;
  prompt: string;
  /** 허용 정답(정규화 후 비교). 첫 항목이 대표 정답 표기. */
  answers: string[];
  explain: string;
  /** 오답노트에서 온 복습 문제면 true */
  isReview?: boolean;
}

export interface StudyState {
  /** 현재 학습 중인 장 (1~21). 22 = 전 과정 수료(자유 복습 모드) */
  chapter: number;
  /** 통과한 장 번호들 */
  passed: number[];
  /** 진행 중 퀴즈 (없으면 null — 다음 /학습 때 새로 출제) */
  quiz: StudyQuestion[] | null;
  qIndex: number;
  correctInQuiz: number;
  /** 미해소 오답 (복습에서 맞히면 제거). 최대 MAX_WRONG_NOTES개 유지. */
  wrongNotes: StudyQuestion[];
  stats: { answered: number; correct: number };
  startedAt: string;
}

export function emptyStudyState(): StudyState {
  return {
    chapter: 1,
    passed: [],
    quiz: null,
    qIndex: 0,
    correctInQuiz: 0,
    wrongNotes: [],
    stats: { answered: 0, correct: 0 },
    startedAt: new Date().toISOString(),
  };
}

const QUIZ_SIZE = 5; // 새 문제 수 (복습 문제는 여기에 +α)
const REVIEW_PER_QUIZ = 2; // 퀴즈당 오답노트 복습 최대 문항
const PASS_RATIO = 0.8;
const MAX_WRONG_NOTES = 20;
const GRAD_CHAPTER = 22;
const GRAD_QUIZ_SIZE = 10;

// ── 교재 사주 (모듈 로드 시 1회 계산, 이후 재사용) ──────────

export const TEXTBOOK_PILLARS = { year: "임진", month: "기묘", day: "갑술", hour: "경오" } as const;

let textbookChart: SajuChart | null = null;
export function getTextbookChart(): SajuChart {
  if (!textbookChart) {
    textbookChart = computeChartFromPillars({ ...TEXTBOOK_PILLARS });
  }
  return textbookChart;
}

const TEXTBOOK_LABEL = "교재 사주(임진년 기묘월 갑술일 경오시, 일간 갑)";

// ── 이론 상수 (보편 상수 — 학습 출제용) ──────────────────

const ELEMENTS = ["목", "화", "토", "금", "수"] as const;
type El = (typeof ELEMENTS)[number];
const GENERATES: Record<El, El> = { 목: "화", 화: "토", 토: "금", 금: "수", 수: "목" };
const OVERCOMES: Record<El, El> = { 목: "토", 화: "금", 토: "수", 금: "목", 수: "화" };

const GAN_INFO: Record<string, { el: El; yin: boolean }> = {
  갑: { el: "목", yin: false }, 을: { el: "목", yin: true },
  병: { el: "화", yin: false }, 정: { el: "화", yin: true },
  무: { el: "토", yin: false }, 기: { el: "토", yin: true },
  경: { el: "금", yin: false }, 신: { el: "금", yin: true },
  임: { el: "수", yin: false }, 계: { el: "수", yin: true },
};
const ZHI_INFO: Record<string, { el: El; yin: boolean }> = {
  자: { el: "수", yin: false }, 축: { el: "토", yin: true }, 인: { el: "목", yin: false },
  묘: { el: "목", yin: true }, 진: { el: "토", yin: false }, 사: { el: "화", yin: true },
  오: { el: "화", yin: false }, 미: { el: "토", yin: true }, 신: { el: "금", yin: false },
  유: { el: "금", yin: true }, 술: { el: "토", yin: false }, 해: { el: "수", yin: true },
};
const GANS = Object.keys(GAN_INFO);
const ZHIS = Object.keys(ZHI_INFO);

// 지장간 (여기→정기 순, 엔진 HIDDEN_STEMS와 동일)
const HIDDEN: Record<string, string[]> = {
  자: ["임", "계"], 축: ["계", "신", "기"], 인: ["무", "병", "갑"], 묘: ["갑", "을"],
  진: ["을", "계", "무"], 사: ["무", "경", "병"], 오: ["병", "기", "정"], 미: ["정", "을", "기"],
  신: ["무", "임", "경"], 유: ["경", "신"], 술: ["신", "정", "무"], 해: ["무", "갑", "임"],
};

const GAN_HE: Array<[string, string, string]> = [
  ["갑", "기", "토"], ["을", "경", "금"], ["병", "신", "수"], ["정", "임", "목"], ["무", "계", "화"],
];
const GAN_CHONG: Array<[string, string]> = [["갑", "경"], ["을", "신"], ["병", "임"], ["정", "계"]];
const LIUHE: Array<[string, string, string]> = [
  ["자", "축", "토"], ["인", "해", "목"], ["묘", "술", "화"], ["진", "유", "금"], ["사", "신", "수"], ["오", "미", "화"],
];
const SANHE: Array<{ group: string; el: El; wang: string }> = [
  { group: "인오술", el: "화", wang: "오" }, { group: "사유축", el: "금", wang: "유" },
  { group: "신자진", el: "수", wang: "자" }, { group: "해묘미", el: "목", wang: "묘" },
];
const FANGHE: Array<{ group: string; el: El }> = [
  { group: "인묘진", el: "목" }, { group: "사오미", el: "화" }, { group: "신유술", el: "금" }, { group: "해자축", el: "수" },
];
const CHONG: Array<[string, string]> = [["자", "오"], ["축", "미"], ["인", "신"], ["묘", "유"], ["진", "술"], ["사", "해"]];
const XING_GROUPS = [
  { name: "인사신 삼형", members: ["인", "사", "신"], gloss: "지세지형(믿는 힘끼리 부딪히는 형)" },
  { name: "축술미 삼형", members: ["축", "술", "미"], gloss: "무은지형(은혜가 원망으로 바뀌는 형)" },
  { name: "자묘형", members: ["자", "묘"], gloss: "무례지형(예의 없이 파고드는 형)" },
];
const SELF_XING = ["진", "오", "유", "해"];
const PO: Array<[string, string]> = [["자", "유"], ["축", "진"], ["인", "해"], ["묘", "오"], ["사", "신"], ["술", "미"]];
const HAI: Array<[string, string]> = [["자", "미"], ["축", "오"], ["인", "사"], ["묘", "진"], ["신", "해"], ["유", "술"]];
const WONJIN: Array<[string, string]> = [["자", "미"], ["축", "오"], ["인", "유"], ["묘", "신"], ["진", "해"], ["사", "술"]];
const GWIMUN: Array<[string, string]> = [["자", "유"], ["축", "오"], ["인", "미"], ["묘", "신"], ["진", "해"], ["사", "술"]];
const TOMB: Array<[string, string]> = [["진", "수"], ["술", "화"], ["축", "금"], ["미", "목"]]; // [창고 지지, 갈무리 오행]
const YANGIN: Array<[string, string]> = [["갑", "묘"], ["병", "오"], ["무", "오"], ["경", "유"], ["임", "자"]];
const SIX_REL: Array<[string, string]> = [
  ["비겁", "형제·자매, 친구·동료, 경쟁자"],
  ["식상", "(여성 기준) 자녀, 손아랫사람, 표현·재능"],
  ["재성", "(남성 기준) 아내·여자 인연, 부친, 재물"],
  ["관성", "(여성 기준) 남편, (남성 기준) 자녀, 직장·명예"],
  ["인성", "어머니, 스승·윗사람, 문서·자격·배움"],
];

// ── 유틸 ──────────────────────────────────────────────

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** 한국어 주격 조사: 받침 있으면 '이', 없으면 '가' */
function iGa(word: string): string {
  const code = word.charCodeAt(word.length - 1);
  if (code < 0xac00 || code > 0xd7a3) return `${word}이(가)`;
  return (code - 0xac00) % 28 > 0 ? `${word}이` : `${word}가`;
}

/** 채점용 정규화: 공백·구두점 제거, 소문자화. */
function norm(s: string): string {
  return s.toLowerCase().replace(/[\s.,·/()\[\]{}'"~!?:;\-_+=*#]/g, "");
}

/**
 * 채점: 정규화 후 (1) 완전 일치, (2) 정답이 2글자 이상이면 사용자 답 안에 포함돼도 인정.
 * ("신유" 정답에 "신유 공망"이라 답해도 정답)
 */
export function gradeAnswer(userText: string, answers: string[]): boolean {
  const u = norm(userText);
  if (!u) return false;
  for (const a of answers) {
    const n = norm(a);
    if (!n) continue;
    if (u === n) return true;
    if (n.length >= 2 && u.includes(n)) return true;
  }
  return false;
}

function q(chapter: number, prompt: string, answers: string[], explain: string): StudyQuestion {
  return { chapter, prompt, answers, explain };
}

// ── 21장 커리큘럼: 압축 강의 + 문제 풀(pool) ──────────────

interface Chapter {
  n: number;
  title: string;
  lesson: string;
  pool: () => StudyQuestion[];
}

const CHAPTERS: Chapter[] = [
  {
    n: 1,
    title: "음양오행(陰陽五行)",
    lesson: [
      "*1장 음양오행* — 모든 글자는 음/양 + 오행(목화토금수)을 갖는다.",
      "상생(生): 목→화→토→금→수→목 (낳아주는 순환)",
      "상극(克): 목→토→수→화→금→목 (누르는 순환)",
      "암기틀: 나무가 불을 살리고(목생화), 나무가 흙을 파고든다(목극토).",
    ].join("\n"),
    pool: () => {
      const out: StudyQuestion[] = [];
      for (const el of ELEMENTS) {
        out.push(q(1, `${iGa(el)} 생(生)하는 오행은?`, [GENERATES[el]], `상생 순환 목→화→토→금→수→목. ${el}생${GENERATES[el]}.`));
        out.push(q(1, `${iGa(el)} 극(克)하는 오행은?`, [OVERCOMES[el]], `상극 순환 목→토→수→화→금→목. ${el}극${OVERCOMES[el]}.`));
      }
      for (const g of shuffle([...GANS]).slice(0, 4)) {
        const info = GAN_INFO[g];
        out.push(q(1, `천간 ${g}의 오행과 음양은? (예: 양목)`, [`${info.yin ? "음" : "양"}${info.el}`], `${g} = ${info.yin ? "음" : "양"}${info.el}.`));
      }
      return out;
    },
  },
  {
    n: 2,
    title: "사주팔자(四柱八字)",
    lesson: [
      "*2장 사주팔자* — 연·월·일·시 네 기둥(사주), 기둥마다 천간+지지 = 여덟 글자(팔자).",
      "연주는 *입춘* 기준으로 바뀌고, 월주는 *절기(절입)* 기준, 일주는 60갑자가 60일 주기로 순환.",
      "일간(일주의 천간) = '나'. 모든 십신·강약 판정의 기준점.",
    ].join("\n"),
    pool: () => {
      const c = getTextbookChart();
      return [
        q(2, "사주에서 연주가 바뀌는 기준이 되는 절기는?", ["입춘"], "1월 1일이 아니라 입춘(대략 2/4)부터 새해 간지로 본다."),
        q(2, "월주가 바뀌는 기준은? (양력 1일 / 절기 중)", ["절기", "절입"], "매월 절입일(입춘·경칩·청명…)부터 다음 월주가 시작된다."),
        q(2, "일주는 며칠 주기로 같은 간지가 돌아오나?", ["60", "60일", "육십"], "60갑자가 하루에 하나씩 → 60일 주기."),
        q(2, "사주팔자에서 '나 자신'을 뜻하는 글자는?", ["일간"], "일주의 천간(일간)이 나. 나머지 일곱 글자는 일간과의 관계로 읽는다."),
        q(2, `${TEXTBOOK_LABEL}의 일간은?`, [c.dayMasterGan], `일주 ${c.day.ganZhi}의 천간 = ${c.dayMasterGan}.`),
        q(2, "출생 시간을 모르면 네 기둥 중 어느 기둥이 빠지나?", ["시주"], "시주 제외 3주(6글자)로 해석하고 그 한계를 밝힌다."),
      ];
    },
  },
  {
    n: 3,
    title: "천간지지(天干地支)와 지장간",
    lesson: [
      "*3장 천간지지* — 천간 10개(갑을병정무기경신임계), 지지 12개(자축인묘진사오미신유술해).",
      "지지 속에는 천간이 숨어 있다 = *지장간*(여기→중기→정기, 마지막이 정기·본기).",
      "예: 술 = 신·정·무 (정기 무토). 지장간이 통근·투출·격국의 재료가 된다.",
    ].join("\n"),
    pool: () => {
      const out: StudyQuestion[] = [];
      for (const z of shuffle([...ZHIS]).slice(0, 6)) {
        const hs = HIDDEN[z];
        out.push(q(3, `지지 ${z}의 정기(본기) 천간은?`, [hs[hs.length - 1]], `${z}의 지장간은 ${hs.join("·")} — 마지막이 정기.`));
      }
      for (const z of shuffle([...ZHIS]).slice(0, 3)) {
        const info = ZHI_INFO[z];
        out.push(q(3, `지지 ${z}의 오행은?`, [info.el], `${z} = ${info.yin ? "음" : "양"}${info.el}.`));
      }
      out.push(q(3, "지장간에서 '정기'란?", ["본기", "그 지지의 대표 기운", "마지막 기운"], "여기→중기→정기 중 가장 힘 있는 대표 기운(본기)."));
      return out;
    },
  },
  {
    n: 4,
    title: "궁위(宮位)",
    lesson: [
      "*4장 궁위* — 네 기둥은 각각 삶의 자리를 맡는다.",
      "연주=조상·집안·초년 / 월주=부모·형제·직업환경·청년기 / 일주=나(일간)와 배우자(일지) / 시주=자식·말년.",
      "특히 *일지 = 배우자궁*, *월지 = 사주의 중심(계절·세력)*.",
    ].join("\n"),
    pool: () => [
      q(4, "배우자궁은 여덟 글자 중 어느 자리?", ["일지"], "일지가 배우자·가장 가까운 관계의 자리."),
      q(4, "부모·형제와 직업 환경을 함께 보는 기둥은?", ["월주"], "월주 = 성장·사회 진출의 자리."),
      q(4, "자식과 말년을 보는 기둥은?", ["시주"], "시주 = 결실·노후·아랫사람의 자리."),
      q(4, "조상·집안 배경·초년운을 보는 기둥은?", ["연주"], "연주 = 뿌리와 초년의 자리."),
      q(4, "사주 전체의 계절·세력 중심이 되는 글자는?", ["월지"], "월지가 격국·강약 판정의 중심."),
      q(4, `${TEXTBOOK_LABEL}에서 배우자궁의 글자는?`, [getTextbookChart().day.zhi], `일지 = ${getTextbookChart().day.zhi}.`),
    ],
  },
  {
    n: 5,
    title: "십신(十神)",
    lesson: [
      "*5장 십신* — 일간과 다른 글자의 생극(生克)×음양으로 10가지 관계가 나온다.",
      "나와 같은 오행=비견(음양 같음)·겁재(다름) / 내가 생=식신(같음)·상관(다름)",
      "내가 극=편재(같음)·정재(다름) / 나를 극=편관(같음)·정관(다름) / 나를 생=편인(같음)·정인(다름)",
      "암기틀: 같은 극성은 '편·비·식', 다른 극성은 '정·겁·상'.",
    ].join("\n"),
    pool: () => {
      const dayGan = getTextbookChart().dayMasterGan; // 갑
      const out: StudyQuestion[] = [];
      for (const g of shuffle(GANS.filter((g) => g !== dayGan)).slice(0, 7)) {
        const tg = tenGodOf(dayGan, g);
        out.push(q(5, `일간 ${dayGan} 기준, 천간 ${g}의 십신은?`, [tg], `${dayGan}(${GAN_INFO[dayGan].el})와 ${g}(${GAN_INFO[g].el})의 생극×음양 → ${tg}.`));
      }
      out.push(q(5, "일간이 극(克)하는 오행이면서 음양이 다른 십신은?", ["정재"], "내가 극 + 음양 다름 = 정재. 같으면 편재."));
      out.push(q(5, "일간을 생(生)해주는 오행이면서 음양이 같은 십신은?", ["편인"], "나를 생 + 음양 같음 = 편인. 다르면 정인."));
      return out;
    },
  },
  {
    n: 6,
    title: "육친(六親)",
    lesson: [
      "*6장 육친* — 십신을 실제 가족·인간관계로 옮긴다.",
      "비겁=형제·동료 / 식상=(여)자녀·표현 / 재성=(남)아내·부친·재물 / 관성=(여)남편·(남)자녀·직장 / 인성=어머니·문서·스승.",
      "성별에 따라 배우자·자식 대응이 갈리는 게 핵심.",
    ].join("\n"),
    pool: () => {
      const out: StudyQuestion[] = SIX_REL.map(([grp, rel]) =>
        q(6, `십신 그룹 '${grp}'이 상징하는 육친·관계는? (하나만 답해도 됨)`, rel.split(/[,·]/).map((s) => s.replace(/\(.+?\)/g, "").trim()).filter(Boolean), `${grp} = ${rel}.`),
      );
      out.push(q(6, "남성 사주에서 아내를 뜻하는 십신 그룹은?", ["재성", "정재"], "남성에게 재성(특히 정재)이 아내."));
      out.push(q(6, "여성 사주에서 남편을 뜻하는 십신 그룹은?", ["관성", "정관"], "여성에게 관성(특히 정관)이 남편."));
      out.push(q(6, "남녀 모두에게 어머니를 뜻하는 십신 그룹은?", ["인성", "정인"], "나를 생해주는 인성이 어머니."));
      out.push(q(6, "여성 사주에서 자녀를 뜻하는 십신 그룹은?", ["식상", "식신", "상관"], "내가 낳는(생하는) 식상이 여성의 자녀."));
      return out;
    },
  },
  {
    n: 7,
    title: "강약(强弱) — 신강·신약",
    lesson: [
      "*7장 강약* — 일간이 든든한가(신강) 허한가(신약).",
      "득령: 월지가 일간을 돕는 오행(비겁·인성)인가 — 가장 큰 비중.",
      "득지: 일지가 돕는가 / 득세: 전체 글자 중 돕는 세력이 많은가.",
      "돕는 편 = 비겁(같은 오행)+인성(나를 생). 빼는 편 = 식상·재성·관성.",
    ].join("\n"),
    pool: () => {
      const c = getTextbookChart();
      return [
        q(7, "강약 판정에서 가장 비중이 큰 자리는?", ["월지"], "월령(계절)을 얻었는지 = 득령이 최우선."),
        q(7, "월지가 일간을 돕는 오행일 때를 뭐라고 하나?", ["득령"], "득령 = 계절의 힘을 얻음."),
        q(7, "일지가 일간을 돕는 오행일 때는?", ["득지"], "득지 = 앉은 자리의 힘."),
        q(7, "일간을 돕는 십신 두 그룹은? (예: ○○과 ○○)", ["비겁과 인성", "비겁 인성", "인성 비겁", "인성과 비겁"], "같은 오행(비겁) + 나를 생(인성)이 돕는 편."),
        q(7, `${TEXTBOOK_LABEL}의 강약 판정은? (신강/신약/중화)`, [c.strength!.label], `엔진 판정: ${c.strength!.label}. ${c.strength!.detail}`),
        q(7, `${TEXTBOOK_LABEL}은 득령했나? (예/아니오)`, [c.strength!.detail.includes("득령") ? "예" : "아니오", c.strength!.detail.includes("득령") ? "득령" : "실령"], `월지 ${c.month.zhi}(${ZHI_INFO[c.month.zhi].el})와 일간 ${c.dayMasterGan}(${GAN_INFO[c.dayMasterGan].el})의 관계로 판단. ${c.strength!.detail}`),
      ];
    },
  },
  {
    n: 8,
    title: "통근(通根)·투출(透出)",
    lesson: [
      "*8장 통근·투출* — 천간과 지지가 연결돼야 힘이 실린다.",
      "통근: 천간이 지지의 지장간에 같은 오행 뿌리를 둠. 정기 통근이 가장 단단.",
      "투출: 월지 지장간이 천간에 드러남 → 그 십신이 격국으로 뚜렷하게 작동.",
      "뿌리 없는 천간은 뜬 기운, 투출 없는 월령은 잠재된 기운.",
    ].join("\n"),
    pool: () => {
      const c = getTextbookChart();
      const rootCount = (c.rootedness ?? []).length;
      return [
        q(8, "천간이 지지 지장간에 같은 오행의 뿌리를 두는 것을 뭐라 하나?", ["통근"], "통근(通根) — 뿌리를 통함."),
        q(8, "월지의 지장간이 천간에 드러나는 것을 뭐라 하나?", ["투출", "투간"], "투출(透出) — 격국이 뚜렷해지는 조건."),
        q(8, "지장간 세 위상(여기·중기·정기) 중 통근이 가장 단단한 것은?", ["정기"], "정기 통근 > 중기 > 여기."),
        q(8, "뿌리(통근) 없이 천간에만 뜬 기운은 강한가 약한가?", ["약하다", "약함", "약"], "지지에 뿌리가 없으면 쉽게 흔들린다."),
        q(8, `${TEXTBOOK_LABEL}에서 통근한 천간은 몇 개인가? (숫자)`, [String(rootCount)], `엔진 계산: ${rootCount}건. ${(c.rootedness ?? []).map((r) => r.note).join(" ")}`),
      ];
    },
  },
  {
    n: 9,
    title: "생목(生木)·사목(死木) — 물상 활력",
    lesson: [
      "*9장 생목·사목* — 일간을 물상(자연물)에 빗대 활력을 본다.",
      "갑목=큰 나무: 물(수, 뿌리 적심)·햇빛(화)·땅(토)이 갖춰지면 생목, 없으면 사목.",
      "사목은 흉이 아니라 '재목으로 쓰이는 나무' — 다만 금(도끼)이 강한데 화가 없으면 눌린다.",
      "다른 일간도 같은 원리: 정화=촛불(땔감 목 필요), 임수=강물(제방 토 필요) 등.",
    ].join("\n"),
    pool: () => {
      const c = getTextbookChart();
      return [
        q(9, "갑목이 생목(生木)이 되기 위해 필요한 오행 셋은? (하나만 답해도 됨)", ["수", "화", "토", "물", "햇빛", "땅"], "물(수)·햇빛(화)·땅(토)이 갖춰져야 살아 있는 나무."),
        q(9, "정화(丁火)를 물상으로 빗대면?", ["촛불", "등불", "화롯불"], "정화 = 촛불·등불. 땔감(목)이 있어야 이어진다."),
        q(9, "임수(壬水)가 범람하지 않으려면 필요한 오행은?", ["토", "제방", "흙"], "임수 = 큰 강물. 토(제방)가 물길을 잡는다."),
        q(9, "사목(死木)은 반드시 흉한가? (예/아니오)", ["아니오", "아니", "no"], "사목은 다듬어 쓰는 재목의 상 — 길흉 단정이 아니라 기운이 쓰이는 방식의 차이."),
        q(9, `${TEXTBOOK_LABEL}의 생목·사목 판정은? (생/조건부 생/사)`, [c.livingState!.verdict, c.livingState!.verdict.replace(/\(.+?\)/g, "")], `엔진 판정: ${c.livingState!.verdict}. ${c.livingState!.note}`),
      ];
    },
  },
  {
    n: 10,
    title: "천간합충(天干合沖)",
    lesson: [
      "*10장 천간합충* — 천간끼리의 관계.",
      "5합: 갑기(토)·을경(금)·병신(수)·정임(목)·무계(화) — 여섯 번째 천간과 합.",
      "4충(칠충): 갑경·을신·병임·정계 — 오행 상극 + 음양 같음의 정면충돌. 무기(토)는 중앙이라 충 없음.",
    ].join("\n"),
    pool: () => {
      const out: StudyQuestion[] = [];
      for (const [a, b, el] of GAN_HE) {
        out.push(q(10, `천간합 ${a}${b}합의 결과 오행은?`, [el], `${a}${b}합 → ${el}. (갑기토·을경금·병신수·정임목·무계화)`));
      }
      for (const [a, b] of GAN_CHONG) {
        out.push(q(10, `천간 ${a}과(와) 충(沖)하는 천간은?`, [b], `${a}${b}충 — 상극이면서 음양이 같은 정면충돌.`));
      }
      out.push(q(10, "천간충이 없는 두 천간(중앙 토)은?", ["무기", "무와 기", "기무"], "무·기(토)는 중앙이라 충이 성립하지 않는다."));
      const c = getTextbookChart();
      if ((c.stemClashes ?? []).length > 0) {
        out.push(q(10, `${TEXTBOOK_LABEL}에 있는 천간충은? (예: 갑경충)`, c.stemClashes!.map((s) => s.split(" ").pop()!), `엔진 계산: ${c.stemClashes!.join(", ")}.`));
      }
      return out;
    },
  },
  {
    n: 11,
    title: "지지합(地支合)",
    lesson: [
      "*11장 지지합* — 육합·삼합·반합·방합.",
      "육합 6쌍: 자축(토)·인해(목)·묘술(화)·진유(금)·사신(수)·오미(화).",
      "삼합 4국: 인오술(화)·사유축(금)·신자진(수)·해묘미(목) — 가운데가 왕지. 왕지 포함 2글자면 반합.",
      "방합 4국: 인묘진(목)·사오미(화)·신유술(금)·해자축(수) — 같은 계절끼리.",
    ].join("\n"),
    pool: () => {
      const out: StudyQuestion[] = [];
      for (const [a, b, el] of shuffle([...LIUHE]).slice(0, 3)) {
        out.push(q(11, `육합 ${a}${b}합의 결과 오행은?`, [el], `${a}${b}합 → ${el}.`));
      }
      for (const s of SANHE) {
        out.push(q(11, `삼합 ${s.group}이 이루는 오행 국(局)은?`, [s.el], `${s.group} → ${s.el}국. 왕지는 ${s.wang}.`));
      }
      out.push(q(11, "삼합에서 반합이 성립하려면 반드시 포함해야 하는 글자는? (왕지/생지/묘지 중)", ["왕지"], "왕지(자오묘유)가 낀 2글자만 반합으로 본다."));
      for (const f of shuffle([...FANGHE]).slice(0, 2)) {
        out.push(q(11, `방합 ${f.group}의 오행은?`, [f.el], `${f.group} = 같은 계절 묶음 → ${f.el}.`));
      }
      return out;
    },
  },
  {
    n: 12,
    title: "충(沖)",
    lesson: [
      "*12장 지지충* — 정반대 자리끼리의 충돌. 6쌍: 자오·축미·인신·묘유·진술·사해.",
      "작용: 그 궁위(자리)가 흔들림·이동·변화. 왕지끼리(자오·묘유)는 세게, 묘고끼리(진술·축미)는 창고를 연다(개고).",
    ].join("\n"),
    pool: () => {
      const out: StudyQuestion[] = [];
      for (const [a, b] of shuffle([...CHONG]).slice(0, 4)) {
        out.push(q(12, `지지 ${a}와(과) 충하는 지지는?`, [b], `${a}${b}충. 여섯 칸 건너 정반대 자리끼리.`));
      }
      const c = getTextbookChart();
      const chongHits = (c.interactionDetails ?? []).filter((d) => d.kind === "충");
      if (chongHits.length > 0) {
        out.push(q(12, `${TEXTBOOK_LABEL}에 있는 지지충은? (예: 자오충)`, chongHits.map((d) => `${d.chars}충`), `엔진 계산: ${chongHits.map((d) => d.label).join(", ")}.`));
      }
      out.push(q(12, "묘고(진술축미)끼리의 충이 특별한 이유는? (한 단어)", ["개고", "창고가 열림", "창고"], "진술충·축미충은 잠긴 창고를 여는 개고 작용."));
      return out;
    },
  },
  {
    n: 13,
    title: "형(刑)",
    lesson: [
      "*13장 형* — 겉은 조용한데 속으로 쌓이는 압박·긴장.",
      "삼형 2조: 인사신(지세지형)·축술미(무은지형) / 상형: 자묘(무례지형) / 자형: 진진·오오·유유·해해.",
      `${TEXTBOOK_LABEL}에는 형이 없다 — 축이나 미가 오면 술과 축술미형이 성립하는 구조.`,
    ].join("\n"),
    pool: () => {
      const out: StudyQuestion[] = [];
      for (const g of XING_GROUPS) {
        out.push(q(13, `${g.name.replace(" 삼형", "").replace("형", "")}… 이 조합의 형 이름은? → ${g.members.join("·")}이 이루는 형은?`, [g.name, g.name.replace(" ", "")], `${g.name} = ${g.gloss}.`));
      }
      out.push(q(13, "자형(自刑)이 되는 지지 네 글자는? (하나만 답해도 됨)", SELF_XING, `진·오·유·해가 같은 글자끼리 만나면 자형.`));
      out.push(q(13, `${TEXTBOOK_LABEL}의 지지(진묘술오)에 어떤 지지가 오면 축술미 삼형이 완성되나? (두 글자)`, ["축미", "미축", "축과 미", "미와 축"], "원국에 술이 있으니 축+미가 모두 오면 축술미 삼형."),
      );
      return out;
    },
  },
  {
    n: 14,
    title: "파(破)",
    lesson: [
      "*14장 파* — 깨짐·어긋남·계획 수정. 6쌍: 자유·축진·인해·묘오·사신·술미.",
      "충보다 약하지만 합을 깨거나 일을 어긋나게 하는 잔 진동.",
      `교재 사주에는 *묘오파*(월지-시지)가 있다.`,
    ].join("\n"),
    pool: () => {
      const out: StudyQuestion[] = [];
      for (const [a, b] of shuffle([...PO]).slice(0, 4)) {
        out.push(q(14, `지지 ${a}와(과) 파(破)가 되는 지지는?`, [b], `${a}${b}파.`));
      }
      out.push(q(14, `${TEXTBOOK_LABEL}에 있는 파는?`, ["묘오파", "묘오"], "월지 묘 - 시지 오 = 묘오파."));
      out.push(q(14, "파의 작용을 한 단어로? (깨짐/충돌/속박 중)", ["깨짐"], "파 = 깨짐·어긋남·계획 수정."));
      return out;
    },
  },
  {
    n: 15,
    title: "해(害)",
    lesson: [
      "*15장 해* — 은근한 방해·오해·미묘한 불편. 6쌍: 자미·축오·인사·묘진·신해·유술.",
      "육합을 충으로 깨는 자리끼리 성립(예: 자축합을 오가 충해서 자미해).",
      `교재 사주에는 *묘진해*(월지-연지)가 있다.`,
    ].join("\n"),
    pool: () => {
      const out: StudyQuestion[] = [];
      for (const [a, b] of shuffle([...HAI]).slice(0, 4)) {
        out.push(q(15, `지지 ${a}와(과) 해(害)가 되는 지지는?`, [b], `${a}${b}해.`));
      }
      out.push(q(15, `${TEXTBOOK_LABEL}에 있는 해는?`, ["묘진해", "묘진"], "연지 진 - 월지 묘 = 묘진해."));
      out.push(q(15, "해의 작용을 고르면? (정면충돌 / 은근한 방해)", ["은근한 방해", "은근한방해", "방해"], "해 = 은근한 방해·오해. 충처럼 요란하지 않다."));
      return out;
    },
  },
  {
    n: 16,
    title: "원진(怨嗔)·귀문(鬼門)",
    lesson: [
      "*16장 원진·귀문* — 지지 쌍 신살.",
      "원진 6쌍: 자미·축오·인유·묘신·진해·사술 — 이유 없이 껄끄럽고 미워지는 기운.",
      "귀문 6쌍: 자유·축오·인미·묘신·진해·사술 — 예민·직관·집착·신경과민.",
      "축오·묘신·진해·사술은 원진이자 귀문(겹침). 교재 사주에는 둘 다 없다.",
    ].join("\n"),
    pool: () => {
      const out: StudyQuestion[] = [];
      for (const [a, b] of shuffle([...WONJIN]).slice(0, 3)) {
        out.push(q(16, `지지 ${a}와(과) 원진이 되는 지지는?`, [b], `${a}${b} 원진.`));
      }
      for (const [a, b] of shuffle([...GWIMUN]).slice(0, 2)) {
        out.push(q(16, `지지 ${a}와(과) 귀문이 되는 지지는?`, [b], `${a}${b} 귀문.`));
      }
      out.push(q(16, "원진의 기운을 한 줄로 고르면? (정면충돌 / 이유 없는 미움 / 창고 열림)", ["이유 없는 미움", "이유없는미움", "미움"], "원진 = 이유 없이 껄끄럽고 미워지기 쉬운 감정의 기운."));
      out.push(q(16, "귀문의 기운은? (예민·집착 / 재물 창고 / 이동)", ["예민", "집착", "예민집착", "신경과민"], "귀문 = 예민·직관·집착·신경과민."));
      return out;
    },
  },
  {
    n: 17,
    title: "공망(空亡)",
    lesson: [
      "*17장 공망* — 60갑자를 10개씩 6순(旬)으로 나누면, 각 순마다 지지 2개가 짝 없이 빈다 = 순중공망.",
      "일주가 속한 순의 빈 지지 2개가 그 사람의 공망. 공망 맞은 자리는 기운이 헛도는·비워지는 상.",
      "예: 갑술일주는 갑술순(갑술~계미) 소속 → 신·유가 공망.",
    ].join("\n"),
    pool: () => {
      const out: StudyQuestion[] = [];
      const samples: Array<[string, string]> = [["갑", "자"], ["갑", "술"], ["경", "진"], ["임", "인"], ["병", "오"]];
      for (const [g, z] of shuffle(samples).slice(0, 3)) {
        const gm = gongmangOf(g, z);
        out.push(q(17, `${g}${z}일주의 공망 지지 2개는? (예: 자축)`, [gm, gm.split("").reverse().join("")], `${g}${z}은 해당 순(旬)에서 ${gm}이 빈다.`));
      }
      out.push(q(17, "공망은 무엇을 기준으로 정하나? (연주/월주/일주)", ["일주"], "일주가 속한 순(旬)의 빈 지지 2개."));
      out.push(q(17, `${TEXTBOOK_LABEL}의 공망은?`, ["신유", "유신"], `갑술일주 → 신유 공망. 원국 지지(진묘술오)에는 없어 공망 히트 없음.`));
      out.push(q(17, "공망 맞은 자리의 기운은? (강해짐 / 헛돌고 비워짐)", ["헛돌고 비워짐", "비워짐", "헛돎", "헛돌"], "공망 = 채워지지 않고 비는 상. 단정적 흉은 아니다."));
      return out;
    },
  },
  {
    n: 18,
    title: "묘고(墓庫)와 개고(開庫)",
    lesson: [
      "*18장 묘고* — 진·술·축·미는 오행의 창고(墓庫).",
      "진=수고, 술=화고, 축=금고, 미=목고. 창고 속 기운(중기)은 평소 잠겨 있다.",
      "충(진술충·축미충)이나 축술미 삼형으로 열리면(개고) 갈무리된 기운을 쓸 수 있게 된다.",
      "교재 사주는 진술충으로 수고(진)와 화고(술)가 *둘 다 열린* 구조.",
    ].join("\n"),
    pool: () => {
      const out: StudyQuestion[] = [];
      for (const [zhi, el] of TOMB) {
        out.push(q(18, `${zhi}는 무슨 오행의 창고(고)인가?`, [el, `${el}고`], `${zhi} = ${el}의 묘고. (진수·술화·축금·미목)`));
      }
      out.push(q(18, "창고가 충·형으로 열리는 것을 뭐라 하나?", ["개고"], "개고(開庫) — 잠긴 중기가 드러나 쓸 수 있게 됨."));
      out.push(q(18, `${TEXTBOOK_LABEL}에서 개고를 일으키는 상호작용은?`, ["진술충"], "연지 진 - 일지 술의 진술충이 두 창고를 연다."));
      return out;
    },
  },
  {
    n: 19,
    title: "12운성(十二運星)",
    lesson: [
      "*19장 12운성* — 일간이 각 지지에서 갖는 기운의 생애 국면 12단계.",
      "순서: 장생→목욕→관대→건록→제왕→쇠→병→사→묘→절→태→양 (그리고 다시 장생).",
      "양간은 순행, 음간은 역행. 갑목은 해에서 장생, 묘에서 제왕, 오에서 사.",
    ].join("\n"),
    pool: () => {
      const dayGan = getTextbookChart().dayMasterGan;
      const out: StudyQuestion[] = [];
      out.push(q(19, "12운성에서 '제왕' 바로 다음 단계는?", ["쇠"], `순서: …건록→제왕→쇠→병→사…`));
      out.push(q(19, "12운성의 첫 단계(태어남)는?", ["장생"], `장생→목욕→관대→건록→제왕→…`));
      for (const z of shuffle([...ZHIS]).slice(0, 4)) {
        const st = twelveStageOf(dayGan, z);
        out.push(q(19, `일간 ${dayGan}이 지지 ${z}에서 갖는 12운성은?`, [st], `${dayGan}(양간, 순행) 기준 ${z} = ${st}.`));
      }
      out.push(q(19, "12운성에서 양간과 음간의 진행 방향 차이는? (순행·역행)", ["양간은 순행 음간은 역행", "양간순행음간역행", "순행역행", "양순음역"], "양간은 지지 순서대로(순행), 음간은 거꾸로(역행)."));
      return out;
    },
  },
  {
    n: 20,
    title: "12신살(十二神煞)",
    lesson: [
      "*20장 12신살* — 일지(또는 년지)의 삼합국을 기준으로 12지지에 배당되는 살.",
      "겁살→재살→천살→지살→년살(도화)→월살→망신살→장성살→반안살→역마살→육해살→화개살.",
      "암기 앵커: 삼합 첫 글자=지살, 왕지=장성살, 끝 글자(묘고)=화개살. 왕지 다음이 도화(년살), 생지 충하는 자리가 역마.",
    ].join("\n"),
    pool: () => {
      const c = getTextbookChart();
      const baseZhi = c.day.zhi; // 술 → 인오술 화국
      const out: StudyQuestion[] = [];
      const samples = shuffle([...ZHIS]).slice(0, 4);
      for (const z of samples) {
        const s = sibiSinsalOf(baseZhi, z);
        out.push(q(20, `${TEXTBOOK_LABEL} — 일지 ${baseZhi}(인오술 화국) 기준, 지지 ${z}의 십이신살은?`, [s, s.replace(/살$/, "")], `화국 기준 ${z} = ${s}.`));
      }
      out.push(q(20, "삼합국의 왕지에 배당되는 신살은?", ["장성살", "장성"], "왕지(자오묘유) = 장성살."));
      out.push(q(20, "'도화'라고도 불리는 신살은?", ["년살", "연살", "도화살"], "년살 = 도화. 왕지 바로 다음 자리."));
      out.push(q(20, "삼합 묘고 글자(진술축미)에 배당되는 신살은?", ["화개살", "화개"], "끝 글자(묘고) = 화개살."));
      return out;
    },
  },
  {
    n: 21,
    title: "기타 신살",
    lesson: [
      "*21장 기타 신살* — 일간·월지·년지 기준의 길신과 흉살.",
      "길신: 천을귀인(최고 길신)·천덕·월덕·문창(공부)·금여(배우자복)·암록(숨은 복).",
      "흉살류: 양인(갑묘·병오·무오·경유·임자, 강한 칼기운)·괴강(경진·경술·무술·임진·임술)·백호·현침·홍염.",
      "신살은 보조 근거 — 단독으로 길흉을 단정하지 않는다.",
    ].join("\n"),
    pool: () => {
      const c = getTextbookChart();
      const sinsalNames = (c.sinsal ?? []).map((s) => s.name);
      const out: StudyQuestion[] = [];
      for (const [g, z] of shuffle([...YANGIN]).slice(0, 3)) {
        out.push(q(21, `일간 ${g}의 양인(羊刃) 지지는?`, [z], `양인: 갑묘·병오·무오·경유·임자. ${g} → ${z}.`));
      }
      out.push(q(21, "신살 중 '최고의 길신'으로 꼽히는 귀인은?", ["천을귀인", "천을"], "천을귀인 — 위기에서 돕는 사람이 나타나는 길신."));
      out.push(q(21, "공부·글재주의 길신은? (문창/역마/화개)", ["문창", "문창귀인"], "문창귀인 = 학문·표현의 길신."));
      out.push(q(21, `${TEXTBOOK_LABEL}의 연주 임진이 해당하는 강한 기둥 신살은?`, ["괴강", "괴강살"], `괴강(경진·경술·무술·임진·임술) — 극단의 힘·리더십.`));
      if (sinsalNames.includes("양인")) {
        out.push(q(21, `${TEXTBOOK_LABEL}에서 양인이 놓인 자리는? (연지/월지/일지/시지)`, ["월지"], "일간 갑의 양인은 묘 — 월지에 있다."));
      }
      out.push(q(21, "신살 해석의 대원칙은? (단독 단정 / 보조 근거)", ["보조 근거", "보조근거", "보조"], "신살은 보조 근거로만. 단독으로 길흉을 단정하지 않는다."));
      return out;
    },
  },
];

export const TOTAL_CHAPTERS = CHAPTERS.length; // 21

function chapterOf(n: number): Chapter | null {
  return CHAPTERS.find((c) => c.n === n) ?? null;
}

// ── 퀴즈 빌드 ──────────────────────────────────────────

/** 현재 장 퀴즈 생성: 오답노트 복습(최대 2) + 새 문제 5. */
function buildQuiz(state: StudyState): StudyQuestion[] {
  const reviews = shuffle([...state.wrongNotes])
    .slice(0, REVIEW_PER_QUIZ)
    .map((w) => ({ ...w, isReview: true }));
  if (state.chapter >= GRAD_CHAPTER) {
    // 수료 후 자유 복습: 전 장에서 무작위 출제
    const all = CHAPTERS.flatMap((c) => c.pool());
    return [...reviews, ...shuffle(all).slice(0, GRAD_QUIZ_SIZE - reviews.length)];
  }
  const ch = chapterOf(state.chapter)!;
  const fresh = shuffle(ch.pool()).slice(0, QUIZ_SIZE);
  return [...reviews, ...fresh];
}

function questionHeader(state: StudyState): string {
  const cur = state.quiz![state.qIndex];
  const tag = cur.isReview ? "🔁 복습" : `${cur.chapter}장`;
  return `*[${tag} · ${state.qIndex + 1}/${state.quiz!.length}]* ${cur.prompt}`;
}

// ── 공개 API: 시작 / 답변 처리 / 진도 ──────────────────────

export interface StudyReply {
  state: StudyState;
  message: string;
}

/** /학습 진입(이어하기 포함). jumpTo를 주면 해당 장으로 이동. */
export function startStudy(existing: StudyState | null, jumpTo?: number): StudyReply {
  const state = existing ? { ...existing } : emptyStudyState();
  if (jumpTo && jumpTo >= 1 && jumpTo <= TOTAL_CHAPTERS) {
    state.chapter = jumpTo;
    state.quiz = null;
  }

  const lines: string[] = [];
  if (!existing) {
    lines.push("📚 *사주 학습모드*를 시작해요! (전 과정 21장, 문제·채점은 계산 엔진 기반)");
    lines.push(`교재 사주는 고정이에요 — 누구의 사주도 아닌 연습용: *임진년 기묘월 갑술일 경오시* (일간 갑)`);
    lines.push("규칙: 장마다 강의 → 문제 5개 → *80% 이상*이면 다음 장. 틀린 문제는 오답노트로 계속 따라와요.");
    lines.push("답은 그냥 채팅으로 보내면 돼요. 모르겠으면 `패스`, 그만두려면 `/학습종료`.");
    lines.push("");
  } else if (state.quiz && state.qIndex < state.quiz.length) {
    // 진행 중이던 퀴즈 이어하기
    lines.push(`이어서 할게요. (${state.chapter >= GRAD_CHAPTER ? "자유 복습" : `${state.chapter}장`} 진행 중)`);
    lines.push("");
    lines.push(questionHeader(state));
    return { state, message: lines.join("\n") };
  } else {
    lines.push(formatProgressShort(state));
    lines.push("");
  }

  if (state.chapter >= GRAD_CHAPTER) {
    state.quiz = buildQuiz(state);
    state.qIndex = 0;
    state.correctInQuiz = 0;
    lines.push("🎓 전 과정을 이미 수료했어요! 전 장 무작위 복습 퀴즈를 드릴게요.");
    lines.push("");
    lines.push(questionHeader(state));
    return { state, message: lines.join("\n") };
  }

  const ch = chapterOf(state.chapter)!;
  state.quiz = buildQuiz(state);
  state.qIndex = 0;
  state.correctInQuiz = 0;

  lines.push(ch.lesson);
  lines.push("");
  const reviewCount = state.quiz.filter((x) => x.isReview).length;
  lines.push(`이제 문제 ${state.quiz.length}개 나갑니다${reviewCount > 0 ? ` (오답 복습 ${reviewCount}개 포함)` : ""}. 통과 기준 80%!`);
  lines.push("");
  lines.push(questionHeader(state));
  return { state, message: lines.join("\n") };
}

/** 학습모드 진행 중 사용자의 답 처리. */
export function answerStudy(prev: StudyState, userText: string): StudyReply {
  const state: StudyState = { ...prev, wrongNotes: [...prev.wrongNotes], stats: { ...prev.stats } };
  if (!state.quiz || state.qIndex >= state.quiz.length) {
    // 퀴즈가 없으면 새로 시작
    return startStudy(state);
  }

  const cur = state.quiz[state.qIndex];
  const isPass = /^(패스|pass|모르겠|몰라|skip)/i.test(userText.trim());
  const correct = !isPass && gradeAnswer(userText, cur.answers);

  state.stats.answered += 1;
  const lines: string[] = [];

  if (correct) {
    state.stats.correct += 1;
    state.correctInQuiz += 1;
    lines.push(`✅ 정답! *${cur.answers[0]}*`);
    if (cur.isReview) {
      // 복습 문제를 맞히면 오답노트에서 해소
      state.wrongNotes = state.wrongNotes.filter((w) => w.prompt !== cur.prompt);
      lines.push("(오답노트에서 지웠어요 👋)");
    }
  } else {
    lines.push(isPass ? `⏭️ 패스 — 정답은 *${cur.answers[0]}*` : `❌ 아쉽! 정답은 *${cur.answers[0]}*`);
    lines.push(`💡 ${cur.explain}`);
    // 오답노트 기록 (중복 방지, 상한 유지)
    if (!state.wrongNotes.some((w) => w.prompt === cur.prompt)) {
      state.wrongNotes.push({ chapter: cur.chapter, prompt: cur.prompt, answers: cur.answers, explain: cur.explain });
      if (state.wrongNotes.length > MAX_WRONG_NOTES) state.wrongNotes = state.wrongNotes.slice(-MAX_WRONG_NOTES);
    }
  }

  state.qIndex += 1;

  // ── 퀴즈 종료 판정 ──
  if (state.qIndex >= state.quiz.length) {
    const total = state.quiz.length;
    const score = state.correctInQuiz;
    const ratio = score / total;
    lines.push("");
    lines.push(`📊 결과: *${score}/${total}* (${Math.round(ratio * 100)}%)`);

    if (state.chapter >= GRAD_CHAPTER) {
      lines.push("자유 복습 한 세트 끝! 또 하려면 /학습");
      state.quiz = null;
    } else if (ratio >= PASS_RATIO) {
      if (!state.passed.includes(state.chapter)) state.passed.push(state.chapter);
      state.chapter += 1;
      state.quiz = null;
      if (state.chapter > TOTAL_CHAPTERS) {
        state.chapter = GRAD_CHAPTER;
        lines.push("");
        lines.push("🎓🎓 *21장 전 과정 수료!* 축하해요. 이제 /학습 은 전 장 무작위 복습 모드로 돌아가요.");
      } else {
        lines.push(`🎉 통과! 다음은 *${state.chapter}장 ${chapterOf(state.chapter)!.title}* — 이어서 하려면 /학습`);
      }
    } else {
      state.quiz = null;
      lines.push(`아직 통과 기준(80%)에 못 미쳤어요. *${state.chapter}장을 다시* 볼게요 — /학습 으로 재도전! (문제는 새로 뽑혀요)`);
    }
    return { state, message: lines.join("\n") };
  }

  // 다음 문제
  lines.push("");
  lines.push(questionHeader(state));
  return { state, message: lines.join("\n") };
}

function formatProgressShort(state: StudyState): string {
  const done = state.passed.length;
  const acc = state.stats.answered > 0 ? Math.round((state.stats.correct / state.stats.answered) * 100) : 0;
  const cur = state.chapter >= GRAD_CHAPTER ? "수료(자유 복습)" : `${state.chapter}장 ${chapterOf(state.chapter)?.title ?? ""}`;
  return `📌 진도: ${done}/${TOTAL_CHAPTERS}장 통과 · 현재 ${cur} · 누적 정답률 ${acc}% · 오답노트 ${state.wrongNotes.length}개`;
}

/** /진도 — 진도 요약 (학습모드 밖에서도 조회 가능) */
export function formatProgress(state: StudyState | null): string {
  if (!state) return "아직 학습을 시작하지 않았어요. /학습 으로 시작!";
  const lines = [formatProgressShort(state)];
  if (state.wrongNotes.length > 0) {
    lines.push("");
    lines.push("*오답노트 (다음 퀴즈에 복습으로 나와요):*");
    for (const w of state.wrongNotes.slice(-5)) {
      lines.push(`• [${w.chapter}장] ${w.prompt}`);
    }
    if (state.wrongNotes.length > 5) lines.push(`…외 ${state.wrongNotes.length - 5}개`);
  }
  return lines.join("\n");
}

/** 학습모드 진행 중 종료 의사인지 판단 */
export function isStudyExit(text: string): boolean {
  const t = text.trim();
  return t === "/학습종료" || t === "/학습끝" || /^(그만|학습\s*(그만|끝|종료)|스터디\s*(그만|끝)|quit|exit)$/i.test(t);
}
