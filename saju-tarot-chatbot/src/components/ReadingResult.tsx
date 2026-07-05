import LoadingNotice from "./LoadingNotice";
import SajuFactsPanel, { SajuPillarSnapshot } from "./SajuFactsPanel";
import InstantSummary from "./InstantSummary";
import PatternMap from "./PatternMap";
import ActionCalendar from "./ActionCalendar";
import ActionChecklist from "./ActionChecklist";
import EvidenceConfidence from "./EvidenceConfidence";
import TarotSummaryHero from "./TarotSummaryHero";
import SummaryCardGrid from "./SummaryCardGrid";
import PersonalitySpectrum from "./PersonalitySpectrum";
import LifeAreaBars from "./LifeAreaBars";
import EventForecastPanel from "./EventForecastPanel";
import PastValidationPanel from "./PastValidationPanel";
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
  opportunity?: string;
  caution?: string;
  advice: string;
}

const SECTION_META: Record<string, { tag: string; tone: string }> = {
  "사주로 보는 장기 흐름": { tag: "사주", tone: "flow" },
  "타로로 보는 현재 흐름": { tag: "타로", tone: "tarot" },
  "통합 판단": { tag: "통합", tone: "action" },
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

function partDisplayMeta(title: string): { label: string | null; tone: string } {
  const meta = PART_META[title];
  if (!meta) return { label: null, tone: "default" };
  return { label: meta.label === title ? null : meta.label, tone: meta.tone };
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

/**
 * 현재 프롬프트가 요구하는 고정 포맷을 파싱한다: 한 달에 한 줄, "|"로 구분된 4개 필드.
 *  "N월 | 키워드: X | 기회: Y | 주의: Z | 조언: W"
 * 스트리밍 도중 마지막 줄이 잘려 있으면(필드가 안 채워지면) 그 줄은 조용히 버린다.
 */
function parseStrictMonthlyFlow(text: string): { intro: string; months: MonthEvidence[] } | null {
  const clean = stripMarkdown(text);
  const lines = clean.split("\n");
  const lineRe =
    /^\s*(\d{1,2}월(?:\([^)]*\))?)\s*\|\s*키워드\s*[:：]\s*([^|]*)\|\s*기회\s*[:：]\s*([^|]*)\|\s*주의\s*[:：]\s*([^|]*)\|\s*조언\s*[:：]\s*(.+?)\s*$/;

  const introLines: string[] = [];
  const months: MonthEvidence[] = [];
  let sawMonthLine = false;

  for (const line of lines) {
    const match = line.match(lineRe);
    if (match) {
      sawMonthLine = true;
      months.push({
        month: match[1],
        keyword: match[2].trim(),
        opportunity: match[3].trim() || undefined,
        caution: match[4].trim() || undefined,
        advice: match[5].trim(),
      });
      continue;
    }
    if (!sawMonthLine) introLines.push(line);
    // 월 목록이 시작된 뒤 형식에 안 맞는 줄(스트리밍 중 잘린 마지막 줄 등)은 조용히 무시한다.
  }

  return months.length >= 3 ? { intro: introLines.join("\n").trim(), months } : null;
}

/**
 * 과거(고정 포맷 도입 전)에 저장된 리딩과의 호환을 위한 폴백 파서. 두 형식을 지원한다:
 *  - "N월 — 키워드: X. 조언: Y"
 *  - "N월, 키워드는 X. 본문 설명... 한 줄 조언: Y"
 */
function parseLegacyProseMonthlyFlow(text: string): { intro: string; months: MonthEvidence[] } | null {
  const clean = stripMarkdown(text);
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

      let advice = "";
      const adv = rest.match(/(?:한 줄\s*)?조언\s*[:：]\s*(.+)$/);
      if (adv) {
        advice = adv[1].trim();
        rest = rest.slice(0, adv.index).trim();
      }

      let keyword = "";
      const kw = rest.match(/키워드[는은]?\s*[:：]?\s*([^.。]+)[.。]?/);
      if (kw) {
        keyword = kw[1].trim();
        rest = rest.slice(kw.index! + kw[0].length).trim();
      }

      const bodyDetail = rest.replace(/^[.。,\s]+/, "").trim();
      if (!keyword && !advice) return null;
      return { month, keyword, opportunity: bodyDetail || undefined, advice };
    })
    .filter((item): item is MonthEvidence => Boolean(item));

  return months.length >= 3 ? { intro, months } : null;
}

