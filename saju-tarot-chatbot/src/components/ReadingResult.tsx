import LoadingNotice from "./LoadingNotice";
import SajuFactsPanel from "./SajuFactsPanel";
import type { ReadingSession } from "../types";

interface Section {
  title: string;
  body: string;
}

interface BodyPart {
  title: string | null;
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

function parseBodyParts(text: string): BodyPart[] {
  const parts = text.split(/^\[([^\]]+)\]\s*$/m);
  if (parts.length <= 1) return [{ title: null, body: text }];

  const result: BodyPart[] = [];
  const intro = parts[0]?.trim();
  if (intro) result.push({ title: null, body: intro });
  for (let i = 1; i < parts.length; i += 2) {
    result.push({ title: parts[i].trim(), body: (parts[i + 1] ?? "").trim() });
  }
  return result.filter((part) => part.body.length > 0);
}

/**
 * 본문에서 마크다운 기호를 제거해 깔끔한 문장만 남긴다.
 * (모델이 실수로 넣어도 화면에 **, -, # 같은 기호가 보이지 않게 하는 방어선)
 * '분야별 요약'은 파싱을 먼저 끝낸 뒤라 여기서 정리해도 안전하다.
 */
function stripMarkdown(text: string): string {
  return text
    .replace(/\*\*(.+?)\*\*/g, "$1") // **굵게**
    .replace(/__(.+?)__/g, "$1") // __굵게__
    .replace(/`([^`]+)`/g, "$1") // `코드`
    .replace(/^#{1,6}\s+/gm, "") // 본문 속 소제목
    .replace(/^\s*>\s?/gm, "") // 인용
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function renderTextBlock(text: string) {
  const blocks: JSX.Element[] = [];
  const lines = stripMarkdown(text).split("\n");
  let paragraph: string[] = [];
  let bullets: string[] = [];

  const flushParagraph = () => {
    const body = paragraph.join("\n").trim();
    if (body) {
      blocks.push(
        <p className="reading-body" key={`p-${blocks.length}`}>
          {body}
        </p>,
      );
    }
    paragraph = [];
  };

  const flushBullets = () => {
    if (bullets.length > 0) {
      blocks.push(
        <ul className="reading-bullets" key={`ul-${blocks.length}`}>
          {bullets.map((item, i) => (
            <li key={i}>{item}</li>
          ))}
        </ul>,
      );
    }
    bullets = [];
  };

  for (const line of lines) {
    const bullet = line.match(/^\s*[-*+]\s+(.+)$/);
    if (bullet) {
      flushParagraph();
      bullets.push(bullet[1].trim());
      continue;
    }
    if (!line.trim()) {
      flushParagraph();
      flushBullets();
      continue;
    }
    flushBullets();
    paragraph.push(line);
  }
  flushParagraph();
  flushBullets();

  return blocks.length > 0 ? blocks : null;
}

function SectionBody({ body, loading }: { body: string; loading?: boolean }) {
  const parts = parseBodyParts(body);
  if (parts.length === 1 && !parts[0].title) {
    return (
      <div className="reading-section__body">
        {renderTextBlock(parts[0].body)}
        {loading && <span className="reading-typing"> ▌</span>}
      </div>
    );
  }

  return (
    <div className="reading-section__body">
      {parts.map((part) => {
        const isEvidence = part.title === "전문가 근거 보기";
        if (isEvidence) {
          return (
            <details className="expert-evidence" key={part.title}>
              <summary>{part.title}</summary>
              <div className="expert-evidence__body">{renderTextBlock(part.body)}</div>
            </details>
          );
        }
        return (
          <div className="reading-part" key={part.title ?? "intro"}>
            {part.title && <h4 className="reading-part__title">{part.title}</h4>}
            {renderTextBlock(part.body)}
          </div>
        );
      })}
      {loading && <span className="reading-typing"> ▌</span>}
    </div>
  );
}

const HERO_OPENING = "첫 점괘";
const HERO_CLOSING = "마지막 점괘";
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
    items.push({ label: m[1].trim(), rating: RATING_WORD[m[2]], comment: stripMarkdown(m[3].trim()) });
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

  const opening = sections.find((s) => s.title === HERO_OPENING) ?? sections[0];
  const closing = sections.find((s) => s.title === HERO_CLOSING);
  // 본문 카드: 첫/마지막 점괘·분야별 요약을 제외한 나머지
  const bodySections = sections.filter(
    (s) => s !== opening && s !== closing && s.title !== CATEGORY_SECTION_TITLE,
  );

  return (
    <div className="reading-result">
      {loading && <LoadingNotice depth={session.context?.depth} />}

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

      {opening && (
        <div className="card reading-oracle reading-oracle--opening">
          <span className="reading-oracle__tag">첫 점괘</span>
          <p className="reading-oracle__text">
            {stripMarkdown(opening.body)}
            {loading && bodySections.length === 0 && !closing && <span className="reading-typing"> ▌</span>}
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

      {bodySections.map((section, i) => (
        <section key={section.title} className="card reading-section reading-section--open">
          <h3 className="reading-section__title">{section.title}</h3>
          <SectionBody body={section.body} loading={loading && i === bodySections.length - 1 && !closing} />
        </section>
      ))}

      {closing && (
        <div className="card reading-oracle reading-oracle--closing">
          <span className="reading-oracle__tag">마지막 점괘</span>
          <p className="reading-oracle__text">
            {stripMarkdown(closing.body)}
            {loading && <span className="reading-typing"> ▌</span>}
          </p>
        </div>
      )}

      {/* 근거(원국·신살·세운) — 사주 용어는 여기에만 둔다. 몰입 리딩 뒤 신뢰 보강용. */}
      {(session.sajuChart || session.luckCycles) && (
        <details className="reading-evidence">
          <summary>이 풀이의 근거가 된 내 사주 보기</summary>
          <div className="reading-evidence__body">
            <SajuFactsPanel sajuChart={session.sajuChart} luckCycles={session.luckCycles} />
          </div>
        </details>
      )}
    </div>
  );
}
