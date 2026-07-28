import type { SajuChart, SinsalCategory, SinsalHit } from "../../types";

const CATEGORY_LABEL: Record<SinsalCategory, string> = {
  길신: "길신",
  흉살: "주의",
  특수: "특수",
};

function groupSinsal(sinsal: SinsalHit[]): SinsalHit[] {
  const byKey = new Map<string, SinsalHit>();
  for (const item of sinsal) {
    const existing = byKey.get(item.name);
    if (!existing) {
      byKey.set(item.name, { ...item });
      continue;
    }
    byKey.set(item.name, { ...existing, position: `${existing.position} · ${item.position}` });
  }
  return [...byKey.values()].sort((a, b) => categoryRank(a.category) - categoryRank(b.category));
}

function categoryRank(category: SinsalCategory): number {
  if (category === "길신") return 0;
  if (category === "흉살") return 1;
  return 2;
}

export default function SinsalBadges({ chart }: { chart: SajuChart }) {
  const sinsal = groupSinsal(chart.sinsal ?? []);

  if (sinsal.length === 0) {
    return <p className="sv-sinsal-empty">현재 원국에서 표시할 주요 신살이 적습니다.</p>;
  }

  return (
    <div className="sv-sinsal" aria-label="신살 목록">
      {sinsal.map((item) => (
        <span
          className={`sv-sinsal-badge sv-sinsal-badge--${item.category}`}
          key={`${item.name}-${item.position}`}
          title={`${item.position} · ${item.gloss}`}
        >
          <span className="sv-sinsal-badge__cat">{CATEGORY_LABEL[item.category]}</span>
          <b>{item.name}</b>
          <small>{item.position}</small>
        </span>
      ))}
    </div>
  );
}
