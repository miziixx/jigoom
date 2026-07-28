import type { MysticReadingResult } from "../../types";

/**
 * 구조화된 리딩 결과를 이어묻기 챗봇의 컨텍스트로 쓸 수 있는 읽기용 텍스트로 변환한다.
 * (챗봇은 이 텍스트를 assistant 메시지로 받아 대화를 이어간다)
 */
export function mysticResultToText(r: MysticReadingResult): string {
  const parts: string[] = [];
  parts.push(`[첫 점괘] ${r.openingOracle.title} — ${r.openingOracle.sentence}`);
  parts.push(
    `[지금 내 상태] ${r.currentState.summary} 몸: ${r.currentState.bodySignal} 감정: ${r.currentState.emotionalSignal} 에너지: ${r.currentState.energyLeak} 조언: ${r.currentState.advice}`,
  );
  parts.push(
    `[말하지 않은 고민] ${r.hiddenConcerns.map((c) => `${c.title}(${c.description})`).join(" / ")}`,
  );
  parts.push(
    `[겉과 속] 남들이 보는 나: ${r.outerInnerSelf.outerSelf} 숨기는 마음: ${r.outerInnerSelf.innerSelf} 상처 반응: ${r.outerInnerSelf.defensePattern} 진짜 원하는 것: ${r.outerInnerSelf.hiddenDesire} 무너지는 지점: ${r.outerInnerSelf.collapsePoint}`,
  );
  parts.push(
    `[반복 패턴] ${r.repeatedPatterns.map((p) => `${p.pattern} (${p.reason})`).join(" / ")}`,
  );
  parts.push(
    `[돈과 일] 붙는 방식: ${r.workAndMoney.moneyAttractionPattern} 새는 구멍: ${r.workAndMoney.moneyLeakPattern} 맞는 환경: ${r.workAndMoney.suitableWorkEnvironment} 조언: ${r.workAndMoney.currentAdvice}`,
  );
  parts.push(
    `[관계 속마음] 기대: ${r.relationshipReading.expectationPattern} 상처: ${r.relationshipReading.hurtPattern} 마음 닫는 순간: ${r.relationshipReading.closingHeartMoment} 조언: ${r.relationshipReading.advice}`,
  );
  parts.push(
    `[올해 전환점] ${r.yearlyTurningPoints.map((t) => `${t.period} ${t.keyword}: ${t.advice}`).join(" / ")}`,
  );
  parts.push(`[지금 피해야 할 선택] ${r.avoidNow.map((a) => `${a.title} → ${a.saferAlternative}`).join(" / ")}`);
  parts.push(`[지금 해야 할 선택] ${r.doNow.map((d) => `${d.title}: ${d.action}`).join(" / ")}`);
  parts.push(`[마지막 점괘] ${r.closingOracle.sentence}`);
  return parts.join("\n");
}
