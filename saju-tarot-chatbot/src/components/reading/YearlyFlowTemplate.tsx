import LoadingNotice from "../LoadingNotice";
import SajuFactsPanel, { SajuPillarSnapshot } from "../SajuFactsPanel";
import ActionChecklist from "../ActionChecklist";
import { buildReadingDashboard } from "../../lib/readingDashboard";
import { VizIcon } from "../viz/icons";
import { CloudPattern, CornerOrnaments, QuoteMark, SectionDivider } from "../viz/Motif";
import MonthlyFlowChart from "../viz/MonthlyFlowChart";
import { parseSections, renderTextBlock, stripMarkdown } from "../../lib/readingText";
import ReadingNextCta from "./ReadingNextCta";
import {
  ACTION_SECTION_TITLE,
  CATEGORY_SECTION_TITLE,
  CalculationEvidenceZone,
  CategorySummarySection,
  DetailLoadingCard,
  HERO_CLOSING,
  HERO_OPENING,
  QUESTION_CORE_TITLE,
  ReadingSectionCard,
  SectionBody,
  YEARLY_FLOW_SECTION_TITLE,
  extractConclusion,
  parseCategorySummary,
  parseMonthlyFlow,
  MonthEvidenceGrid,
} from "./readingBlocks";
import type { ReadingSession } from "../../types";

/**
 * 올해운세(흐름 캘린더) 전용 템플릿 — "1년 작전 지도" 구성.
 * 순서: 올해 총평 히어로 → 원국 → 큰 흐름×올해 흐름 → 분야별 요약 → 12개월 차트 →
 * 월별 상세 → 해야 할 것/피해야 할 것 → 나머지 풀이 → 마지막 정리 → 근거 존 → CTA.
 * AI 출력 구조는 그대로 두고 화면 배치만 바꾼다 (스트리밍/저장 세션과 호환).
 */
