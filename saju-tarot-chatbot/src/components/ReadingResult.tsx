import LoadingNotice from "./LoadingNotice";
import SajuFactsPanel from "./SajuFactsPanel";
import InstantSummary from "./InstantSummary";
import PatternMap from "./PatternMap";
import ActionCalendar from "./ActionCalendar";
import ActionChecklist from "./ActionChecklist";
import EvidenceConfidence from "./EvidenceConfidence";
import TarotSummaryHero from "./TarotSummaryHero";
import SummaryCardGrid from "./SummaryCardGrid";
import PersonalitySpectrum from "./PersonalitySpectrum";
import LifeAreaBars from "./LifeAreaBars";
import { buildLifestyleGuide } from "../lib/lifestyleGuide";
import { buildReadingDashboard } from "../lib/readingDashboard";
import TarotFactsPanel from "./TarotFactsPanel";
import type { ReadingSession } from "../types";

interface Section {
  title: string;
  body: string;
}

interface BodyPart {
  title: string | null;
  body: string;
}

interface MonthEvidence {
  month: string;
  keyword: string;
  /** 키워드와 조언 사이의 설명 본문(있으면). 내용을 버리지 않기 위해 보존한다. */
  body?: string;
  advice: string;
}

const SECTION_META: Record<string, { tag: string; tone: string }> = {
  "타고난 성격과 기질": { tag: "기질", tone: "self" },
  "직업과 돈": { tag: "일과 돈", tone: "work" },
  "재물 흐름": { tag: "재물", tone: "money" },
  "애정과 관계": { tag: "관계", tone: "love" },
  "건강과 컨디션": { tag: "컨디션", tone: "health" },
  "인생의 큰 흐름": { tag: "큰 흐름", tone: "flow" },
  "올해의 흐름": { tag: "올해", tone: "year" },
  "지금 해야 할 것과 피해야 할 것": { tag: "행동", tone: "action" },
};

const PART_META: Record<string, { label: string; tone: string }> = {
  "한 줄 결론": { label: "결론", tone: "conclusion" },
  "쉬운 풀이": { label: "풀이", tone: "plain" },
  "왜 그렇게 보는지": { label: "근거 번역", tone: "why" },
  "현실에서 나타나는 모습": { label: "현실 예시", tone: "life" },
  "조심할 점": { label: "주의", tone: "caution" },
  "활용 방법 / 보완 방법": { label: "활용", tone: "use" },
  "오늘 바로 할 수 있는 행동": { label: "바로 실행", tone: "todo" },
};

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

/**
 * 1~12월(또는 여러 달) 나열 문단을 월별 카드로 파싱한다. 두 형식을 모두 지원한다:
 *  - "N월 — 키워드: X. 조언: Y"
 *  - "N월, 키워드는 X. 본문 설명... 한 줄 조언: Y"
 * 키워드/조언 외 중간 설명은 body로 보존해 내용을 버리지 않는다.
 */
function parseMonthlyFlow(text: string): { intro: string; months: MonthEvidence[] } | null {
  const clean = stripMarkdown(text);
  // 월 시작 위치(줄 시작에서 "N월")
  const monthStart = clean.search(/(?:^|\n)\s*\d{1,2}월/);
  if (monthStart < 0) return null;

  const intro = clean.slice(0, monthStart).trim();
  const monthText = clean.slice(monthStart).trim();
  const chunks = monthText.split(/\n(?=\s*\d{1,2}월)/);
  const months = chunks
    .map((chunk): MonthEvidence | null => {
      const norm = chunk.replace(/\s+/g, " ").trim();
      const head = norm.match(/^(\d{1,2}월(?:\([^)]*\))?)\s*[,，—-]?\s*(.*)$/);
      if (!head) return null;
      const month = head[1];
      let rest = head[2];

      // 조언 추출 ("한 줄 조언:" 또는 "조언:")
      let advice = "";
      const adv = rest.match(/(?:한 줄\s*)?조언\s*[:：]\s*(.+)$/);
      if (adv) {
        advice = adv[1].trim();
        rest = rest.slice(0, adv.index).trim();
      }

      // 키워드 추출 ("키워드는 X" / "키워드: X")
      let keyword = "";
      const kw = rest.match(/키워드[는은]?\s*[:：]?\s*([^.。]+)[.。]?/);
      if (kw) {
        keyword = kw[1].trim();
        rest = rest.slice(kw.index! + kw[0].length).trim();
      }

      const bodyDetail = rest.replace(/^[.。,\s]+/, "").trim();
      // 키워드나 조언 구조가 있어야 월별 카드로 본다(단순 "N월에는…" 언급은 제외).
      if (!keyword && !advice) return null;
      return { month, keyword, body: bodyDetail || undefined, advice };
    })
    .filter((item): item is MonthEvidence => Boolean(item));

  return months.length >= 3 ? { intro, months } : null;
}

