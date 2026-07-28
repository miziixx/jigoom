/**
 * Quality Dashboard 접근 제한 (개발자 전용).
 *
 * 운영(prod)에서는 명시적 플래그가 없으면 접근 불가. 개발(dev)에서는 열려 있다.
 * 대시보드는 개인정보를 저장하지 않지만, 개발자 전용 운영 화면이므로 노출을 제한한다.
 *
 * 활성 조건(둘 중 하나):
 *   - 빌드 환경변수 VITE_QUALITY_DASHBOARD === "1" (배포 시 켜기)
 *   - localStorage["quality-dashboard-unlock"] === "1" (운영 중 수동 해제)
 * 개발 모드(import.meta.env.DEV)에서는 항상 허용.
 */

const UNLOCK_KEY = "quality-dashboard-unlock";

function readEnv(): { dev: boolean; flag: string | undefined } {
  try {
    const env = (import.meta as unknown as { env?: Record<string, unknown> }).env ?? {};
    return { dev: env.DEV === true, flag: typeof env.VITE_QUALITY_DASHBOARD === "string" ? env.VITE_QUALITY_DASHBOARD : undefined };
  } catch {
    return { dev: false, flag: undefined };
  }
}

function unlockedInStorage(): boolean {
  try {
    if (typeof localStorage === "undefined") return false;
    return localStorage.getItem(UNLOCK_KEY) === "1";
  } catch {
    return false;
  }
}

export function isQualityDashboardEnabled(): boolean {
  const { dev, flag } = readEnv();
  if (dev) return true;
  if (flag === "1") return true;
  return unlockedInStorage();
}

/** 운영 중 대시보드를 수동으로 켜고 끄는 헬퍼 (콘솔에서 호출 가능) */
export function setQualityDashboardUnlock(on: boolean): void {
  try {
    if (typeof localStorage === "undefined") return;
    if (on) localStorage.setItem(UNLOCK_KEY, "1");
    else localStorage.removeItem(UNLOCK_KEY);
  } catch {
    // ignore
  }
}
