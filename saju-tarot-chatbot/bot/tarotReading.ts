// 텔레그램 봇 타로 리딩. 웹앱(src/lib/tarot.ts, tarotSymbolism.ts)의 계산·상징 엔진을 그대로 재사용해
// 카드는 프로그램이 뽑고(무작위+역방향), 상징·원소 디그니티까지 계산해 근거로 만든다.
// Claude(teacher.ts의 askTarot)는 이 근거만 해석하고, 없는 카드를 지어내지 않는다.
import { SPREADS, drawSpread, type SpreadId } from "../src/lib/tarot.js";
import { describeTarotSymbolism, tarotSuitOf, describeElementalDignities } from "../src/lib/tarotSymbolism.js";
import type { DrawnTarotCard } from "../src/types/index.js";

/**
 * 자연어 질문에서 어떤 스프레드로 뽑을지 고른다. 사용자가 스프레드 이름을 몰라도
 * 질문의 결(관계/선택/한 달/깊게…)만으로 알아서 배열을 잡아준다.
 * 우선순위가 높은(구체적인) 것부터 검사한다.
 */
export function selectSpread(question: string): SpreadId {
  const q = question.trim();

  // 두 선택지 비교 — "A 할까 B 할까", "vs", "아니면"
  if (/(할까)\s*말까|할까\s*.*할까|둘\s*중|비교|어느\s*쪽|vs\b|\bab\b|아니면\s*.*\?|선택지/i.test(q)) return "ab";
  // 관계/연애/사람 마음
  if (/연애|사랑|썸|짝사랑|재회|이별|헤어|남친|여친|남자친구|여자친구|배우자|부부|상대\s*마음|그\s*사람|관계|짝/.test(q)) return "relation";
  // 한 달/이번 달 흐름
  if (/이번\s*달|한\s*달|이달|월간|다음\s*달|월\s*흐름|주차/.test(q)) return "month";
  // 깊고 정밀하게 — 켈틱크로스
  if (/깊게|자세히|정밀|제대로|심층|중요한|켈틱|celtic|10장|열\s*장|종합적으로/i.test(q)) return "celtic";
  // 문제·해결·막힘
  if (/문제|해결|막히|막혀|어떻게\s*해야|풀리|안\s*풀|해법|방법\s*좀|조언/.test(q)) return "soa";
  // 한 장만 빠르게 / 간단히
  if (/한\s*장|1장|원\s*카드|간단|빨리|핵심만|딱\s*하나|메시지\s*하나/i.test(q)) return "one";
  // 상황을 조금 더 넓게 5장
  if (/전체적으로|여러\s*각도|넓게|5장|다섯\s*장/.test(q)) return "five";
  // 기본: 과거-현재-흐름 3장 (가장 무난한 흐름 리딩)
  return "ppf";
}

export interface DrawnSpread {
  spreadId: SpreadId;
  cards: DrawnTarotCard[];
}

/** 질문에 맞는 스프레드를 골라 카드를 뽑는다. spreadOverride를 주면 그 배열로 강제한다. */
export function drawForQuestion(question: string, spreadOverride?: SpreadId): DrawnSpread {
  const spreadId = spreadOverride ?? selectSpread(question);
  const cards = drawSpread(spreadId, "classic");
  return { spreadId, cards };
}

/** 사용자에게 먼저 보여줄 짧은 "뽑은 카드" 헤더 (스트리밍 리딩 앞에 붙는다). */
export function describeDrawnCardsShort(spreadId: SpreadId, cards: DrawnTarotCard[]): string {
  const spread = SPREADS[spreadId];
  const lines = cards.map((c) => {
    const orient = c.reversed ? "역방향" : "정방향";
    const label = c.positionLabel ?? `${c.position}번째`;
    return `• ${label}: *${c.card.name}* (${orient})`;
  });
  return [`🃏 *${spread.label}* — ${cards.length}장 뽑았어요`, "", ...lines].join("\n");
}