function MonthlyFlowOrText({ body }: { body: string }) {
  const monthly = parseMonthlyFlow(body);
  if (!monthly) return <>{renderTextBlock(body)}</>;

  return (
    <div className="evidence-translation">
      {monthly.intro && <div className="evidence-translation__intro">{renderTextBlock(monthly.intro)}</div>}
      <div className="month-evidence-grid">
        {monthly.months.map((item) => (
          <article className="month-evidence-card" key={item.month}>
            <span className="month-evidence-card__month">{item.month}</span>
            {item.keyword && <b>{item.keyword}</b>}
            {item.body && <p className="month-evidence-card__body">{item.body}</p>}
            {item.advice && (
              <p className="month-evidence-card__advice">
                <span>조언</span> {item.advice}
              </p>
            )}
          </article>
        ))}
      </div>
    </div>
  );
}

function SectionBody({ body, loading }: { body: string; loading?: boolean }) {
  const parts = parseBodyParts(body);
  if (parts.length === 1 && !parts[0].title) {
    return (
      <div className="reading-section__body">
        <MonthlyFlowOrText body={parts[0].body} />
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
          <div className={`reading-part${part.title ? ` reading-part--${PART_META[part.title]?.tone ?? "default"}` : ""}`} key={part.title ?? "intro"}>
            {part.title && (
              <h4 className="reading-part__title">
                <span className="reading-part__label">{PART_META[part.title]?.label ?? part.title}</span>
                <span>{part.title}</span>
              </h4>
            )}
            <MonthlyFlowOrText body={part.body} />
          </div>
        );
      })}
      {loading && <span className="reading-typing"> ▌</span>}
    </div>
  );
}

/** 요약 히어로에 쓸 "한 줄 결론"을 추출한다. 질문 핵심 → 첫 점괘 순으로, [한 줄 결론] 파트가
 * 있으면 그 첫 문장, 없으면 본문 첫 문장을 쓴다. */
function extractConclusion(candidates: Array<Section | undefined>): string | null {
  for (const section of candidates) {
    if (!section) continue;
    const parts = parseBodyParts(section.body);
    const conclusionPart = parts.find((p) => p.title === "한 줄 결론");
    const source = conclusionPart?.body ?? parts.find((p) => !p.title)?.body ?? section.body;
    const clean = stripMarkdown(source).trim();
    if (!clean) continue;
    const firstSentence = clean.split(/(?<=[.!?。])\s+|\n/)[0]?.trim();
    if (firstSentence && firstSentence.length >= 6) return firstSentence;
  }
  return null;
}

const HERO_OPENING = "첫 점괘";
const HERO_CLOSING = "마지막 점괘";
const CATEGORY_SECTION_TITLE = "분야별 요약";
const QUESTION_CORE_TITLE = "질문 중심 핵심";

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

function LifestyleClosingSummary({ session }: { session: ReadingSession }) {
  if (!session.sajuChart) return null;
  const guide = buildLifestyleGuide(session.sajuChart, { todayGanZhi: session.luckCycles?.dayGanZhi });
  return (
    <section className="card lifestyle-closing">
      <span className="lifestyle-closing__tag">오늘 써먹는 내 기운</span>
      <h3 className="card-title">마지막 생활 정리</h3>
      <div className="lifestyle-closing__hero">
        <span className={`lifestyle-guide__badge lifestyle-guide__badge--${guide.basisElement}`}>{guide.basisLabel}</span>
        <p>
          {guide.basisReason}
          {guide.secondaryLabel && (
            <span className="lifestyle-closing__secondary"> · 보조 기운 {guide.secondaryLabel}</span>
          )}
        </p>
      </div>
      {guide.today && (
        <div className={`lifestyle-today lifestyle-today--${guide.today.relation}`}>
          <span className="lifestyle-today__badge">오늘 일진 {guide.today.label}</span>
          <b>{guide.today.headline}</b>
          <p>{guide.today.note}</p>
          <small>오늘 한 가지 — {guide.today.action}</small>
        </div>
      )}
      <div className="lifestyle-closing__chips">
        <span>색 {guide.colors.slice(0, 2).join(" · ")}</span>
        <span>숫자 {guide.numbers.join(" · ")}</span>
        <span>방향 {guide.directions[0]}</span>
        <span>장소 {guide.places.slice(0, 2).join(" · ")}</span>
      </div>
      <div className="lifestyle-closing__grid">
        <div>
          <b>건강 체크</b>
          <p>{guide.healthFocus.join(" · ")}</p>
        </div>
        <div>
          <b>운동</b>
          <p>{guide.movement.slice(0, 3).join(" · ")}</p>
        </div>
      </div>
      <div className="lifestyle-closing__actions">
        <b>바로 실행 3개</b>
        <ul>
          {guide.todayActions.map((action) => (
            <li key={action}>{action}</li>
          ))}
        </ul>
      </div>
      <p className="lifestyle-closing__note">
        절대적인 행운 예언이 아니라, 계산된 보완 흐름을 생활에서 써먹기 쉽게 바꾼 가이드입니다.
      </p>
    </section>
  );
}

