/**
 * 리딩 결과 화면의 공용 블록 모음.
 * ReadingResult에서 추출한 것으로, 리딩 타입별 템플릿(평생사주/올해운세/고민리딩/타로)이
 * 같은 파서·카드·근거 존을 재사용할 수 있게 한다. 동작은 추출 전과 동일하다.
 */
import { useEffect, useState } from "react";
import ActionCalendar from "../ActionCalendar";
import EvidenceConfidence from "../EvidenceConfidence";
import InstantSummary from "../InstantSummary";
import LifeAreaBars from "../LifeAreaBars";
import PatternMap from "../PatternMap";
import PersonalitySpectrum from "../PersonalitySpectrum";
import TarotFactsPanel from "../TarotFactsPanel";
import MonthlyFlowChart from "../viz/MonthlyFlowChart";
import RatingCell from "../viz/RatingCell";
import { PartIcon, SectionIcon } from "../viz/icons";
import { buildLifestyleGuide } from "../../lib/lifestyleGuide";
import { buildReadingDashboard } from "../../lib/readingDashboard";
import { parseBodyParts, renderTextBlock, stripMarkdown, type Section } from "../../lib/readingText";
import type { LuckCycles, ReadingSession } from "../../types";

export interface MonthEvidence {
  month: string;
  keyword: string;
  opportunity?: string;
  caution?: string;
  advice: string;
}

export const SECTION_META: Record<string, { tag: string; tone: string }> = {
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
  "반복 패턴 정밀 진단": { tag: "정밀", tone: "pattern" },
  "선택과 시기 판단": { tag: "판단", tone: "decision" },
  "3개월 실행 전략": { tag: "전략", tone: "strategy" },
  "지금 해야 할 것과 피해야 할 것": { tag: "행동", tone: "action" },
};

export const PART_META: Record<string, { label: string; tone: string }> = {
  "한 줄 결론": { label: "결론", tone: "conclusion" },
  "쉬운 풀이": { label: "풀이", tone: "plain" },
  "왜 그렇게 보는지": { label: "근거 번역", tone: "why" },
  "현실에서 나타나는 모습": { label: "현실 예시", tone: "life" },
  "조심할 점": { label: "주의", tone: "caution" },
  "추천": { label: "추천", tone: "recommend" },
  "활용 방법 / 보완 방법": { label: "활용", tone: "use" },
  "오늘 바로 할 수 있는 행동": { label: "바로 실행", tone: "todo" },
};

export function partDisplayMeta(title: string): { label: string | null; tone: string } {
  const meta = PART_META[title];
  if (!meta) return { label: null, tone: "default" };
  return { label: meta.label === title ? null : meta.label, tone: meta.tone };
}

/**
 * 현재 프롬프트가 요구하는 고정 포맷을 파싱한다: 한 달에 한 줄, "|"로 구분된 4개 필드.
 *  "N월 | 키워드: X | 기회: Y | 주의: Z | 조언: W"
 * 스트리밍 도중 마지막 줄이 잘려 있으면(필드가 안 채워지면) 그 줄은 조용히 버린다.
 */
export function parseStrictMonthlyFlow(text: string): { intro: string; months: MonthEvidence[] } | null {
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
export function parseLegacyProseMonthlyFlow(text: string): { intro: string; months: MonthEvidence[] } | null {
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

export function parseMonthlyFlow(text: string): { intro: string; months: MonthEvidence[] } | null {
  return parseStrictMonthlyFlow(text) ?? parseLegacyProseMonthlyFlow(text);
}

/** 월별 카드 그리드 (표 뷰). 올해운세 템플릿에서는 차트와 분리해 단독으로도 쓴다. */
export function MonthEvidenceGrid({ months }: { months: MonthEvidence[] }) {
  return (
    <div className="month-evidence-grid">
      {months.map((item) => (
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
  );
}

export function MonthlyFlowOrText({ body, luckCycles }: { body: string; luckCycles?: LuckCycles }) {
  const monthly = parseMonthlyFlow(body);
  if (!monthly) return <>{renderTextBlock(body)}</>;

  // 곡선은 계산값(luckCycles)만 쓰고, AI가 쓴 월별 텍스트는 달을 눌렀을 때 상세로 연결한다.
  const hasChart = !!luckCycles?.monthlyFlow && luckCycles.monthlyFlow.length > 1;

  return (
    <div className="evidence-translation">
      {monthly.intro && <div className="evidence-translation__intro">{renderTextBlock(monthly.intro)}</div>}
      {hasChart && <MonthlyFlowChart monthlyFlow={luckCycles!.monthlyFlow} monthDetails={monthly.months} />}
      {hasChart ? (
        // 차트가 있으면 12장 카드 나열은 접어서 스크롤 부담을 줄인다 (카드는 표 뷰로 보존).
        <details className="month-evidence-more">
          <summary>12달 카드를 한꺼번에 펼쳐 보기</summary>
          <MonthEvidenceGrid months={monthly.months} />
        </details>
      ) : (
        <MonthEvidenceGrid months={monthly.months} />
      )}
    </div>
  );
}

export function SectionBody({ body, loading, luckCycles }: { body: string; loading?: boolean; luckCycles?: LuckCycles }) {
  const parts = parseBodyParts(body);
  if (parts.length === 1 && !parts[0].title) {
    return (
      <div className="reading-section__body">
        <MonthlyFlowOrText body={parts[0].body} luckCycles={luckCycles} />
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
                <PartIcon tone={meta?.tone} className="reading-part__icon" />
                {meta?.label && <span className="reading-part__label">{meta.label}</span>}
                <span>{part.title}</span>
              </h4>
            )}
            <MonthlyFlowOrText body={part.body} luckCycles={luckCycles} />
          </div>
        );
      })}
      {loading && <span className="reading-typing"> ▌</span>}
    </div>
  );
}

