import type { ReadingSession } from "../types";
import Markdown from "./Markdown";
import FiveElementsChart from "./saju-visual/FiveElementsChart";
import PillarCards from "./saju-visual/PillarCards";
import LuckTimeline from "./saju-visual/LuckTimeline";
import SinsalBadges from "./saju-visual/SinsalBadges";

interface Section {
  title: string;
  body: string;
}

function parseSections(markdown: string): Section[] {
  const parts = markdown.split(/^#\s+(.+)$/m).slice(1);
  const sections: Section[] = [];
  for (let i = 0; i < parts.length; i += 2) {
    sections.push({ title: parts[i].trim(), body: (parts[i + 1] ?? "").trim() });
  }
  return sections.length > 0 ? sections : [{ title: "리딩 결과", body: markdown }];
}

export default function ReadingResult({ session }: { session: ReadingSession }) {
  const reply = session.messages.find((m) => m.role === "assistant")?.content ?? "";
  const sections = parseSections(reply);
  const [summary, ...rest] = sections;
  const chart = session.sajuChart;
  const luck = session.luckCycles;

  return (
    <div className="reading-result">
      {(chart || (session.tarotCards && session.tarotCards.length > 0)) && (
        <div className="card facts-panel">
          {chart && (
            <div className="facts-block">
              <h4>사주 원국</h4>
              <PillarCards chart={chart} />
              <FiveElementsChart chart={chart} />
              <SinsalBadges chart={chart} />
              {chart.strength && (
                <p className="facts-line">
                  신강/신약(간이) — <b>{chart.strength.label}</b>
                  {chart.yongshin && <> · 균형을 돕는 기운(용신 후보): {chart.yongshin.supportive.join("·")}</>}
                </p>
              )}
              {chart.interactions && chart.interactions.length > 0 && (
                <p className="facts-line">글자끼리의 작용(합충형파해) — {chart.interactions.join(", ")}</p>
              )}

              {/* 세부 계산값은 접기 안에 보조로 */}
              <details className="facts-more">
                <summary>계산 세부 보기</summary>
                {chart.gongmang && <p>공망 — {chart.gongmang}</p>}
                {chart.hiddenStems && <p>지장간 — {chart.hiddenStems.join(", ")}</p>}
                {chart.twelveStages && <p>12운성 — {chart.twelveStages.join(", ")}</p>}
                {chart.seasonNote && <p>조후(계절) — {chart.seasonNote}</p>}
                {chart.timeCorrection && chart.timeCorrection.applied.length > 0 && (
                  <p>
                    시각 보정 — {chart.timeCorrection.applied.join(", ")} (보정 후{" "}
                    {chart.timeCorrection.correctedDateTime})
                  </p>
                )}
              </details>
              {chart.timeCorrection?.boundaryWarning && (
                <p className="boundary-warning">⚠ {chart.timeCorrection.boundaryWarning}</p>
              )}
            </div>
          )}

          {luck && (
            <div className="facts-block">
              <h4>운 흐름</h4>
              <LuckTimeline luck={luck} />
            </div>
          )}

          {session.tarotCards && session.tarotCards.length > 0 && (
            <div className="facts-block">
              <h4>뽑힌 카드</h4>
              <p>
                {session.tarotCards
                  .map(
                    (c) =>
                      `${c.positionLabel ? `[${c.positionLabel}] ` : ""}${c.card.name} (${c.reversed ? "역방향" : "정방향"})`,
                  )
                  .join(" · ")}
              </p>
            </div>
          )}
        </div>
      )}

      {summary && (
        <div className="card reading-summary">
          <h3>{summary.title}</h3>
          <Markdown>{summary.body}</Markdown>
        </div>
      )}

      {rest.map((section) => (
        <details key={section.title} className="card reading-section" open>
          <summary>{section.title}</summary>
          <Markdown>{section.body}</Markdown>
        </details>
      ))}
    </div>
  );
}
