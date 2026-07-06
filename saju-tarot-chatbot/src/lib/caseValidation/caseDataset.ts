import type { Case, CaseDomain, CaseSource } from "./caseTypes.js";
import { CASE_SCHEMA_VERSION } from "./caseTypes.js";

/**
 * 사례 데이터셋 (Case Dataset) — 사례를 모으고 필터/직렬화하는 순수 저장 컨테이너.
 *
 * 이 모듈은 저장만 한다. Rule/Judgment/confidence를 바꾸지 않는다.
 * 지금은 파일/DB 없이 메모리·JSON 직렬화 수준의 구조만 제공한다 (UI 없음).
 */

export interface CaseDataset {
  schemaVersion: typeof CASE_SCHEMA_VERSION;
  cases: Case[];
}

export function createDataset(cases: Case[] = []): CaseDataset {
  // id 중복 제거 (나중 항목이 이김)
  const byId = new Map<string, Case>();
  for (const c of cases) byId.set(c.id, c);
  return { schemaVersion: CASE_SCHEMA_VERSION, cases: [...byId.values()] };
}

/** 사례 추가 (불변: 새 데이터셋 반환). 같은 id면 교체한다. */
export function addCase(ds: CaseDataset, kase: Case): CaseDataset {
  const cases = ds.cases.filter((c) => c.id !== kase.id);
  cases.push(kase);
  return { ...ds, cases };
}

/** 여러 사례 추가 */
export function addCases(ds: CaseDataset, cases: Case[]): CaseDataset {
  return cases.reduce((acc, c) => addCase(acc, c), ds);
}

export function getCase(ds: CaseDataset, id: string): Case | undefined {
  return ds.cases.find((c) => c.id === id);
}

export function filterBySource(ds: CaseDataset, source: CaseSource): Case[] {
  return ds.cases.filter((c) => c.source === source);
}

/** 해당 분야에 실제 결과가 기록된 사례만 */
export function filterByDomain(ds: CaseDataset, domain: CaseDomain): Case[] {
  return ds.cases.filter((c) =>
    c.actualOutcomes.some((o) => o.domain === domain),
  );
}

/** 사용자 피드백이 있는 사례만 */
export function withUserFeedback(ds: CaseDataset): Case[] {
  return ds.cases.filter((c) => c.userFeedback != null);
}

/** 전문가 검토가 있는 사례만 */
export function withExpertReview(ds: CaseDataset): Case[] {
  return ds.cases.filter((c) => c.expertReview != null);
}

export function serializeDataset(ds: CaseDataset): string {
  return JSON.stringify(ds);
}

export function deserializeDataset(json: string): CaseDataset {
  const parsed = JSON.parse(json) as Partial<CaseDataset>;
  const cases = Array.isArray(parsed.cases) ? parsed.cases : [];
  return createDataset(cases);
}