/** 요약 히어로에 쓸 "한 줄 결론"을 추출한다. 질문 핵심 → 첫 점괘 순으로, [한 줄 결론] 파트가
 * 있으면 그 첫 문장, 없으면 본문 첫 문장을 쓴다. */
export function extractConclusion(candidates: Array<Section | undefined>): string | null {
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

export const HERO_OPENING = "첫 점괘";
export const HERO_CLOSING = "마지막 점괘";
export const CATEGORY_SECTION_TITLE = "분야별 요약";
export const QUESTION_CORE_TITLE = "질문 중심 핵심";
export const YEARLY_FLOW_SECTION_TITLE = "올해의 흐름";
export const ACTION_SECTION_TITLE = "지금 해야 할 것과 피해야 할 것";

export function sectionAnchor(title: string): string {
  return `reading-${title.replace(/\s+/g, "-").replace(/[^\p{L}\p{N}-]/gu, "")}`;
}

export interface CategorySummary {
  label: string;
  rating: "good" | "mid" | "caution";
  comment: string;
}

const RATING_WORD: Record<string, CategorySummary["rating"]> = { 좋음: "good", 보통: "mid", 주의: "caution" };
export const RATING_LABEL: Record<CategorySummary["rating"], string> = { good: "좋음", mid: "보통", caution: "주의" };

/** "- 라벨: 평가 좋음|보통|주의 — 코멘트" 형식의 줄만 파싱한다. 형식이 어긋나면 그 줄은 건너뛴다. */
export function parseCategorySummary(sections: Section[]): CategorySummary[] | null {
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

/** 분야 라벨 → 섹션 아이콘 tone. 표시용 매칭이라 못 찾으면 기본 아이콘으로 조용히 폴백한다. */
export function categoryIconTone(label: string): string {
  if (/애정|연애|인연/.test(label)) return "love";
  if (/직업|직장|일|학업|커리어/.test(label)) return "work";
  if (/재물|돈|금전/.test(label)) return "money";
  if (/건강|컨디션/.test(label)) return "health";
  if (/멘탈|감정|마음/.test(label)) return "self";
  if (/관계|대인/.test(label)) return "love";
  return "default";
}

export function CategorySummaryCard({ item }: { item: CategorySummary }) {
  const tone = categoryIconTone(item.label);
  return (
    <div className={`reading-category-card reading-category-card--${item.rating}`}>
      <div className="reading-category-card__head">
        <span className={`reading-category-card__icon category-icon--${tone}`}>
          <SectionIcon tone={tone} size={15} />
        </span>
        <span className="reading-category-card__label">{item.label}</span>
        <RatingCell rating={item.rating} />
      </div>
      <p className="reading-category-card__comment">{item.comment}</p>
    </div>
  );
}

/** "좋음 2 · 보통 1 · 주의 1" 형태의 분야별 요약 집계 스트립. */
export function CategoryTally({ items }: { items: CategorySummary[] }) {
  const order: Array<CategorySummary["rating"]> = ["good", "mid", "caution"];
  const counts = order
    .map((rating) => ({ rating, count: items.filter((i) => i.rating === rating).length }))
    .filter((c) => c.count > 0);
  if (counts.length === 0) return null;
  return (
    <div className="reading-category-tally" aria-label="분야별 평가 집계">
      {counts.map((c) => (
        <span key={c.rating} className={`reading-category-tally__item reading-category-tally__item--${c.rating}`}>
          {RATING_LABEL[c.rating]} <b>{c.count}</b>
        </span>
      ))}
    </div>
  );
}

/** 분야별 요약 카드 묶음 (헤딩 + 집계 + 그리드). */
export function CategorySummarySection({ items }: { items: CategorySummary[] }) {
  return (
    <section className="card">
      <div className="section-heading-row">
        <h3 className="card-title">분야별 요약</h3>
        <CategoryTally items={items} />
      </div>
      <div className="reading-category-grid">
        {items.map((item) => (
          <CategorySummaryCard key={item.label} item={item} />
        ))}
      </div>
    </section>
  );
}

export function ReadingTableOfContents({ sections }: { sections: Section[] }) {
  const [active, setActive] = useState<string | null>(null);
  const titlesKey = sections.map((s) => s.title).join("|");

  // 스크롤을 따라 현재 읽는 섹션 칩을 하이라이트한다. (jsdom/SSR에는 IntersectionObserver가 없으니 감지 후에만)
  useEffect(() => {
    if (typeof IntersectionObserver === "undefined" || typeof document === "undefined") return;
    const els = titlesKey
      .split("|")
      .filter(Boolean)
      .map((title) => document.getElementById(sectionAnchor(title)))
      .filter((el): el is HTMLElement => !!el);
    if (els.length === 0) return;
    const io = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);
        if (visible[0]) setActive(visible[0].target.id);
      },
      { rootMargin: "-15% 0px -65% 0px" },
    );
    els.forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, [titlesKey]);

  if (sections.length === 0) return null;

  // 이 앱은 HashRouter를 쓰므로 <a href="#..."> 는 페이지 내 스크롤이 아니라 라우터의
  // 경로 이동으로 해석되어 존재하지 않는 라우트(빈 화면)로 튕긴다. 버튼 + 직접 스크롤로 대체한다.
  function goTo(title: string) {
    const el = document.getElementById(sectionAnchor(title));
    if (!el) return;
    if (el instanceof HTMLDetailsElement) el.open = true;
    setActive(el.id);
    el.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  return (
    <nav className="card reading-toc reading-toc--chips" aria-label="리딩 목차">
      <div className="reading-toc__head">
        <span>목차</span>
        <p>필요한 부분을 눌러 바로 이동하세요. 스크롤을 내려도 이 줄이 따라옵니다.</p>
      </div>
      <div className="reading-toc__links">
        {sections.map((section) => {
          const tone = SECTION_META[section.title]?.tone ?? "default";
          const isActive = active === sectionAnchor(section.title);
          return (
            <button
              type="button"
              className={`reading-toc__link${isActive ? " reading-toc__link--active" : ""}`}
              key={section.title}
              aria-current={isActive || undefined}
              onClick={() => goTo(section.title)}
            >
              <SectionIcon tone={tone} size={14} />
              {SECTION_META[section.title]?.tag ?? section.title}
            </button>
          );
        })}
      </div>
    </nav>
  );
}

/** 본문 섹션 하나 (접힘 카드 + tone 아이콘). 템플릿이 순서를 정해 나열한다. */
export function ReadingSectionCard({
  section,
  loading,
  luckCycles,
  open,
}: {
  section: Section;
  loading?: boolean;
  luckCycles?: LuckCycles;
  /** true면 처음부터 펼쳐서 보여준다 (올해운세의 행동 섹션 등). */
  open?: boolean;
}) {
  const tone = SECTION_META[section.title]?.tone ?? "default";
  return (
    <details
      id={sectionAnchor(section.title)}
      className={`card reading-section reading-section--open reading-section--${tone}`}
      open={open}
    >
      <summary className="reading-section__head">
        <span className={`reading-section__icon category-icon--${tone}`}>
          <SectionIcon tone={tone} />
        </span>
        <span className="reading-section__tag">{SECTION_META[section.title]?.tag ?? "풀이"}</span>
        <h3 className="reading-section__title">{section.title}</h3>
      </summary>
      <SectionBody body={section.body} loading={loading} luckCycles={luckCycles} />
    </details>
  );
}

/** 계산 위젯(오행/대운/신살/월별 등)을 기본 닫힘 상태로 모아, 총평·목차·본문 사이 스크롤을 줄인다. */
export function CalculationEvidenceZone({
  session,
  dashboard,
  loading,
  hideTarotFacts = false,
}: {
  session: ReadingSession;
  dashboard: ReturnType<typeof buildReadingDashboard>;
  loading: boolean;
  /** 타로형 템플릿이 카드 근거를 위에서 이미 펼쳐 보여줄 때 중복 렌더를 막는다. */
  hideTarotFacts?: boolean;
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
        {session.type !== "combo" && hasTarot && !hideTarotFacts && <TarotFactsPanel cards={session.tarotCards!} />}
        {dashboard && <PersonalitySpectrum spectrum={dashboard.spectrum} />}
        {session.sajuChart && <PatternMap sajuChart={session.sajuChart} />}
        {session.luckCycles?.monthlyFlow && <ActionCalendar luckCycles={session.luckCycles} />}
        {session.sajuChart && <LifestyleClosingSummary session={session} />}
      </div>
    </details>
  );
}

export function DetailLoadingCard() {
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

export function LifestyleClosingSummary({ session }: { session: ReadingSession }) {
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
