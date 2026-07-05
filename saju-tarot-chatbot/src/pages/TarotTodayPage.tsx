import { useMemo, useState } from "react";
import { TAROT_DECK } from "../data/tarotDeck";
import { describeTarotSymbolism, tarotElementOf, tarotSuitOf } from "../lib/tarotSymbolism";
import type { TarotCardDefinition } from "../types";

function dateKey(date = new Date()) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function hashText(text: string) {
  let hash = 2166136261;
  for (let i = 0; i < text.length; i += 1) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function dailyDraw(seedText: string) {
  const seed = hashText(seedText);
  const card = TAROT_DECK[seed % TAROT_DECK.length];
  const reversed = ((seed >>> 7) % 100) < 38;
  return { card, reversed };
}

function randomDraw() {
  const seed = `${Date.now()}-${Math.random()}`;
  return dailyDraw(seed);
}

function visualLabel(card: TarotCardDefinition) {
  if (card.arcana === "major") return "major";
  if (card.name.includes("Wands")) return "wands";
  if (card.name.includes("Cups")) return "cups";
  if (card.name.includes("Swords")) return "swords";
  return "pentacles";
}

function visualTitle(card: TarotCardDefinition) {
  if (card.arcana === "major") return "Major";
  if (card.name.includes("Wands")) return "Wands";
  if (card.name.includes("Cups")) return "Cups";
  if (card.name.includes("Swords")) return "Swords";
  return "Pentacles";
}

function visualSymbol(card: TarotCardDefinition) {
  if (card.arcana === "major") return "✦";
  if (card.name.includes("Wands")) return "♨";
  if (card.name.includes("Cups")) return "☽";
  if (card.name.includes("Swords")) return "◇";
  return "◉";
}

function koreanName(card: TarotCardDefinition) {
  return card.name.match(/\((.+)\)/)?.[1] ?? card.name;
}

function englishName(card: TarotCardDefinition) {
  return card.name.split(" (")[0];
}

function cardRank(card: TarotCardDefinition) {
  if (card.arcana === "major") return "major";
  return englishName(card).split(" of ")[0];
}

const SUIT_DAILY_KEYWORDS: Record<string, string[]> = {
  완드: ["움직임", "추진력", "시작"],
  컵: ["감정 정리", "공감", "관계의 온도"],
  소드: ["생각 정리", "말 조심", "판단"],
  펜타클: ["현실 점검", "돈과 시간", "생활 리듬"],
  메이저: ["큰 흐름", "전환점", "오늘의 주제"],
};

const RANK_DAILY_KEYWORD: Record<string, string> = {
  Ace: "작은 시작",
  Two: "균형 맞추기",
  Three: "함께 나누기",
  Four: "멈춤과 안정",
  Five: "불편함 조정",
  Six: "회복",
  Seven: "선택지 정리",
  Eight: "속도 조절",
  Nine: "만족과 피로",
  Ten: "마무리",
  Page: "새로운 신호",
  Knight: "움직임",
  Queen: "감정 관리",
  King: "기준 세우기",
};

function todayKeywords(card: TarotCardDefinition, reversed: boolean) {
  if (card.arcana === "major") {
    const symbolism = describeTarotSymbolism(card);
    return symbolism.archetype
      .split(/,|와|과/)
      .map((item) => item.trim())
      .filter(Boolean)
      .slice(0, 3)
      .join(" · ");
  }

  const suit = tarotSuitOf(card);
  const rank = cardRank(card);
  const base = SUIT_DAILY_KEYWORDS[suit] ?? ["오늘의 흐름"];
  const rankKeyword = RANK_DAILY_KEYWORD[rank] ?? "상황 확인";
  const direction = reversed ? "막힌 부분 보기" : "자연스럽게 쓰기";
  return [base[0], rankKeyword, direction].join(" · ");
}

function todayMood(card: TarotCardDefinition, reversed: boolean) {
  const suit = tarotSuitOf(card);
  const rank = cardRank(card);

  if (card.arcana === "major") {
    return reversed
      ? "오늘은 큰 흐름이 바로 풀리기보다, 먼저 걸리는 이유를 확인해야 하는 날입니다."
      : "오늘은 사소한 일보다 하루 전체의 방향을 정리하기 좋은 날입니다.";
  }

  if (suit === "컵" && rank === "Queen") {
    return reversed
      ? "마음이 예민해지기 쉬워요. 남의 감정까지 떠안기보다 내 감정과 상대 감정을 나눠 보는 날입니다."
      : "마음이 섬세해지고 사람들의 분위기를 잘 읽는 날입니다. 다만 배려하느라 내 속마음을 미루지 않는 게 좋아요.";
  }
  if (suit === "완드") {
    return reversed
      ? "움직이고 싶은데 속도가 잘 안 붙을 수 있어요. 오늘은 무리한 추진보다 방향 점검이 먼저입니다."
      : "몸을 움직이거나 미뤄둔 일을 시작하기 좋은 분위기입니다. 작게라도 행동하면 흐름이 열립니다.";
  }
  if (suit === "컵") {
    return reversed
      ? "감정이 안쪽으로 고이기 쉬운 날입니다. 서운함을 바로 결론내리기보다 차분히 정리해보세요."
      : "관계와 감정의 온도가 중요한 날입니다. 따뜻한 말 한마디가 생각보다 큰 영향을 줍니다.";
  }
  if (suit === "소드") {
    return reversed
      ? "생각이 꼬이거나 말이 날카로워지기 쉬워요. 답을 서두르기보다 사실과 해석을 나눠보세요."
      : "머리가 맑아지고 판단이 선명해지는 날입니다. 정리할 말과 결정할 일을 분리하면 좋습니다.";
  }
  if (suit === "펜타클") {
    return reversed
      ? "현실적인 부담이 먼저 보일 수 있어요. 돈, 시간, 체력을 한 번에 쓰지 말고 우선순위를 정하세요."
      : "생활 리듬과 현실 감각이 살아나는 날입니다. 돈, 일정, 몸 상태를 정리하기 좋습니다.";
  }
  return reversed ? "오늘은 막힌 부분을 먼저 정리하는 편이 좋습니다." : "오늘은 작은 행동으로 흐름을 확인하기 좋은 날입니다.";
}

function todayAdvice(card: TarotCardDefinition, reversed: boolean) {
  const suit = tarotSuitOf(card);
  if (suit === "컵") return reversed ? "오늘은 감정적으로 바로 답하지 말고, 느낀 점을 한 줄로 적은 뒤 말하세요." : "고마운 사람에게 짧게 안부를 전하고, 내 감정도 한 문장으로 확인하세요.";
  if (suit === "완드") return reversed ? "새 일을 벌이기보다 이미 시작한 일 하나를 15분만 정리하세요." : "미뤄둔 일을 아주 작게 시작하세요. 첫 행동이 중요합니다.";
  if (suit === "소드") return reversed ? "결정 전 사실 3개와 추측 3개를 나눠 적어보세요." : "복잡한 대화나 문서를 짧게 정리하기 좋은 날입니다.";
  if (suit === "펜타클") return reversed ? "지출, 일정, 체력 중 하나만 골라 오늘 쓸 수 있는 한도를 정하세요." : "돈이나 일정처럼 미뤄둔 현실 문제 하나를 처리하세요.";
  return reversed ? "무리해서 밀기보다 막힌 이유를 먼저 정리하세요." : "작게라도 움직여 오늘의 흐름을 확인하세요.";
}

function TodayCardVisual({ card, reversed }: { card: TarotCardDefinition; reversed: boolean }) {
  const title = visualTitle(card);
  return (
    <div className={`tarot-card-visual tarot-card-visual--today tarot-card-visual--${visualLabel(card)}${reversed ? " tarot-card-visual--reversed" : ""}`}>
      {card.imageUrl ? (
        <img src={card.imageUrl} alt={card.name} loading="lazy" />
      ) : (
        <>
          <span className="tarot-card-visual__arcana">{title}</span>
          <b className="tarot-card-visual__symbol">{visualSymbol(card)}</b>
          <span className="tarot-card-visual__name">{card.name.replace(/\s*\(.+?\)/, "")}</span>
        </>
      )}
    </div>
  );
}

export default function TarotTodayPage() {
  const today = dateKey();
  const stable = useMemo(() => dailyDraw(`insight-oracle-tarot-card:${today}`), [today]);
  const [extra, setExtra] = useState<{ card: TarotCardDefinition; reversed: boolean } | null>(null);
  const draw = extra ?? stable;
  const meaning = draw.reversed ? draw.card.reversedMeaning : draw.card.uprightMeaning;
  const element = tarotElementOf(draw.card);
  const suit = tarotSuitOf(draw.card);

  return (
    <section className="page">
      <h2 className="page-title">오늘의 카드</h2>
      <p className="page-desc">
        오늘 하루의 분위기를 카드 1장으로 가볍게 확인해요. 기본 카드는 날짜 기준으로 하루 동안 고정됩니다.
      </p>

      <section className="card today-tarot-card">
        <div className="today-tarot-card__visual">
          <TodayCardVisual card={draw.card} reversed={draw.reversed} />
        </div>
        <div className="today-tarot-card__body">
          <span className="feature-badge">{extra ? "지금 다시 뽑은 카드" : `${today} 오늘의 카드`}</span>
          <h3>{koreanName(draw.card)}</h3>
          <p className="today-tarot-card__direction">
            {draw.reversed ? "역방향" : "정방향"} · {suit} · {element}
          </p>
          <p className="today-tarot-card__meaning">{meaning}</p>
          <div className="today-tarot-card__grid">
            <div>
              <b>오늘의 키워드</b>
              <span>{todayKeywords(draw.card, draw.reversed)}</span>
            </div>
            <div>
              <b>분위기</b>
              <span>{todayMood(draw.card, draw.reversed)}</span>
            </div>
            <div>
              <b>현실 조언</b>
              <span>{todayAdvice(draw.card, draw.reversed)}</span>
            </div>
          </div>
          <button type="button" className="btn btn--secondary" onClick={() => setExtra(randomDraw())}>
            지금 다시 뽑기
          </button>
        </div>
      </section>
    </section>
  );
}
