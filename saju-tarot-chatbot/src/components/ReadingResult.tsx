import type { ReadingSession } from "../types";

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

  return (
    <div className="reading-result">
      {(session.sajuChart || (session.tarotCards && session.tarotCards.length > 0)) && (
        <div className="card facts-panel">
          {session.sajuChart && (
            <div className="facts-block">
              <h4>사주 원국</h4>
              <p>
                연주 {session.sajuChart.year.ganZhi} · 월주 {session.sajuChart.month.ganZhi} · 일주{" "}
                {session.sajuChart.day.ganZhi}
                {session.sajuChart.hour ? ` · 시주 ${session.sajuChart.hour.ganZhi}` : " · 시주 모름"}
              </p>
              <p>
                오행 — 목 {session.sajuChart.fiveElements.wood} · 화 {session.sajuChart.fiveElements.fire} · 토{" "}
                {session.sajuChart.fiveElements.earth} · 금 {session.sajuChart.fiveElements.metal} · 수{" "}
                {session.sajuChart.fiveElements.water}
                {session.sajuChart.yinYang && (
                  <>
                    {" "}
                    · 양 {session.sajuChart.yinYang.yang} / 음 {session.sajuChart.yinYang.yin}
                  </>
                )}
              </p>
              {session.sajuChart.strength && (
                <p>
                  신강/신약(간이) — {session.sajuChart.strength.label}
                  {session.sajuChart.yongshin && <> · 용신 후보: {session.sajuChart.yongshin.supportive.join("·")}</>}
                </p>
              )}
              {session.sajuChart.interactions && session.sajuChart.interactions.length > 0 && (
                <p>합충형파해 — {session.sajuChart.interactions.join(", ")}</p>
              )}
            </div>
          )}
          {session.luckCycles && (
            <div className="facts-block">
              <h4>운 흐름</h4>
              <p>
                현재 대운 {session.luckCycles.currentDaYun ?? "시작 전"} · 세운({session.luckCycles.year}년){" "}
                {session.luckCycles.yearGanZhi} · 월운({session.luckCycles.month}월) {session.luckCycles.monthGanZhi}
              </p>
              <p>
                대운:{" "}
                {session.luckCycles.daYun
                  .map((dy) => `${dy.startAge}세 ${dy.ganZhi}${dy.current ? "★" : ""}`)
                  .join(" → ")}
              </p>
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
          <p className="reading-body">{summary.body}</p>
        </div>
      )}

      {rest.map((section) => (
        <details key={section.title} className="card reading-section">
          <summary>{section.title}</summary>
          <p className="reading-body">{section.body}</p>
        </details>
      ))}
    </div>
  );
}
