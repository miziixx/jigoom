import LoadingNotice from "./LoadingNotice";
import SajuFactsPanel from "./SajuFactsPanel";
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

const CATEGORY_SECTION_TITLE = "분야별 요약";

interface CategorySummary {
  label: string;
  rating: "good" | "mid" | "caution";
  comment: string;
}

const RATING_WORD: Record<string, CategorySummary["rating"]> = { 좋음: "good", 보통: "mid", 주의: "caution" };
const RATING_LABEL: Record<CategorySummary["rating"], string> = { good: "좋음", mid: "보통", caution: "주의" };

/** "- 라벨: 평가 좋음|보통|주의 — 코멘트" 형식의 줄만 파싱한다. 형식이 어긋나면 그 줄은 건너뛴다. */
function parseCategorySummary(sections: Section[]): CategorySummary[] | null {
  const section = sections.find((s) => s.title === CATEGORY_SECTION_TITLE);
  if (!section) return null;
  const items: CategorySummary[] = [];
  for (const line of section.body.split("\n")) {
    const m = line.trim().match(/^-\s*([^:]+):\s*평가\s*(좋음|보통|주의)\s*[—-]\s*(.+)$/);
    if (!m) continue;
    items.push({ label: m[1].trim(), rating: RATING_WORD[m[2]], comment: m[3].trim() });
  }
  return items.length > 0 ? items : null;
}

function CategorySummaryCard({ item }: { item: CategorySummary }) {
  return (
    <div className="reading-category-card">
      <div className="reading-category-card__head">
        <span className="reading-category-card__label">{item.label}</span>
        <span className={`reading-badge reading-badge--${item.rating}`}>{RATING_LABEL[item.rating]}</span>
      </div>
      <p className="reading-category-card__comment">{item.comment}</p>
    </div>
  );
}

export default function ReadingResult({ session, loading = false }: { session: ReadingSession; loading?: boolean }) {
  const reply = session.messages.find((m) => m.role === "assistant")?.content ?? "";
  const sections = parseSections(reply);
  const categorySummary = parseCategorySummary(sections);
  const [summary, ...restRaw] = sections;
  const rest = restRaw.filter((s) => s.title !== CATEGORY_SECTION_TITLE);

  return (
    <div className="reading-result">
      {loading && <LoadingNotice depth={session.context?.depth} />}

      <SajuFactsPanel sajuChart={session.sajuChart} luckCycles={session.luckCycles} />

      {session.tarotCards && session.tarotCards.length > 0 && (
        <div className="card facts-panel">
          <div className="facts-block">
            <h4>뽑힌 카드</h4>
            <p>
              {session.tarotCards
                .map((c) => `${c.positionLabel ? `[${c.positionLabel}] ` : ""}${c.card.name} (${c.reversed ? "역방향" : "정방향"})`)
                .join(" · ")}
            </p>
          </div>
        </div>
      )}

      {summary && (
        <div className="card reading-summary">
          <h3>{summary.title}</h3>
          <p className="reading-body">
            {summary.body}
            {loading && rest.length === 0 && <span className="reading-typing"> ▌</span>}
          </p>
        </div>
      )}

      {categorySummary && (
        <section className="card">
          <h3 className="card-title">분야별 요약</h3>
          <div className="reading-category-grid">
            {categorySummary.map((item) => (
              <CategorySummaryCard key={item.label} item={item} />
            ))}
          </div>
        </section>
      )}

      {loading
        ? rest.map((section, i) => (
            <div key={section.title} className="card reading-section reading-section--live">
              <h4 className="reading-section__live-title">{section.title}</h4>
              <p className="reading-body">
                {section.body}
                {i === rest.length - 1 && <span className="reading-typing"> ▌</span>}
              </p>
            </div>
          ))
        : rest.map((section) => (
            <details key={section.title} className="card reading-section">
              <summary>{section.title}</summary>
              <p className="reading-body">{section.body}</p>
            </details>
          ))}
    </div>
  );
}
