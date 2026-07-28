import type { FiveElementBalance, ReadingSession } from "../types";

const ELEMENT_LABEL: Record<keyof FiveElementBalance, string> = {
  wood: "성장·배움",
  fire: "표현·활력",
  earth: "안정·현실감",
  metal: "판단·정리",
  water: "생각·휴식",
};

const SECTION_KEYWORDS: Record<string, string[]> = {
  "타고난 성격과 기질": ["기질", "강점", "스트레스"],
  "직업과 돈": ["커리어", "일하는 방식"],
  "재물 흐름": ["재물", "관리 습관"],
  "애정과 관계": ["관계", "표현 방식"],
  "건강과 컨디션": ["컨디션", "회복 리듬"],
  "인생의 큰 흐름": ["큰 흐름"],
  "올해의 흐름": ["올해 흐름", "월별 전략"],
};

function pushUnique(list: string[], value?: string) {
  if (!value) return;
  const clean = value.trim();
  if (clean && !list.includes(clean)) list.push(clean);
}

function strongestElement(fiveElements: FiveElementBalance): keyof FiveElementBalance {
  return (Object.keys(fiveElements) as Array<keyof FiveElementBalance>).reduce((best, key) =>
    fiveElements[key] > fiveElements[best] ? key : best,
  );
}

function weakestElement(fiveElements: FiveElementBalance): keyof FiveElementBalance {
  return (Object.keys(fiveElements) as Array<keyof FiveElementBalance>).reduce((best, key) =>
    fiveElements[key] < fiveElements[best] ? key : best,
  );
}

function sectionTitles(reply: string): string[] {
  return reply
    .split(/^#\s+(.+)$/m)
    .slice(1)
    .filter((_, i) => i % 2 === 0)
    .map((s) => s.trim());
}

function buildKeywords(session: ReadingSession): string[] {
  const keywords: string[] = [];
  const reply = session.messages.find((m) => m.role === "assistant")?.content ?? "";

  if (session.sajuChart) {
    const strong = strongestElement(session.sajuChart.fiveElements);
    const weak = weakestElement(session.sajuChart.fiveElements);
    pushUnique(keywords, `${ELEMENT_LABEL[strong]} 강함`);
    pushUnique(keywords, `${ELEMENT_LABEL[weak]} 보완`);
    pushUnique(keywords, session.sajuChart.strength?.label);
    pushUnique(keywords, session.sajuChart.gyeokguk?.name);
    for (const sinsal of session.sajuChart.sinsal ?? []) pushUnique(keywords, sinsal.name);
  }

  if (session.luckCycles) {
    pushUnique(keywords, `${session.luckCycles.year}년 흐름`);
    pushUnique(keywords, "1월~12월 월별 운");
    if (session.luckCycles.currentDaYun) pushUnique(keywords, `현재 큰 흐름 ${session.luckCycles.currentDaYun}`);
  }

  for (const title of sectionTitles(reply)) {
    for (const keyword of SECTION_KEYWORDS[title] ?? []) pushUnique(keywords, keyword);
  }

  if (session.tarotCards && session.tarotCards.length > 0) {
    for (const tarot of session.tarotCards.slice(0, 3)) pushUnique(keywords, tarot.card.name.split(" (")[1]?.replace(")", "") ?? tarot.card.name);
  }

  return keywords.slice(0, 14);
}

export default function KeywordCloud({ session }: { session: ReadingSession }) {
  const keywords = buildKeywords(session);
  if (keywords.length === 0) return null;

  return (
    <section className="card keyword-cloud" aria-label="주요 키워드">
      <h3 className="card-title">주요 키워드</h3>
      <div className="keyword-cloud__stage">
        {keywords.map((keyword, i) => (
          <span className={`keyword-bubble keyword-bubble--${(i % 5) + 1}`} key={`${keyword}-${i}`}>
            {keyword}
          </span>
        ))}
      </div>
    </section>
  );
}
