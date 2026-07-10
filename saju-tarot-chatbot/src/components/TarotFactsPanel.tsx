import {
  describeCourtPersona,
  describeTarotSymbolism,
  elementalRelation,
  tarotElementOf,
  tarotSuitOf,
  type DignityRelation,
  type TarotElement,
} from "../lib/tarotSymbolism";
import { detectCardCombos } from "../data/tarotCombos";
import type { DrawnTarotCard, TarotCardDefinition } from "../types";
import TarotCardArt, { tarotSuitKeyOf } from "./viz/TarotCardArt";

/** "The Lovers (연인)" → "연인" */
function koName(card: TarotCardDefinition): string {
  return card.name.match(/\((.+)\)/)?.[1] ?? card.name;
}

interface Props {
  cards: DrawnTarotCard[];
}

const ELEMENT_GLOSS: Record<TarotElement, string> = {
  불: "행동·열정",
  물: "감정·관계",
  공기: "생각·판단",
  흙: "현실·안정",
  메이저: "큰 주제·전환",
};

const RELATION_LABEL: Record<DignityRelation, string> = {
  강화: "서로 힘을 실어줌",
  약화: "힘이 부딪힘",
  중립: "느슨한 연결",
};

const RELATION_KEY: Record<DignityRelation, string> = {
  강화: "strengthen",
  약화: "weaken",
  중립: "neutral",
};

const RELATION_MARK: Record<DignityRelation, string> = {
  강화: "→→",
  약화: "→✕→",
  중립: "→",
};

export function TarotCardVisual({
  card,
  reversed,
  className,
}: {
  card: DrawnTarotCard["card"];
  reversed: boolean;
  /** 자리별 크기 변형(예: "tarot-card-visual--today")을 붙일 때 사용 */
  className?: string;
}) {
  const suit = tarotSuitKeyOf(card.name, card.arcana);
  const koName = card.name.match(/\((.+)\)/)?.[1] ?? null;

  return (
    <div
      className={`tarot-card-visual tarot-card-visual--${suit}${reversed ? " tarot-card-visual--reversed" : ""}${
        card.imageUrl ? "" : " tarot-card-visual--drawn"
      }${className ? ` ${className}` : ""}`}
    >
      {card.imageUrl ? (
        <img src={card.imageUrl} alt={card.name} loading="lazy" />
      ) : (
        <TarotCardArt name={card.name} arcana={card.arcana} koName={koName} />
      )}
    </div>
  );
}

/**
 * 뽑힌 카드와 각 카드가 이 리딩에서 맡은 근거(자리·방향·슈트·원소·역할)를 눈에 보이게 정리한다.
 * 해석 본문이 어떤 카드에서 나왔는지 사용자가 추적할 수 있게 하는 근거 패널.
 */
