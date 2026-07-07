import LoadingNotice from "../LoadingNotice";
import SajuFactsPanel, { SajuPillarSnapshot } from "../SajuFactsPanel";
import ActionChecklist from "../ActionChecklist";
import TarotSummaryHero from "../TarotSummaryHero";
import SummaryCardGrid from "../SummaryCardGrid";
import EventForecastPanel from "../EventForecastPanel";
import PastValidationPanel from "../PastValidationPanel";
import TarotFactsPanel from "../TarotFactsPanel";
import { buildReadingDashboard } from "../../lib/readingDashboard";
import { VizIcon } from "../viz/icons";
import { CloudPattern, CornerOrnaments, QuoteMark, SectionDivider } from "../viz/Motif";
import { parseSections, stripMarkdown } from "../../lib/readingText";
import {
  CATEGORY_SECTION_TITLE,
  CalculationEvidenceZone,
  CategorySummarySection,
  DetailLoadingCard,
  HERO_CLOSING,
  HERO_OPENING,
  QUESTION_CORE_TITLE,
  ReadingSectionCard,
  ReadingTableOfContents,
  SectionBody,
  extractConclusion,
  parseCategorySummary,
} from "./readingBlocks";
import type { ReadingSession } from "../../types";

/**
 * 기본(공용) 리딩 결과 템플릿 — 사주/콤보/고민/타로가 공유하는 현행 배치.
 * 타입별 차이는 eyebrow(상단 상품 라벨)와 promoteTarotFacts(타로 근거 승격)로만 표현한다.
 */
export default function DefaultReadingTemplate({
  session,
  loading = false,
  eyebrow,
  eyebrowIcon = "book",
  promoteTarotFacts = false,
}: {
  session: ReadingSession;
  loading?: boolean;
  /** "평생사주 리포트" 같은 상품 정체성 라벨. 없으면 표시하지 않는다. */
  eyebrow?: string;
  eyebrowIcon?: string;
  /** 타로형: 뽑힌 카드 근거 패널을 접힌 근거 존이 아니라 히어로 바로 아래에 펼친다. */
  promoteTarotFacts?: boolean;
}) {
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
  const hasTarot = !!(session.tarotCards && session.tarotCards.length > 0);

  return (
    <div className="reading-result">
      {eyebrow && (
        <div className="reading-type-eyebrow">
          <VizIcon name={eyebrowIcon} size={13} /> {eyebrow}
        </div>
      )}

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
            <span>
              <VizIcon name="book" size={14} /> 기본 사주 리포트
            </span>
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
      {session.type !== "combo" && hasTarot && <TarotSummaryHero cards={session.tarotCards!} />}

      {/* 타로형: 뽑힌 카드가 주인공이므로 카드 근거를 바로 펼쳐 보여준다. */}
      {promoteTarotFacts && session.type !== "combo" && hasTarot && (
        <div className="tarot-facts-promoted">
          <TarotFactsPanel cards={session.tarotCards!} />
        </div>
      )}

      {session.type === "combo" && hasTarot && (
        <section className="combo-result-layer" aria-label="타로 카드 요약">
          <div className="reading-layer-heading">
            <span>
              <VizIcon name="moonStar" size={14} /> 타로 카드 흐름
            </span>
            <p>사주는 큰 흐름을, 타로는 지금 질문의 가까운 분위기를 보여줍니다. 뽑힌 카드는 아래에서 바로 확인할 수 있어요.</p>
          </div>
          <TarotSummaryHero cards={session.tarotCards!} />
          <TarotFactsPanel cards={session.tarotCards!} />
        </section>
      )}

      {!hasReply && loading && <DetailLoadingCard />}

      {hasReply && <SectionDivider />}

      {hasReply && (
        <section className="reading-detail-layer" aria-label="AI 상세 리딩">
          <div className="reading-layer-heading">
            <span>
              <VizIcon name="sparkle" size={14} /> AI 상세 리딩
            </span>
            <p>빠른 요약에서 잡은 흐름을 질문과 분야별 상황에 맞춰 풀어드립니다.</p>
          </div>

          {questionCore && (
            <section className="card question-core-card">
              <span className="question-core-card__tag">
                <VizIcon name="compass" size={13} />{" "}
                {session.question?.trim() ? "내 질문에 대한 먼저 답변" : "선택한 관심사 핵심 보기"}
              </span>
              <h3 className="card-title">{session.question?.trim() ? session.question.trim() : "지금 먼저 볼 핵심"}</h3>
              <SectionBody
                body={questionCore.body}
                loading={loading && bodySections.length === 0 && !closing}
                luckCycles={session.luckCycles}
              />
            </section>
          )}

          {opening && (
            <div className="card reading-oracle reading-oracle--opening">
              <CloudPattern id="oracle-cloud-opening" />
              <CornerOrnaments />
              <QuoteMark />
              <span className="reading-oracle__tag">전체 총평</span>
              <p className="reading-oracle__text">
                {stripMarkdown(opening.body)}
                {loading && bodySections.length === 0 && !closing && <span className="reading-typing"> ▌</span>}
              </p>
            </div>
          )}

          {categorySummary && <CategorySummarySection items={categorySummary} />}

          <ReadingTableOfContents sections={bodySections} />

          <CalculationEvidenceZone
            session={session}
            dashboard={dashboard}
            loading={loading}
            hideTarotFacts={promoteTarotFacts}
          />

          {bodySections.map((section, i) => (
            <ReadingSectionCard
              key={section.title}
              section={section}
              loading={loading && i === bodySections.length - 1 && !closing}
              luckCycles={session.luckCycles}
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
        </section>
      )}

      {session.sajuChart && <SectionDivider />}
      {session.sajuChart && <ActionChecklist sajuChart={session.sajuChart} luckCycles={session.luckCycles} />}
    </div>
  );
}
