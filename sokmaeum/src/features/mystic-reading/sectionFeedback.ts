import type { SectionFeedback } from "../../types";

/**
 * 리딩 섹션별 피드백을 로컬에 저장한다(추후 개인화용).
 * (세션 단위 피드백과 별개로, 카드마다 정확도 신호를 모은다)
 */
const KEY = "sokmaeum:section-feedback";

export const SECTION_FEEDBACK_LABEL: Record<SectionFeedback["feedback"], string> = {
  accurate: "정확해요",
  partial: "반쯤 맞아요",
  unsure: "잘 모르겠어요",
  wrong: "아니에요",
};

function loadAll(): SectionFeedback[] {
  try {
    const raw = localStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as SectionFeedback[]) : [];
  } catch {
    return [];
  }
}

function saveAll(list: SectionFeedback[]): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(list));
  } catch {
    // 무시
  }
}

/** 특정 리딩·섹션의 저장된 피드백을 반환 */
export function getSectionFeedback(readingId: string, sectionKey: string): SectionFeedback["feedback"] | null {
  const found = loadAll().find((f) => f.readingId === readingId && f.sectionKey === sectionKey);
  return found?.feedback ?? null;
}

/** 섹션 피드백을 저장(동일 리딩·섹션은 덮어쓴다) */
export function saveSectionFeedback(readingId: string, sectionKey: string, feedback: SectionFeedback["feedback"]): void {
  const list = loadAll().filter((f) => !(f.readingId === readingId && f.sectionKey === sectionKey));
  list.push({ readingId, sectionKey, feedback, createdAt: new Date().toISOString() });
  saveAll(list);
}

/**
 * 지금까지 모인 섹션 피드백에서 다음 리딩에 반영할 스타일 힌트를 만든다(개인화).
 * 충분한 신호(3개 이상)가 없으면 null을 반환해 개인화를 적용하지 않는다.
 */
export function buildMysticStyleHint(): string | null {
  const all = loadAll();
  if (all.length < 3) return null;

  const count = (f: SectionFeedback["feedback"]) => all.filter((x) => x.feedback === f).length;
  const wrong = count("wrong");
  const unsure = count("unsure");
  const accurate = count("accurate");
  const total = all.length;

  const hints: string[] = [];
  if (wrong / total >= 0.35) {
    hints.push("지난 리딩에서 안 맞는다는 신호가 많았다. 단정의 강도를 낮추고, 근거와 반대 근거를 더 투명하게 드러내라.");
  }
  if (unsure / total >= 0.35) {
    hints.push("지난 리딩이 모호하다는 신호가 많았다. 추상적 표현을 줄이고 구체적인 상황·행동 묘사를 늘려라.");
  }
  if (accurate / total >= 0.5) {
    hints.push("지난 리딩이 잘 맞았다는 신호가 많았다. 지금의 톤과 깊이를 유지하되 현실 장면 묘사를 조금 더 살려라.");
  }

  // 자주 틀린 섹션을 특정해 더 조심하게
  const wrongBySection = new Map<string, number>();
  for (const f of all) {
    if (f.feedback === "wrong") wrongBySection.set(f.sectionKey, (wrongBySection.get(f.sectionKey) ?? 0) + 1);
  }
  const worst = [...wrongBySection.entries()].sort((a, b) => b[1] - a[1])[0];
  if (worst && worst[1] >= 2) {
    hints.push(`"${worst[0]}" 섹션이 특히 안 맞는다는 신호가 반복됐다. 이 부분은 더 신중하게, 근거에 밀착해서 써라.`);
  }

  return hints.length > 0 ? hints.join(" ") : null;
}
