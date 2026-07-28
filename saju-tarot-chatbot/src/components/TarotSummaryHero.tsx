import { tarotElementOf, type TarotElement } from "../lib/tarotSymbolism";
import type { DrawnTarotCard } from "../types";
import { VizIcon } from "./viz/icons";

const ELEMENT_GLOSS: Record<TarotElement, string> = {
  불: "행동·열정",
  물: "감정·관계",
  공기: "생각·판단",
  흙: "현실·안정",
  메이저: "큰 주제·전환",
};

const ELEMENT_ICON: Record<TarotElement, string> = {
  불: "wand",
  물: "cup",
  공기: "sword",
  흙: "pentacle",
  메이저: "star",
};

/**
 * 타로 결과 상단 요약 히어로. 사주 대시보드가 없는 타로 리딩에서, 뽑은 카드의 방향 비율과
 * 중심/빠진 에너지를 한눈에 보여준다. 계산은 전부 기존 tarotSymbolism 기반(새 계산 없음).
 */
export default function TarotSummaryHero({ cards }: { cards: DrawnTarotCard[] }) {
  if (!cards || cards.length === 0) return null;

  const upright = cards.filter((c) => !c.reversed).length;
  const reversed = cards.length - upright;
  const major = cards.filter((c) => c.card.arcana === "major").length;
  const uprightPct = Math.round((upright / cards.length) * 100);

  const counts = new Map<TarotElement, number>();
  for (const c of cards) {
    const el = tarotElementOf(c.card);
    counts.set(el, (counts.get(el) ?? 0) + 1);
  }
  const suitElements: TarotElement[] = ["불", "물", "공기", "흙"];
  const present = suitElements.filter((el) => counts.has(el));
  const dominant =
    present.length > 0 ? present.reduce((a, b) => ((counts.get(b) ?? 0) > (counts.get(a) ?? 0) ? b : a)) : null;
  const missing = suitElements.filter((el) => !counts.has(el));

  // 한 줄 메시지: 방향 비율 + 메이저 비중으로 흐름 성격을 쉽게
  let headline: string;
  if (uprightPct >= 70) headline = "전반적으로 흐름이 순방향이에요. 지금 방향대로 밀고 가도 좋은 신호가 많습니다.";
  else if (uprightPct <= 35) headline = "역방향이 많아요. 밖으로 밀기보다 안에서 정리하고 속도를 늦출 때라는 신호입니다.";
  else headline = "순방향과 역방향이 섞여 있어요. 되는 부분은 밀고, 걸리는 부분은 다듬는 조율이 필요한 흐름입니다.";
  if (major >= Math.ceil(cards.length / 2)) headline += " 메이저 카드 비중이 높아 큰 주제·전환이 걸린 질문입니다.";

  return (
    <section className="card tarot-hero">
      <div className="section-heading-row">
        <h3 className="card-title">타로 한눈 요약</h3>
        <span className="feature-badge">카드 흐름</span>
      </div>

      <p className="tarot-hero__headline">{headline}</p>

      {/* 카드 1장 = 핍 1개. 뽑은 순서 그대로, 채움=정방향 / 윤곽=역방향 */}
      <div className="tarot-hero__ratio">
        <div className="tarot-hero__pips" role="img" aria-label={`정방향 ${upright}장, 역방향 ${reversed}장 (뽑은 순서대로)`}>
          {cards.map((c, i) => (
            <span
              key={`${c.position}-${c.card.id}`}
              className={`tarot-hero__pip${c.reversed ? " tarot-hero__pip--reversed" : ""}`}
              title={`${c.positionLabel ?? `${c.position}번째`} · ${c.card.name} · ${c.reversed ? "역방향" : "정방향"}`}
            >
              {i + 1}
            </span>
          ))}
        </div>
        <div className="tarot-hero__ratio-labels">
          <span>정방향 {upright}</span>
          <span>역방향 {reversed}</span>
        </div>
      </div>

      <div className="tarot-hero__chips">
        <span className="tarot-hero__chip">
          <VizIcon name="moonStar" size={13} /> 카드 {cards.length}장
        </span>
        <span className="tarot-hero__chip">
          <VizIcon name="star" size={13} /> 메이저 {major}
        </span>
        {dominant && (counts.get(dominant) ?? 0) >= 2 && (
          <span className="tarot-hero__chip tarot-hero__chip--dominant">
            <VizIcon name={ELEMENT_ICON[dominant]} size={13} /> 중심 {dominant}({ELEMENT_GLOSS[dominant]})
          </span>
        )}
        {missing.length > 0 && cards.length >= 3 && (
          <span className="tarot-hero__chip tarot-hero__chip--missing">
            빠진 {missing.map((el) => `${el}(${ELEMENT_GLOSS[el]})`).join(" · ")}
          </span>
        )}
      </div>
      <p className="tarot-hero__note">아래 카드별 근거와 해석이 이어집니다.</p>
    </section>
  );
}
