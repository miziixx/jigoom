// 문맥 이해 라우터. 결정론적 키워드 분류(intentDetector)는 현재 한 줄만 보고 판단하기 때문에,
// "그럼 연애는?", "아까 그 카드 다시 봐줘", "한 장 더" 같은 맥락 의존 표현을 놓친다.
// 이 라우터는 최근 대화 + 등록 상태(사주/생일/타로)를 함께 Claude(빠른 모델)에게 주고,
// 사용자가 지금 뭘 원하는지 자연어 그대로 이해해 의도를 정한다. 키워드 결과는 힌트로만 준다.
//
// 안전 원칙: 이 라우터는 "리딩/대화" 계열 의도만 반환한다. 기억 저장·삭제·조회·보안·초기화 같은
// 보안 민감 동작은 절대 LLM 판단에 맡기지 않는다 — 그건 messageHandler가 키워드로 먼저 처리하고,
// 여기 오기 전에 걸러진다(RoutableIntent 자체가 그 값들을 포함하지 않는다).
import Anthropic from "@anthropic-ai/sdk";
import type { ChatTurn } from "./storeTypes.js";
import type { DetectedIntent } from "./intentDetector.js";
import { logError } from "./logSafe.js";

export type RoutableIntent =
  | "sajuReading"
  | "astrologyReading"
  | "tarotReading"
  | "combinedReading"
  | "todayFlow"
  | "selfAnalysis"
  | "planning"
  | "writing"
  | "decision"
  | "generalChat";

const ROUTABLE: readonly RoutableIntent[] = [
  "sajuReading",
  "astrologyReading",
  "tarotReading",
  "combinedReading",
  "todayFlow",
  "selfAnalysis",
  "planning",
  "writing",
  "decision",
  "generalChat",
];

export interface RouteInput {
  text: string;
  history: ChatTurn[];
  /** 키워드 분류기의 1차 추측 (LLM에 힌트로만 전달) */
  keywordHint: DetectedIntent;
  hasSaju: boolean;
  hasBirth: boolean;
  hasTarot: boolean;
}

export interface RouteResult {
  intent: RoutableIntent;
  /** 타로: 새 카드를 뽑아야 하는가 */
  newDraw: boolean;
  /** 타로: 이미 뽑은 카드에 이어지는 후속 질문인가 */
  tarotFollowUp: boolean;
  /** LLM 라우터를 실제로 썼는지 (테스트/로그용) */
  usedLlm: boolean;
}

const DRAW_WORDS = /뽑아|뽑아줘|뽑아주|뽑아봐|봐줘|보고\s*싶|점\s*(봐|보)|다시\s*뽑|한\s*장\s*더|새로\s*뽑|다른\s*카드|새\s*카드|다시\s*봐/;

/** 키워드 힌트를 RoutableIntent로 좁힌다(보안·기억 계열은 여기 오지 않지만 방어적으로 generalChat 처리). */
function narrowHint(hint: DetectedIntent): RoutableIntent {
  return (ROUTABLE as readonly string[]).includes(hint) ? (hint as RoutableIntent) : "generalChat";
}

/** LLM 없이 타로 새로뽑기/후속 여부만 규칙으로 정한다(라우터 끄거나 실패 시 폴백). */
export function heuristicTarotFlags(text: string, hasTarot: boolean): { newDraw: boolean; tarotFollowUp: boolean } {
  const wantsDraw = DRAW_WORDS.test(text);
  if (!hasTarot) return { newDraw: true, tarotFollowUp: false }; // 뽑은 게 없으면 뽑아야 뭐라도 본다
  if (wantsDraw) return { newDraw: true, tarotFollowUp: false };
  return { newDraw: false, tarotFollowUp: true }; // 카드가 있고 새로 뽑으란 말 없으면 후속 질문
}

/** 라우터를 켤지 여부. 기본 ON. BOT_SMART_ROUTER=0/false 로 끄면 키워드 결과만 쓴다. */
function routerEnabled(): boolean {
  const v = (process.env.BOT_SMART_ROUTER ?? "1").toLowerCase();
  return v !== "0" && v !== "false" && v !== "off";
}

const ROUTER_MODEL = process.env.BOT_ROUTER_MODEL ?? "claude-haiku-4-5-20251001";

let client: Anthropic | null = null;
function getClient(): Anthropic {
  if (!client) client = new Anthropic();
  return client;
}