export default function TarotFactsPanel({ cards }: Props) {
  if (cards.length === 0) return null;

  const upright = cards.filter((c) => !c.reversed).length;
  const reversed = cards.length - upright;
  const major = cards.filter((c) => c.card.arcana === "major").length;

  // T-2: 전통 카드 조합 신호 (참고용)
  const combos = detectCardCombos(cards);

  // 원소 분포
  const counts = new Map<TarotElement, number>();
  for (const c of cards) {
    const el = tarotElementOf(c.card);
    counts.set(el, (counts.get(el) ?? 0) + 1);
  }
  const elementOrder: TarotElement[] = ["불", "물", "공기", "흙", "메이저"];
  const distribution = elementOrder.filter((el) => counts.has(el));

  // 인접 자리 관계
  const relations = cards.slice(1).map((c, i) => {
    const prev = cards[i];
    return {
      from: prev.positionLabel ?? `${prev.position}번째`,
      to: c.positionLabel ?? `${c.position}번째`,
      relation: elementalRelation(tarotElementOf(prev.card), tarotElementOf(c.card)),
    };
  });

  // 중심/빠진 에너지 (메이저 제외한 4원소 기준)
  const suitElements: TarotElement[] = ["불", "물", "공기", "흙"];
  const present = suitElements.filter((el) => counts.has(el));
  const dominant =
    present.length > 0
      ? present.reduce((a, b) => ((counts.get(b) ?? 0) > (counts.get(a) ?? 0) ? b : a))
      : null;
  const missing = suitElements.filter((el) => !counts.has(el));

  return (
    <div className="card facts-panel tarot-facts">
      <div className="facts-block">
        <h4>뽑힌 카드와 근거</h4>
        <p className="tarot-facts__hint">
          아래 해석은 이 카드들을 근거로 합니다. 각 카드가 맡은 자리·방향·원소를 함께 표시했어요.
        </p>
        <div className="tarot-evidence-grid">
          {cards.map((c) => {
            const symbolism = describeTarotSymbolism(c.card);
            const element = tarotElementOf(c.card);
            const court = describeCourtPersona(c.card);
            return (
              <article className="tarot-evidence-card" key={`${c.position}-${c.card.id}`}>
                <TarotCardVisual card={c.card} reversed={c.reversed} />
                <span>{c.positionLabel ?? `${c.position}번째 자리`}</span>
                <b>{c.card.name}</b>
                <p>{c.reversed ? c.card.reversedMeaning : c.card.uprightMeaning}</p>
                <small>
                  {c.reversed ? "역방향" : "정방향"} · {tarotSuitOf(c.card)} · {element}
                  {element !== "메이저" ? `(${ELEMENT_GLOSS[element]})` : ""}
                </small>
                <small>{symbolism.archetype}</small>
                <em>{symbolism.symbols.slice(0, 4).join(" · ")}</em>
                {court && (
                  <small className="tarot-evidence-card__court">
                    인물상: {court.persona}
                    {c.reversed ? ` (역방향: ${court.reversedDistortion})` : ""}
                  </small>
                )}
              </article>
            );
          })}
        </div>
      </div>

      <div className="facts-block">
        <h4>배열이 말하는 근거</h4>
        <div className="tarot-facts__chips">
          <span className="tarot-facts__chip">정방향 {upright} · 역방향 {reversed}</span>
          <span className="tarot-facts__chip">메이저 {major} / 전체 {cards.length}</span>
          {distribution.map((el) => (
            <span className="tarot-facts__chip" key={el}>
              {el}
              {el !== "메이저" ? `(${ELEMENT_GLOSS[el]})` : ""} {counts.get(el)}
            </span>
          ))}
        </div>

        {relations.length > 0 && (
          <ul className="tarot-facts__relations">
            {relations.map((r, i) => (
              <li key={i} className={`tarot-facts__relation tarot-facts__relation--${RELATION_KEY[r.relation]}`}>
                <span>{r.from}</span>
                <em>{RELATION_MARK[r.relation]}</em>
                <span>{r.to}</span>
                <small>{RELATION_LABEL[r.relation]}</small>
              </li>
            ))}
          </ul>
        )}

        {(dominant || missing.length > 0) && (
          <p className="tarot-facts__energy">
            {dominant && (counts.get(dominant) ?? 0) >= 2 && (
              <>중심 에너지 <b>{dominant}({ELEMENT_GLOSS[dominant]})</b> — 이 질문의 핵심 영역. </>
            )}
            {missing.length > 0 && cards.length >= 3 && (
              <>빠진 에너지 <b>{missing.map((el) => `${el}(${ELEMENT_GLOSS[el]})`).join(", ")}</b> — 지금 놓치기 쉬운 영역.</>
            )}
          </p>
        )}

        {combos.length > 0 && (
          <ul className="tarot-facts__combos">
            {combos.map((c, i) => (
              <li key={i}>
                <b>{koName(c.a.card)} + {koName(c.b.card)}</b> — {c.entry.signal}
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
