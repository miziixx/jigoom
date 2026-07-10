import type { LifeDomain } from "../types/index.js";
import type { CompactDomainScore, CompactEvidence } from "./compactEvidence.js";
import type { EvidenceDirection, EvidenceRef, EvidenceSource, EvidenceStrength } from "./judgmentTypes.js";

const COMPACT_ID_MAP: Record<string, { id: string; source: EvidenceSource; direction: EvidenceDirection; strength: EvidenceStrength }> = {
  natal_core: { id: "chart.natal.core", source: "chart", direction: "support", strength: 4 },
  five_elements: { id: "chart.elements.balance", source: "chart", direction: "support", strength: 4 },
  strength: { id: "chart.strength.assessment", source: "chart", direction: "support", strength: 4 },
  useful_elements: { id: "chart.useful_elements.candidates", source: "chart", direction: "constraint", strength: 3 },
  natal_interactions: { id: "chart.interactions.natal", source: "chart", direction: "support", strength: 3 },
  structure: { id: "chart.gyeokguk.structure", source: "chart", direction: "support", strength: 2 },
  // 엔진 업그레이드 S-2: 4대 고전 심화 근거
  structure_classic: { id: "chart.gyeokguk.classic", source: "chart", direction: "support", strength: 3 },
  tengod_profile: { id: "chart.tengods.profile", source: "chart", direction: "support", strength: 3 },
  climate_classic: { id: "chart.climate.classic", source: "chart", direction: "constraint", strength: 3 },
  sinsal_key: { id: "chart.sinsal.key", source: "chart", direction: "neutral", strength: 2 },
  current_luck: { id: "luck.current.summary", source: "luck", direction: "support", strength: 4 },
  luck_overlap: { id: "luck.overlap.daeyun_year", source: "luck", direction: "support", strength: 4 },
  luck_interactions: { id: "luck.interactions.current", source: "luck", direction: "support", strength: 4 },
};

const VALID_DOMAINS = new Set<LifeDomain>(["career", "money", "love", "health", "family", "move", "startup"]);

function clampStrength(value: number): EvidenceStrength {
  if (value >= 5) return 5;
  if (value <= 1) return 1;
  return Math.round(value) as EvidenceStrength;
}

function domainDirection(domain: CompactDomainScore): EvidenceDirection {
  if (domain.balance === "caution") return "risk";
  if (domain.balance === "calm") return "neutral";
  return "support";
}

function domainStrength(domain: CompactDomainScore): EvidenceStrength {
  const fromActivation = domain.activation === "high" ? 5 : domain.activation === "mid" ? 4 : 2;
  const fromScore = domain.activationScore >= 70 ? 5 : domain.activationScore >= 45 ? 4 : domain.activationScore >= 20 ? 3 : 2;
  return clampStrength((fromActivation + fromScore) / 2);
}

function normalizeDomain(value: string): LifeDomain | null {
  return VALID_DOMAINS.has(value as LifeDomain) ? (value as LifeDomain) : null;
}

export function evidenceIdForCompactKey(key: string): string {
  if (COMPACT_ID_MAP[key]) return COMPACT_ID_MAP[key].id;
  if (key.startsWith("domain_")) return `event.domain.${key.replace("domain_", "")}`;
  return `compact.${key}`;
}

export function evidenceRefsFromCompactEvidence(compact: CompactEvidence): EvidenceRef[] {
  const refs: EvidenceRef[] = [];
  for (const [key, summary] of Object.entries(compact.evidenceIds)) {
    const mapped = COMPACT_ID_MAP[key];
    refs.push({
      id: mapped?.id ?? evidenceIdForCompactKey(key),
      source: mapped?.source ?? (key.startsWith("domain_") ? "event" : "compact"),
      strength: mapped?.strength ?? 3,
      direction: mapped?.direction ?? "support",
      summary,
    });
  }

  for (const domain of compact.domainScores) {
    const normalized = normalizeDomain(domain.domain);
    if (!normalized) continue;
    refs.push({
      id: `event.${normalized}.activation.${domain.activation}`,
      source: "event",
      strength: domainStrength(domain),
      direction: domainDirection(domain),
      summary: `${domain.label}: 활성 ${domain.activationScore}, 이득 ${domain.benefit}, 위험 ${domain.risk}, 성격 ${domain.balance}`,
    });
    refs.push({
      id: `event.${normalized}.balance.${domain.balance}`,
      source: "event",
      strength: domainStrength(domain),
      direction: domainDirection(domain),
      summary: `${domain.label}: ${domain.summary}`,
    });
  }

  for (const [index, flag] of compact.riskFlags.entries()) {
    refs.push({
      id: `context.risk_flag.${index + 1}`,
      source: "context",
      strength: 3,
      direction: "constraint",
      summary: flag,
    });
  }

  const byId = new Map<string, EvidenceRef>();
  for (const ref of refs) byId.set(ref.id, ref);
  return [...byId.values()];
}

export function evidenceById(evidence: EvidenceRef[]): Map<string, EvidenceRef> {
  return new Map(evidence.map((ref) => [ref.id, ref]));
}