function parseMonthlyFlow(text: string): { intro: string; months: MonthEvidence[] } | null {
  return parseStrictMonthlyFlow(text) ?? parseLegacyProseMonthlyFlow(text);
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
            {item.opportunity && (
              <p className="month-evidence-card__opportunity">
                <span>기회</span> {item.opportunity}
              </p>
            )}
            {item.caution && (
              <p className="month-evidence-card__caution">
                <span>주의</span> {item.caution}
              </p>
            )}
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
        const meta = part.title ? partDisplayMeta(part.title) : null;
        if (isEvidence) {
          return (
            <details className="expert-evidence" key={part.title}>
              <summary>{part.title}</summary>
              <div className="expert-evidence__body">{renderTextBlock(part.body)}</div>
            </details>
          );
        }
        return (
          <div className={`reading-part${part.title ? ` reading-part--${meta?.tone ?? "default"}` : ""}`} key={part.title ?? "intro"}>
            {part.title && (
              <h4 className="reading-part__title">
                {meta?.label && <span className="reading-part__label">{meta.label}</span>}
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

function sectionAnchor(title: string): string {
  return `reading-${title.replace(/\s+/g, "-").replace(/[^\p{L}\p{N}-]/gu, "")}`;
}

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

function ReadingTableOfContents({ sections }: { sections: Section[] }) {
  if (sections.length === 0) return null;

  // 이 앱은 HashRouter를 쓰므로 <a href="#..."> 는 페이지 내 스크롤이 아니라 라우터의
  // 경로 이동으로 해석되어 존재하지 않는 라우트(빈 화면)로 튕긴다. 버튼 + 직접 스크롤로 대체한다.
  function goTo(title: string) {
    const el = document.getElementById(sectionAnchor(title));
    if (!el) return;
    if (el instanceof HTMLDetailsElement) el.open = true;
    el.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  return (
    <nav className="card reading-toc" aria-label="리딩 목차">
      <div className="reading-toc__head">
        <span>목차</span>
        <p>위의 총평을 먼저 읽고, 필요한 부분만 펼쳐서 보세요.</p>
      </div>
      <div className="reading-toc__links">
        {sections.map((section) => (
          <button type="button" className="reading-toc__link" key={section.title} onClick={() => goTo(section.title)}>
            <span>{SECTION_META[section.title]?.tag ?? "풀이"}</span>
            {section.title}
          </button>
        ))}
      </div>
    </nav>
  );
}

/** 계산 위젯(오행/대운/신살/월별 등)을 기본 닫힘 상태로 모아, 총평·목차·본문 사이 스크롤을 줄인다. */
function CalculationEvidenceZone({
  session,
  dashboard,
  loading,
}: {
  session: ReadingSession;
  dashboard: ReturnType<typeof buildReadingDashboard>;
  loading: boolean;
}) {
  const hasSaju = !!(session.sajuChart || session.luckCycles);
  const hasTarot = !!(session.tarotCards && session.tarotCards.length > 0);
  if (!dashboard && !hasSaju && !hasTarot) return null;

  return (
    <details className="reading-evidence-zone">
      <summary>
        <span>계산 근거 자세히 보기</span>
        <p>사주 원국·오행·대운/세운 흐름{hasTarot ? "과 타로 카드 근거" : ""}를 자세히 확인할 수 있어요.</p>
      </summary>
      <div className="reading-evidence-zone__body">
        {dashboard && <LifeAreaBars areas={dashboard.lifeAreas} />}
        <EvidenceConfidence session={session} />
        {session.sajuChart && (
          <InstantSummary sajuChart={session.sajuChart} luckCycles={session.luckCycles} loading={loading} />
        )}
        {session.type !== "combo" && hasTarot && <TarotFactsPanel cards={session.tarotCards!} />}
        {dashboard && <PersonalitySpectrum spectrum={dashboard.spectrum} />}
        {session.sajuChart && <PatternMap sajuChart={session.sajuChart} />}
        {session.luckCycles?.monthlyFlow && <ActionCalendar luckCycles={session.luckCycles} />}
        {session.sajuChart && <LifestyleClosingSummary session={session} />}
      </div>
    </details>
  );
}

function DetailLoadingCard() {
  return (
    <section className="card reading-detail-status">
      <span className="reading-detail-status__tag">AI 상세 리딩</span>
      <h3 className="card-title">상세 풀이를 쓰고 있어요</h3>
      <p className="reading-body">
        위의 빠른 요약은 계산값으로 바로 보여드린 내용입니다. 질문 답변, 분야별 상세 풀이, 월별 흐름은 아래에 도착하는 대로 이어집니다.
      </p>
    </section>
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
  const hasReply = reply.trim().length > 0;
  const sections = hasReply ? parseSections(reply) : [];
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
      {loading && (
        <LoadingNotice
          depth={session.context?.depth}
          type={session.type}
          hasQuestion={!!session.question?.trim()}
          replyText={reply}
          isInitial={session.messages.length <= 2}
        />
      )}

      {/* 한눈에 보기 영역 — 요약, 원국 4기둥, 총평, 질문 답변, 분야 요약, 목차까지만 항상 펼침 */}
      {dashboard && (
        <SummaryCardGrid conclusion={conclusion} keywords={dashboard.keywords} dashboard={dashboard} />
      )}

      <SajuPillarSnapshot sajuChart={session.sajuChart} />

      {session.sajuChart && (
        <section className="reading-basic-report" aria-label="기본 사주 리포트">
          <div className="reading-layer-heading">
            <span>기본 사주 리포트</span>
            <p>원국·오행·십신·신살·대운과 세운을 먼저 한눈에 정리했어요. 긴 풀이 전에 내 사주의 기본 베이스를 확인할 수 있습니다.</p>
          </div>
          <SajuFactsPanel
            sajuChart={session.sajuChart}
            luckCycles={session.luckCycles}
            birthInfo={session.birthInfo}
            showPillars={false}
          />
        </section>
      )}

      {/* 사건화 예보: 원국이 있는 리딩에서 "지금 어느 분야가 움직이는지"를 계산값으로 바로 보여준다. */}
      {session.sajuChart && (
        <EventForecastPanel
          sajuChart={session.sajuChart}
          luckCycles={session.luckCycles}
          gender={session.birthInfo?.gender}
        />
      )}

      {/* 과거 검증: 사용자가 과거 사건을 입력했으면 그 시기 흐름과의 부합도를 보여준다. */}
      {session.sajuChart && session.context?.pastEvents && session.context.pastEvents.length > 0 && (
        <PastValidationPanel
          birthInfo={session.birthInfo}
          sajuChart={session.sajuChart}
          pastEvents={session.context.pastEvents}
        />
      )}

      {/* 타로 헤드라인은 접지 않는다: 순수 타로 리딩에서 AI 텍스트가 나오기 전 유일한 즉시 요약이다. */}
      {session.type !== "combo" && session.tarotCards && session.tarotCards.length > 0 && (
        <TarotSummaryHero cards={session.tarotCards} />
      )}

      {session.type === "combo" && session.tarotCards && session.tarotCards.length > 0 && (
        <section className="combo-result-layer" aria-label="타로 카드 요약">
          <div className="reading-layer-heading">
            <span>타로 카드 흐름</span>
            <p>사주는 큰 흐름을, 타로는 지금 질문의 가까운 분위기를 보여줍니다. 뽑힌 카드는 아래에서 바로 확인할 수 있어요.</p>
          </div>
          <TarotSummaryHero cards={session.tarotCards} />
          <TarotFactsPanel cards={session.tarotCards} />
        </section>
      )}

      {!hasReply && loading && <DetailLoadingCard />}

      {hasReply && (
        <section className="reading-detail-layer" aria-label="AI 상세 리딩">
          <div className="reading-layer-heading">
            <span>AI 상세 리딩</span>
            <p>빠른 요약에서 잡은 흐름을 질문과 분야별 상황에 맞춰 풀어드립니다.</p>
          </div>

          {questionCore && (
            <section className="card question-core-card">
              <span className="question-core-card__tag">
                {session.question?.trim() ? "내 질문에 대한 먼저 답변" : "선택한 관심사 핵심 보기"}
              </span>
              <h3 className="card-title">{session.question?.trim() ? session.question.trim() : "지금 먼저 볼 핵심"}</h3>
              <SectionBody body={questionCore.body} loading={loading && bodySections.length === 0 && !closing} />
            </section>
          )}

          {opening && (
            <div className="card reading-oracle reading-oracle--opening">
              <span className="reading-oracle__tag">전체 총평</span>
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

          <ReadingTableOfContents sections={bodySections} />

          <CalculationEvidenceZone session={session} dashboard={dashboard} loading={loading} />

          {bodySections.map((section, i) => (
            <details
              key={section.title}
              id={sectionAnchor(section.title)}
              className={`card reading-section reading-section--open reading-section--${SECTION_META[section.title]?.tone ?? "default"}`}
            >
              <summary className="reading-section__head">
                <span className="reading-section__tag">{SECTION_META[section.title]?.tag ?? "풀이"}</span>
                <h3 className="reading-section__title">{section.title}</h3>
              </summary>
              <SectionBody body={section.body} loading={loading && i === bodySections.length - 1 && !closing} />
            </details>
          ))}

          {closing && (
            <div className="card reading-oracle reading-oracle--closing">
              <span className="reading-oracle__tag">마지막 정리</span>
              <p className="reading-oracle__text">
                {stripMarkdown(closing.body)}
                {loading && <span className="reading-typing"> ▌</span>}
              </p>
            </div>
          )}
        </section>
      )}

      {session.sajuChart && <ActionChecklist sajuChart={session.sajuChart} luckCycles={session.luckCycles} />}
    </div>
  );
}