/**
 * 타로 리딩 근거 블록. 뽑힌 카드의 정/역 의미 + 상징 원형/키워드 + 자리 의미 +
 * 정역·메이저·반복 슈트 진단 + 원소 디그니티(강화/약화)까지 통째로 직렬화한다.
 * 웹앱 systemPrompt.ts의 formatTarotCards/Diagnostics와 같은 밀도를 유지한다.
 */
export function buildTarotEvidenceText(spreadId: SpreadId, cards: DrawnTarotCard[], question: string): string {
  const spread = SPREADS[spreadId];

  const cardBlocks = cards
    .map((c) => {
      const orientation = c.reversed ? "역방향" : "정방향";
      const meaning = c.reversed ? c.card.reversedMeaning : c.card.uprightMeaning;
      const label = c.positionLabel ? ` [${c.positionLabel}]` : "";
      const sym = describeTarotSymbolism(c.card);
      return [
        `${c.position}번째 자리${label}: ${c.card.name} (${orientation}, ${c.card.arcana === "major" ? "메이저" : "마이너"}) — ${meaning}`,
        `  상징 원형: ${sym.archetype}`,
        `  상징 키워드: ${sym.symbols.join(" · ")}`,
        `  그림 단서: ${sym.imagery}`,
        `  숫자/단계 의미: ${sym.numberTone}`,
        `  슈트 의미: ${sym.suitTone}`,
      ].join("\n");
    })
    .join("\n");

  // 진단(정역/메이저/반복 슈트/흐름 축)
  const upright = cards.filter((c) => !c.reversed).length;
  const reversed = cards.length - upright;
  const major = cards.filter((c) => c.card.arcana === "major").length;
  const suitCounts = cards.reduce<Record<string, number>>((acc, c) => {
    const suit = c.card.arcana === "major" ? "메이저" : tarotSuitOf(c.card);
    acc[suit] = (acc[suit] ?? 0) + 1;
    return acc;
  }, {});
  const repeatedSuits = Object.entries(suitCounts)
    .filter(([, n]) => n >= 2)
    .map(([s, n]) => `${s} ${n}장`);
  const first = cards[0];
  const last = cards[cards.length - 1];
  const diagnostics = [
    `정/역 비율: 정방향 ${upright}장 / 역방향 ${reversed}장`,
    `메이저 비율: ${major}장 / 전체 ${cards.length}장`,
    `반복 슈트: ${repeatedSuits.join(", ") || "뚜렷한 반복 없음"}`,
    first && last
      ? `흐름 축: 시작/핵심 ${first.card.name}(${first.reversed ? "역" : "정"}) → 마지막/조언 ${last.card.name}(${last.reversed ? "역" : "정"})`
      : "",
  ]
    .filter(Boolean)
    .join("\n");

  const blocks = [
    `[타로 계산 데이터 — 프로그램이 78장 덱에서 무작위로 뽑고 각 카드 50% 확률로 역방향을 정한 값. 이 카드들만 근거로 하고 없는 카드를 지어내지 마세요]`,
    `스프레드: ${spread.label} (${cards.length}장)`,
    `자리 의미: ${spread.positions.map((p, i) => `${i + 1}.${p}`).join(" / ")}`,
    spread.note ? `이 배열 해석 지침: ${spread.note}` : "",
    "",
    `[뽑힌 카드]`,
    cardBlocks,
    "",
    `[타로 조합 진단]`,
    diagnostics,
    "",
    `[원소 조합(엘리멘탈 디그니티) — 계산됨]`,
    describeElementalDignities(cards),
    "",
    `[질문]`,
    question || "(질문을 명확히 안 줌 — 자리 의미와 카드 흐름 중심으로 지금 봐야 할 것을 짚어주세요)",
  ];
  return blocks.filter((b) => b !== "").join("\n");
}