export default function ReadingResult({ session, loading = false }: { session: ReadingSession; loading?: boolean }) {
  const reply = session.messages.find((m) => m.role === "assistant")?.content ?? "";
  const sections = parseSections(reply);
  const categorySummary = parseCategorySummary(sections);

  const opening = sections.find((s) => s.title === HERO_OPENING) ?? sections[0];
  const closing = sections.find((s) => s.title === HERO_CLOSING);
  const questionCore = sections.find((s) => s.title === QUESTION_CORE_TITLE);
  // 본문 카드: 첫/마지막 점괘·질문 핵심·분야별 요약을 제외한 나머지
  const bodySections = sections.filter(
    (s) => s !== opening && s !== closing && s !== questionCore && s.title !== CATEGORY_SECTION_TITLE,
  );

  const dashboard = buildReadingDashboard(session.sajuChart, session.luckCycles);
  const conclusion = extractConclusion([questionCore, opening]);

  return (
    <div className="reading-result">
      {loading && <LoadingNotice depth={session.context?.depth} />}

      {/* 타로 근거 (있을 때) */}
      {session.tarotCards && session.tarotCards.length > 0 && (
        <>
          <TarotSummaryHero cards={session.tarotCards} />
          <TarotFactsPanel cards={session.tarotCards} />
        </>
      )}

      {/* 사주 원국·신살·오행·대운/세운·1~12월 흐름 — 맨 위에 그대로 보이게 (원래대로) */}
      {(session.sajuChart || session.luckCycles) && (
        <SajuFactsPanel sajuChart={session.sajuChart} luckCycles={session.luckCycles} birthInfo={session.birthInfo} />
      )}

      {/* 요약 대시보드 — 핵심 한 줄 먼저 */}
      {dashboard && (
        <SummaryCardGrid conclusion={conclusion} keywords={dashboard.keywords} dashboard={dashboard} />
      )}

      {session.sajuChart && <InstantSummary sajuChart={session.sajuChart} luckCycles={session.luckCycles} loading={loading} />}

      {/* 한눈에 보는 내 구조 (기질 스펙트럼·인생영역) */}
      {dashboard && <PersonalitySpectrum spectrum={dashboard.spectrum} />}
      {dashboard && <LifeAreaBars areas={dashboard.lifeAreas} />}

      {session.sajuChart && <PatternMap sajuChart={session.sajuChart} />}
      {session.luckCycles?.monthlyFlow && <ActionCalendar luckCycles={session.luckCycles} />}
      <EvidenceConfidence session={session} />

      {opening && (
        <div className="card reading-oracle reading-oracle--opening">
          <span className="reading-oracle__tag">첫 점괘</span>
          <p className="reading-oracle__text">
            {stripMarkdown(opening.body)}
            {loading && bodySections.length === 0 && !closing && <span className="reading-typing"> ▌</span>}
          </p>
        </div>
      )}

      {questionCore && (
        <section className="card question-core-card">
          <span className="question-core-card__tag">
            {session.question?.trim() ? "내 질문에 대한 먼저 답변" : "선택한 관심사 핵심 보기"}
          </span>
          <h3 className="card-title">{session.question?.trim() ? session.question.trim() : "지금 먼저 볼 핵심"}</h3>
          <SectionBody body={questionCore.body} loading={loading && bodySections.length === 0 && !closing} />
        </section>
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
        <section
          key={section.title}
          className={`card reading-section reading-section--open reading-section--${SECTION_META[section.title]?.tone ?? "default"}`}
        >
          <div className="reading-section__head">
            <span className="reading-section__tag">{SECTION_META[section.title]?.tag ?? "풀이"}</span>
            <h3 className="reading-section__title">{section.title}</h3>
          </div>
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

      {/* 5. 실행 가이드 (체크리스트 신규 + 기존 생활 정리) */}
      {session.sajuChart && <ActionChecklist sajuChart={session.sajuChart} luckCycles={session.luckCycles} />}

      {session.sajuChart && <LifestyleClosingSummary session={session} />}
    </div>
  );
}
