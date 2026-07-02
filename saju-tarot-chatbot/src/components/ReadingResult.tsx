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
              </p>
            </div>
          )}
          {session.tarotCards && session.tarotCards.length > 0 && (
            <div className="facts-block">
              <h4>뽑힌 카드</h4>
              <p>
                {session.tarotCards
                  .map((c) => `${c.card.name} (${c.reversed ? "역방향" : "정방향"})`)
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
