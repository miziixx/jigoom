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
  const symbolism = describeTarotSymbolism(draw.card);
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
              <span>{symbolism.symbols.slice(0, 3).join(" · ")}</span>
            </div>
            <div>
              <b>분위기</b>
              <span>{symbolism.archetype}</span>
            </div>
            <div>
              <b>현실 조언</b>
              <span>{draw.reversed ? "무리해서 밀기보다 막힌 이유를 먼저 정리하세요." : "작게라도 움직여 오늘의 흐름을 확인하세요."}</span>
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
