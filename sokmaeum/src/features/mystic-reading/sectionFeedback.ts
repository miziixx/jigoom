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
