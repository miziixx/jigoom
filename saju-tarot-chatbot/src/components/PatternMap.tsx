import type { FiveElementBalance, SajuChart } from "../types";

const ELEMENT_LABEL: Record<keyof FiveElementBalance, string> = {
  wood: "성장·시작",
  fire: "표현·활력",
  earth: "안정·책임",
  metal: "판단·정리",
  water: "생각·휴식",
};

const ELEMENT_PATTERN: Record<keyof FiveElementBalance, { title: string; tendency: string; adjust: string }> = {
  wood: {
    title: "시작은 빠르지만 방향이 흩어지는 패턴",
    tendency: "새로운 배움이나 계획에 마음이 먼저 움직이기 쉽습니다.",
    adjust: "시작 전에 이번 주에 끝낼 범위를 하나만 정하세요.",
  },
  fire: {
    title: "표현과 속도가 앞서는 패턴",
    tendency: "반응이 빠르고 추진력이 있지만, 피곤할 때 말이나 결정이 빨라질 수 있습니다.",
    adjust: "중요한 말과 결정은 한 번 적어본 뒤 전달하세요.",
  },
  earth: {
    title: "책임을 혼자 들고 가는 패턴",
    tendency: "현실을 챙기려는 힘이 강해 맡은 일을 쉽게 내려놓지 못할 수 있습니다.",
    adjust: "내 몫과 부탁할 일을 구분해서 일정표에 나누세요.",
  },
  metal: {
    title: "기준이 높아 스스로를 압박하는 패턴",
    tendency: "판단과 정리는 강점이지만, 마음이 좁아질 때 흑백으로 보기 쉽습니다.",
    adjust: "완벽한 답보다 지금 가능한 기준 3가지를 먼저 정하세요.",
  },
  water: {
    title: "생각이 깊어지며 실행이 늦어지는 패턴",
    tendency: "감정과 정보를 오래 살피는 힘이 있지만, 걱정이 길어지면 움직임이 줄 수 있습니다.",
    adjust: "생각을 끝내는 시간을 정하고 작은 행동 하나로 마무리하세요.",
  },
};

function topElement(chart: SajuChart): keyof FiveElementBalance | null {
  const entries = Object.entries(chart.fiveElements) as [keyof FiveElementBalance, number][];
  const sorted = entries.sort((a, b) => b[1] - a[1]);
  return sorted[0]?.[1] > 0 ? sorted[0][0] : null;
}

function weakElement(chart: SajuChart): keyof FiveElementBalance | null {
  const entries = Object.entries(chart.fiveElements) as [keyof FiveElementBalance, number][];
  const sorted = entries.sort((a, b) => a[1] - b[1]);
  return sorted[0]?.[0] ?? null;
}

export default function PatternMap({ sajuChart }: { sajuChart?: SajuChart }) {
  if (!sajuChart) return null;
  const primary = topElement(sajuChart);
  const weak = weakElement(sajuChart);
  const cards: Array<{ label: string; title: string; tendency: string; adjust: string }> = [];

  if (primary) {
    cards.push({ label: `두드러진 결 · ${ELEMENT_LABEL[primary]}`, ...ELEMENT_PATTERN[primary] });
  }
  if (sajuChart.strength) {
    cards.push({
      label: "힘의 쓰임",
      title:
        sajuChart.strength.label === "신강"
          ? "혼자 밀고 가다 지치는 패턴"
          : sajuChart.strength.label === "신약"
            ? "환경과 사람의 영향을 크게 받는 패턴"
            : "상황에 따라 밀고 당기는 패턴",
      tendency:
        sajuChart.strength.label === "신강"
          ? "방향이 잡히면 끌고 가는 힘이 좋지만, 도움을 늦게 요청할 수 있습니다."
          : sajuChart.strength.label === "신약"
            ? "주변 조건이 맞을 때 실력이 잘 살아나고, 무리한 독주는 피로가 큽니다."
            : "균형감이 강점이라 상황을 보며 조정하는 방식이 잘 맞습니다.",
      adjust:
        sajuChart.strength.label === "신강"
          ? "처음부터 역할을 나누고, 도움 요청 기준을 정해두세요."
          : sajuChart.strength.label === "신약"
            ? "좋은 환경, 협업자, 루틴을 먼저 만들고 움직이세요."
            : "한쪽으로 치우친 결정을 피하고 장단점을 표로 비교하세요.",
    });
  }
  if (weak) {
    cards.push({
      label: `채우면 좋은 결 · ${ELEMENT_LABEL[weak]}`,
      title: "비어 있는 힘을 생활 습관으로 보완하는 패턴",
      tendency: `${ELEMENT_LABEL[weak]} 쪽은 의식적으로 챙길수록 전체 균형이 좋아집니다.`,
      adjust: ELEMENT_PATTERN[weak].adjust,
    });
  }
  if (cards.length === 0) return null;

  return (
    <section className="card pattern-map">
      <div className="section-heading-row">
        <h3 className="card-title">내 반복 패턴 지도</h3>
        <span className="feature-badge">반복 패턴</span>
      </div>
      <p className="pattern-map__intro">계산된 사주 구조에서 반복되기 쉬운 생활 패턴을 먼저 보여드립니다.</p>
      <div className="pattern-map__grid">
        {cards.slice(0, 3).map((card) => (
          <article className="pattern-card" key={card.label}>
            <span className="pattern-card__label">{card.label}</span>
            <h4>{card.title}</h4>
            <p>{card.tendency}</p>
            <b>조정법</b>
            <p>{card.adjust}</p>
          </article>
        ))}
      </div>
    </section>
  );
}