export default function YearlyFlowTemplate({ session, loading = false }: { session: ReadingSession; loading?: boolean }) {
  const reply = session.messages.find((m) => m.role === "assistant")?.content ?? "";
  const hasReply = reply.trim().length > 0;
  const sections = hasReply ? parseSections(reply) : [];
  const categorySummary = parseCategorySummary(sections);

  const opening = sections.find((s) => s.title === HERO_OPENING) ?? sections[0];
  const closing = sections.find((s) => s.title === HERO_CLOSING);
  const questionCore = sections.find((s) => s.title === QUESTION_CORE_TITLE);
  const flowSection = sections.find((s) => s.title === YEARLY_FLOW_SECTION_TITLE);
  const actionSection = sections.find((s) => s.title === ACTION_SECTION_TITLE);
  const otherSections = sections.filter(
    (s) =>
      s !== opening &&
      s !== closing &&
      s !== questionCore &&
      s !== flowSection &&
      s !== actionSection &&
      s.title !== CATEGORY_SECTION_TITLE,
  );

  const monthly = flowSection ? parseMonthlyFlow(flowSection.body) : null;
  const luckCycles = session.luckCycles;
  const hasChart = !!luckCycles?.monthlyFlow && luckCycles.monthlyFlow.length > 1;
  const year = luckCycles?.year ?? new Date().getFullYear();
  const dashboard = buildReadingDashboard(session.sajuChart, luckCycles);
  const conclusion = extractConclusion([questionCore, opening]);
  const overlap = luckCycles?.daYunYearOverlap;

  return (
    <div className="reading-result yearly-result">
      {loading && (
        <LoadingNotice
          depth={session.context?.depth}
          type={session.type}
          hasQuestion={!!session.question?.trim()}
          replyText={reply}
          isInitial={session.messages.length <= 2}
        />
      )}

      {/* 1. 올해 한 줄 총평 + 올해 키워드 */}
      <section className="card yearly-hero">
        <div className="reading-type-eyebrow">
          <VizIcon name="calendar" size={13} /> {year} 올해운세
        </div>
        <h2 className="yearly-hero__headline">
          {conclusion ?? (hasReply ? "올해의 흐름을 정리했어요." : "올해의 흐름을 정리하고 있어요.")}
        </h2>
        {dashboard && dashboard.keywords.length > 0 && (
          <div className="summary-hero__chips">
            {dashboard.keywords.map((k) => (
              <span className="summary-hero__chip" key={k}>
                {k}
              </span>
            ))}
          </div>
        )}
        <p className="yearly-hero__note">
          올해 들어온 기운{luckCycles?.yearGanZhi ? ` (${luckCycles.yearGanZhi}년)` : ""} 기준 — 아래에서 12개월 흐름과 월별
          상세, 올해 해야 할 것을 확인하세요.
        </p>
      </section>

      <SajuPillarSnapshot sajuChart={session.sajuChart} />

      {/* 2. 큰 흐름 × 올해 흐름 (10년 단위 흐름과 올해가 겹치는 방식) */}
      {overlap && (
        <section className={`card yearly-overlap luck-overlap luck-overlap--${overlap.combo}`}>
          <span className="luck-overlap__tag">큰 흐름 × 올해 흐름</span>
          <p className="luck-overlap__headline">{overlap.headline}</p>
        </section>
      )}

      {!hasReply && loading && <DetailLoadingCard />}

      {hasReply && <SectionDivider />}

      {/* 3. 올해 총평 본문 */}
      {opening && (
        <div className="card reading-oracle reading-oracle--opening">
          <CloudPattern id="oracle-cloud-opening" />
          <CornerOrnaments />
          <QuoteMark />
          <span className="reading-oracle__tag">올해 총평</span>
          <p className="reading-oracle__text">
            {stripMarkdown(opening.body)}
            {loading && !flowSection && !closing && <span className="reading-typing"> ▌</span>}
          </p>
        </div>
      )}

      {questionCore && (
        <section className="card question-core-card">
          <span className="question-core-card__tag">
            <VizIcon name="compass" size={13} /> 내 질문에 대한 먼저 답변
          </span>
          <h3 className="card-title">{session.question?.trim() || "지금 먼저 볼 핵심"}</h3>
          <SectionBody body={questionCore.body} luckCycles={luckCycles} />
        </section>
      )}

      {/* 4. 분야별 올해 흐름 */}
      {categorySummary && <CategorySummarySection items={categorySummary} />}

      {/* 5. 12개월 흐름 차트 (곡선은 계산값, 달을 누르면 AI 월별 텍스트) */}
      {(hasChart || monthly) && (
        <section className="card yearly-flow-card">
          <div className="section-heading-row">
            <h3 className="card-title">1월~12월 흐름</h3>
            <span className="feature-badge">올해 지도</span>
          </div>
          {monthly?.intro && <div className="evidence-translation__intro">{renderTextBlock(monthly.intro)}</div>}
          {hasChart ? (
            <MonthlyFlowChart monthlyFlow={luckCycles!.monthlyFlow} monthDetails={monthly?.months} />
          ) : (
            monthly && <MonthEvidenceGrid months={monthly.months} />
          )}
        </section>
      )}

      {/* 6. 월별 상세 카드 (12장 전체) */}
      {monthly && hasChart && (
        <section className="card">
          <h3 className="card-title">월별 상세</h3>
          <MonthEvidenceGrid months={monthly.months} />
        </section>
      )}

      {/* 올해의 흐름 텍스트가 아직 월별 형식이 아니면(스트리밍 중/구버전) 일반 섹션 카드로 폴백 */}
      {flowSection && !monthly && <ReadingSectionCard section={flowSection} loading={loading && !closing} luckCycles={luckCycles} open />}

      {/* 7. 올해 해야 할 것 / 피해야 할 것 */}
      {actionSection && <ReadingSectionCard section={actionSection} luckCycles={luckCycles} open />}

      {/* 나머지 풀이 섹션 */}
      {otherSections.map((section, i) => (
        <ReadingSectionCard
          key={section.title}
          section={section}
          loading={loading && i === otherSections.length - 1 && !closing}
          luckCycles={luckCycles}
        />
      ))}

      {closing && (
        <div className="card reading-oracle reading-oracle--closing">
          <CloudPattern id="oracle-cloud-closing" />
          <CornerOrnaments />
          <QuoteMark />
          <span className="reading-oracle__tag">마지막 정리</span>
          <p className="reading-oracle__text">
            {stripMarkdown(closing.body)}
            {loading && <span className="reading-typing"> ▌</span>}
          </p>
        </div>
      )}

      <CalculationEvidenceZone session={session} dashboard={dashboard} loading={loading} />

      {session.sajuChart && (
        <section className="reading-basic-report" aria-label="기본 사주 리포트">
          <div className="reading-layer-heading">
            <span>
              <VizIcon name="book" size={14} /> 기본 사주 리포트
            </span>
            <p>원국·오행·대운/세운 계산값을 자세히 보고 싶을 때 펼쳐 보세요.</p>
          </div>
          <SajuFactsPanel
            sajuChart={session.sajuChart}
            luckCycles={luckCycles}
            birthInfo={session.birthInfo}
            showPillars={false}
          />
        </section>
      )}

      {session.sajuChart && <SectionDivider />}
      {session.sajuChart && <ActionChecklist sajuChart={session.sajuChart} luckCycles={luckCycles} />}

      {/* 8. 다음 리딩 CTA */}
      {hasReply && !loading && (
        <ReadingNextCta
          items={[
            { to: "/fortune", label: "오늘 운세 보기", icon: "clock", desc: "오늘 하루의 흐름을 매일 확인" },
            { to: "/saju", label: "전체 사주 리포트", icon: "book", desc: "타고난 구조와 큰 흐름까지" },
            { to: "/combo", label: "질문 넣고 상담 리딩", icon: "compass", desc: "지금 고민을 콕 집어 묻기" },
          ]}
        />
      )}
    </div>
  );
}
