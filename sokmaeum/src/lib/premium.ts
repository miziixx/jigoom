// 프리미엄 기능 게이팅 구조.
// 실제 결제(인앱/PG) 연동 전까지는 localStorage 플래그로 대체하는 스텁이다.
// 결제를 붙일 때는 unlockPremium()을 결제 성공 콜백에서 호출하고,
// isPremium()을 서버 검증 기반으로 바꾸면 된다.

const PREMIUM_KEY = "sokmaeum:premium";

export function isPremium(): boolean {
  try {
    return localStorage.getItem(PREMIUM_KEY) === "true";
  } catch {
    return false;
  }
}

export function unlockPremium(): void {
  localStorage.setItem(PREMIUM_KEY, "true");
}

export function lockPremium(): void {
  localStorage.removeItem(PREMIUM_KEY);
}

/** 프리미엄으로 분류된 기능 목록 (수익화 구조의 뼈대) */
export const PREMIUM_FEATURES = [
  "AI 리딩 비교 분석",
  "속마음 전체 리포트",
  "관계 속마음 리딩",
  "이어 묻기 챗봇",
  "PDF·사주북 저장",
] as const;