const SYSTEM = `너는 사주·타로·점성술·개인비서 챗봇의 "의도 라우터"다. 사용자의 마지막 메시지가 지금 무엇을 원하는지, 최근 대화 맥락까지 보고 정확히 하나로 분류한다. 설명 없이 JSON만 출력한다.

가능한 intent (반드시 이 중 하나):
- sajuReading: 사주/명리(신강신약·격국·오행·대운·일주 등) 또는 "내 사주 성격/재물/연애" 같은 개인 사주 해석
- astrologyReading: 서양·베딕 점성술(별자리·행성·하우스·트랜짓·새턴리턴 등)
- tarotReading: 타로 카드로 봐달라거나, 이미 뽑은 카드에 대한 질문
- combinedReading: 사주와 점성술을 함께 보자는 명시적 요청
- todayFlow: 오늘 하루 흐름/일진/"오늘 왜 이래" 류
- selfAnalysis: "나 왜 자꾸 ~하지?", "내가 예민한 건가?" 같은 자기성찰
- planning: 기획/개발/구조/MVP/작업지시서
- writing: 글 다듬기/이메일/카피/"AI티 빼줘"
- decision: "뭐부터 할까", "이거 밀어붙여도 돼?" 같은 선택/우선순위 판단
- generalChat: 위 어디에도 안 맞는 잡담·인사·일반 질문

핵심 규칙:
- 맥락을 봐라. 직전 대화가 타로였고 사용자가 "그럼 연애는?", "한 장 더", "그 카드 무슨 뜻?"이라고 하면 tarotReading이다. 직전이 사주였고 "그럼 돈은?"이면 sajuReading이다.
- 짧은 후속 질문("그럼?", "왜?", "더 자세히")은 직전 주제를 이어간다.
- 애매하면 keywordHint를 존중해라. 확신이 없으면 keywordHint를 그대로 써라.
- tarot일 때만: newDraw(새 카드를 뽑아야 하는가), tarotFollowUp(이미 뽑은 카드 얘기인가)을 정한다. 아직 뽑은 카드가 없으면(hasTarot=false) tarot이면 newDraw=true. "다시/한 장 더/새로 뽑아"는 newDraw=true. 이미 뽑은 카드를 묻기만 하면 tarotFollowUp=true, newDraw=false. tarot이 아니면 둘 다 false.

출력 형식(JSON, 이것만):
{"intent":"...","newDraw":false,"tarotFollowUp":false}`;

function buildUserMessage(input: RouteInput): string {
  const recent = input.history.slice(-6).map((t) => `${t.role === "user" ? "사용자" : "봇"}: ${t.content.slice(0, 300)}`);
  const state = `등록상태: 사주=${input.hasSaju ? "있음" : "없음"}, 생일(점성술가능)=${input.hasBirth ? "있음" : "없음"}, 최근뽑은타로=${input.hasTarot ? "있음" : "없음"}`;
  return [
    "[최근 대화]",
    recent.length ? recent.join("\n") : "(없음)",
    "",
    state,
    `키워드 힌트: ${input.keywordHint}`,
    "",
    "[사용자의 마지막 메시지]",
    input.text,
  ].join("\n");
}

function parseResult(raw: string, input: RouteInput): RouteResult | null {
  const match = raw.match(/\{[\s\S]*\}/);
  if (!match) return null;
  let obj: { intent?: unknown; newDraw?: unknown; tarotFollowUp?: unknown };
  try {
    obj = JSON.parse(match[0]);
  } catch {
    return null;
  }
  if (typeof obj.intent !== "string" || !(ROUTABLE as readonly string[]).includes(obj.intent)) return null;
  const intent = obj.intent as RoutableIntent;

  if (intent === "tarotReading") {
    // LLM이 준 값을 존중하되, 상태와 모순되면(카드 없는데 후속) 규칙으로 교정한다.
    let newDraw = obj.newDraw === true;
    let tarotFollowUp = obj.tarotFollowUp === true;
    if (!input.hasTarot) {
      newDraw = true;
      tarotFollowUp = false;
    } else if (!newDraw && !tarotFollowUp) {
      // 둘 다 비었으면 규칙으로 보완
      ({ newDraw, tarotFollowUp } = heuristicTarotFlags(input.text, input.hasTarot));
    } else if (newDraw) {
      tarotFollowUp = false;
    }
    return { intent, newDraw, tarotFollowUp, usedLlm: true };
  }
  return { intent, newDraw: false, tarotFollowUp: false, usedLlm: true };
}

/** 키워드 결과만으로 구성한 폴백(라우터 OFF 또는 실패). */
export function fallbackRoute(input: RouteInput): RouteResult {
  const intent = narrowHint(input.keywordHint);
  if (intent === "tarotReading") {
    const flags = heuristicTarotFlags(input.text, input.hasTarot);
    return { ...flags, intent, usedLlm: false };
  }
  return { intent, newDraw: false, tarotFollowUp: false, usedLlm: false };
}

/**
 * 맥락 인지 라우팅. LLM(빠른 모델)으로 최근 대화까지 보고 의도를 정한다.
 * 실패하거나 라우터가 꺼져 있으면 키워드 기반 폴백을 쓴다(견고성 우선).
 */
export async function routeMessage(input: RouteInput): Promise<RouteResult> {
  if (!routerEnabled()) return fallbackRoute(input);
  try {
    const res = await getClient().messages.create({
      model: ROUTER_MODEL,
      max_tokens: 150,
      temperature: 0,
      system: SYSTEM,
      messages: [{ role: "user", content: buildUserMessage(input) }],
    });
    const raw = res.content
      .filter((b): b is Anthropic.Messages.TextBlock => b.type === "text")
      .map((b) => b.text)
      .join("");
    const parsed = parseResult(raw, input);
    return parsed ?? fallbackRoute(input);
  } catch (err) {
    logError("smartRouter.routeMessage", err);
    return fallbackRoute(input);
  }
}
