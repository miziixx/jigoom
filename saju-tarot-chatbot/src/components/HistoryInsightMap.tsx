import type { ReadingSession } from "../types";

const TYPE_LABEL: Record<ReadingSession["type"], string> = {
  saju: "사주",
  tarot: "타로",
  combo: "통합",
  today: "오늘",
  flow: "흐름",
};

const KEYWORDS = ["일", "돈", "관계", "연애", "건강", "이직", "감정", "선택", "가족", "사업", "공부", "휴식"];

function replyOf(session: ReadingSession): string {
  return session.messages.find((m) => m.role === "assistant")?.content ?? "";
}

function topKeywords(sessions: ReadingSession[]): string[] {
  const text = sessions.map((s) => `${s.question}\n${replyOf(s)}`).join("\n");
  return KEYWORDS.map((keyword) => ({ keyword, count: (text.match(new RegExp(keyword, "g")) ?? []).length }))
    .filter((item) => item.count > 0)
    .sort((a, b) => b.count - a.count)
    .slice(0, 5)
    .map((item) => `${item.keyword} ${item.count}회`);
}

export default function HistoryInsightMap({ sessions }: { sessions: ReadingSession[] }) {
  if (sessions.length < 2) return null;
  const favorites = sessions.filter((s) => s.favorite).length;
  const followUps = sessions.reduce((sum, s) => sum + s.messages.slice(2).filter((m) => m.role === "user").length, 0);
  const typeCounts = sessions.reduce<Record<string, number>>((acc, session) => {
    acc[session.type] = (acc[session.type] ?? 0) + 1;
    return acc;
  }, {});
  const mostUsedType = Object.entries(typeCounts).sort((a, b) => b[1] - a[1])[0];
  const keywords = topKeywords(sessions);

  return (
    <section className="card history-insight-map">
      <div className="section-heading-row">
        <h3 className="card-title">내 리딩 변화 추적</h3>
        <span className="feature-badge">기록 기반</span>
      </div>
      <div className="history-insight-map__grid">
        <div>
          <b>{sessions.length}건</b>
          <span>저장된 리딩</span>
        </div>
        <div>
          <b>{favorites}건</b>
          <span>즐겨찾기</span>
        </div>
        <div>
          <b>{followUps}개</b>
          <span>후속 질문</span>
        </div>
        <div>
          <b>{mostUsedType ? TYPE_LABEL[mostUsedType[0] as ReadingSession["type"]] : "-"}</b>
          <span>가장 많이 본 리딩</span>
        </div>
      </div>
      {keywords.length > 0 && <p className="history-insight-map__keywords">반복 키워드: {keywords.join(" · ")}</p>}
    </section>
  );
}
