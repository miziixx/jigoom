import type { SajuChart, SajuPillar } from "../../types";
import { colorOfChar, softOfChar } from "./elementColors";

interface PillarView {
  label: string;
  pillar: SajuPillar | null;
  isDay?: boolean;
}

/** 연/월/일/시 4기둥을 카드로 시각화 (천간·지지, 오행 색, 일간 강조) */
export default function PillarCards({ chart }: { chart: SajuChart }) {
  const pillars: PillarView[] = [
    { label: "연주", pillar: chart.year },
    { label: "월주", pillar: chart.month },
    { label: "일주", pillar: chart.day, isDay: true },
    { label: "시주", pillar: chart.hour },
  ];

  return (
    <div className="sv-pillars">
      {pillars.map(({ label, pillar, isDay }) => (
        <div className={isDay ? "sv-pillar sv-pillar--day" : "sv-pillar"} key={label}>
          <span className="sv-pillar-label">
            {label}
            {isDay && <span className="sv-pillar-me"> (나)</span>}
          </span>
          {pillar ? (
            <>
              <span className="sv-char" style={{ color: colorOfChar(pillar.gan), background: softOfChar(pillar.gan) }}>
                {pillar.gan}
              </span>
              <span className="sv-char" style={{ color: colorOfChar(pillar.zhi), background: softOfChar(pillar.zhi) }}>
                {pillar.zhi}
              </span>
            </>
          ) : (
            <span className="sv-char sv-char--unknown">시간 모름</span>
          )}
        </div>
      ))}
    </div>
  );
}
